#!/usr/bin/env bash
#
# Toetst dat de ontvangstvariant nog iets afdwingt, en niet te veel doorlaat.
#
#   toets-ontvangstschemas.sh <map-met-schemas-relatief-aan-de-hoofdmap>
#
# De structurele controle in ontvangstschemas.sh telt sleutels: staat `required` er nog,
# kloppen de propertynamen. Dat is nodig en niet genoeg. Een transformatie die te ver gaat
# levert een schema op dat álles goedkeurt, en dan is elke gate erachter groen omdat er niets
# meer getoetst wordt — het patroon dat deze repository op vier andere plekken al is
# tegengekomen.
#
# Daarom gedrag in plaats van vorm. Vier kanaries, twee elke kant op:
#
#   afgekeurd   een bericht zonder verplicht veld
#   afgekeurd   een bericht met een verkeerd type
#   doorgelaten een bericht met een onbekend veld
#   doorgelaten een bericht met een onbekende enum-waarde
#
# De bovenste twee vangen een te gulle transformatie: gaat `required` per ongeluk mee eruit,
# dan komt kanarie 1 erdoor en wordt dit rood. De onderste twee vangen een te strenge: blijft
# `additionalProperties: false` staan, dan valt kanarie 3 en breekt elke additieve wijziging.
#
# Samen bracketten ze de transformatie. Slaagt alles, dan doet het schema precies wat de
# belofte zegt: de vorm afdwingen, de woordenschat niet.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "toets-ontvangstschemas: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fout "gebruik: toets-ontvangstschemas.sh <map-met-schemas>"

REL="$1"
MAP="${CBT_ROOT}/${REL}"
[ -d "${MAP}" ] || fout "geen map op ${REL}"

WERK="${MAP}/kanaries"
WERK_REL="${REL}/kanaries"
rm -rf "${WERK}"
mkdir -p "${WERK}"

# We toetsen op RunGestartPayload: die heeft vier verplichte velden, een enum op `soort` en
# geen conditionele constructies. Het is het eenvoudigste schema waarop alle vier de kanaries
# betekenis hebben.
SCHEMA="${MAP}/RunGestartPayload.json"
[ -f "${SCHEMA}" ] || fout "RunGestartPayload.json ontbreekt in ${REL}"

geldig() {
  # ajv geeft 0 bij geldig en niet-0 bij ongeldig. De uitvoer interesseert ons niet, het
  # oordeel wel.
  ajv validate -s "${WERK_REL}/schema.json" -d "${WERK_REL}/$1" --strict=false >/dev/null 2>&1
}

cp "${SCHEMA}" "${WERK}/schema.json"

# De berichten worden uit het schema afgeleid en niet met de hand geschreven. De eerste versie
# hiervan had `scenarioId` als verplicht veld in de fixtures staan; toen een wijziging dat veld
# legitiem uit `required` haalde, viel de kanarie om terwijl de transformatie in orde was. Een
# kanarie die aan de inhoud van vandaag hangt, meet de verkeerde belofte — precies de fout die
# deze gate elders moet vangen.
#
# Het geldige bericht: elk verplicht veld met een waarde die bij zijn type past. De vier
# kanaries zijn daar afgeleiden van, zodat ze meebewegen met het schema.
jq '
  def waarde($s):
    if   $s.example != null then $s.example
    elif $s.type == "integer" or $s.type == "number" then 1
    elif $s.type == "object"  then {}
    elif $s.type == "array"   then []
    elif $s.type == "boolean" then true
    else "x" end;
  . as $doc
  | (.required // []) as $req
  | reduce $req[] as $veld ({};
      . + { ($veld): waarde(
              ($doc.properties[$veld]["$ref"] // "") as $r
              | if $r == "" then $doc.properties[$veld]
                else $doc.components.schemas[$r | sub("^#/components/schemas/"; "")] end) })
' "${WERK_REL}/schema.json" > "${WERK}/geldig.json"

VERPLICHT="$(jq -r '(.required // []) | length' "${WERK_REL}/schema.json")"
verwacht_minstens "${VERPLICHT}" 1 "verplichte velden om een kanarie op te bouwen"

# Het geldige bericht moet ook echt geldig zijn, anders keuren de eerste twee kanaries alles
# af en zijn ze groen om de verkeerde reden. Dat gebeurde: een gegenereerde "x" voldeed niet
# aan de `pattern` op runId, en toen leek "verplicht veld ontbreekt → afgekeurd" te kloppen
# terwijl élk bericht werd afgekeurd. Vandaar de waarden uit de `example` van de spec, en
# vandaar deze controle vóór de vier.
geldig geldig.json \
  || fout "het geldige bericht wordt afgekeurd — dan zeggen de kanaries hieronder niets.
  Waarschijnlijk mist een schema een bruikbare example. Bericht: $(cat "${WERK}/geldig.json")"

# 1: het laatste verplichte veld weglaten.
jq --arg v "$(jq -r '.required[-1]' "${WERK_REL}/schema.json")" 'del(.[$v])' \
  "${WERK_REL}/geldig.json" > "${WERK}/mist-verplicht.json"

# 2: een tekstveld een getal geven.
jq --arg v "$(jq -r 'first(.required[] as $r | select((.properties[$r]["$ref"] // "") != "" or .properties[$r].type == "string") | $r)' "${WERK_REL}/schema.json")" \
  '.[$v] = 12345' "${WERK_REL}/geldig.json" > "${WERK}/verkeerd-type.json"

# 3 en 4: een veld dat niemand kent, en een waarde die niemand kent.
jq '. + {aanleiding: "een veld uit een volgende versie"}' "${WERK_REL}/geldig.json" > "${WERK}/onbekend-veld.json"
jq '.soort = "run-hervat"' "${WERK_REL}/geldig.json" > "${WERK}/onbekende-enum.json"

GESLAAGD=0

toets() {
  _bestand="$1"; _verwacht="$2"; _wat="$3"
  if geldig "${_bestand}"; then _uitkomst=doorgelaten; else _uitkomst=afgekeurd; fi
  if [ "${_uitkomst}" = "${_verwacht}" ]; then
    printf '  ok    %-26s %s\n' "${_wat}" "${_uitkomst}"
    GESLAAGD=$((GESLAAGD + 1))
  else
    printf '  ROOD  %-26s %s, verwacht %s\n' "${_wat}" "${_uitkomst}" "${_verwacht}" >&2
    fout "de ontvangstvariant doet niet wat de belofte zegt"
  fi
}

echo "toets-ontvangstschemas: vier kanaries op RunGestartPayload"
toets mist-verplicht.json  afgekeurd   "verplicht veld ontbreekt"
toets verkeerd-type.json   afgekeurd   "verkeerd type"
toets onbekend-veld.json   doorgelaten "onbekend veld"
toets onbekende-enum.json  doorgelaten "onbekende enum-waarde"

verwacht_minstens "${GESLAAGD}" 4 "kanaries op de ontvangstvariant"
rm -rf "${WERK}"
echo "toets-ontvangstschemas: ${GESLAAGD} kanaries, de vorm wordt afgedwongen en de woordenschat niet"
