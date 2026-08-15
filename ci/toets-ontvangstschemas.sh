#!/usr/bin/env bash
#
# Toetst dat de ontvangstvariant nog iets afdwingt, en niet te veel doorlaat.
#
#   toets-ontvangstschemas.sh <map-met-schemas-relatief-aan-de-hoofdmap>
#
# De structurele controle in ontvangstschemas.sh telt sleutels: staat `required` er nog,
# kloppen de propertynamen. Dat is nodig en niet genoeg. Een transformatie die te ver gaat
# levert een schema op dat álles goedkeurt, en dan is elke gate erachter groen omdat er niets
# meer getoetst wordt — het patroon dat deze repository elders al vier keer is tegengekomen.
#
# Daarom gedrag in plaats van vorm. Per payloadschema vier kanaries, twee elke kant op:
#
#   afgekeurd   een bericht zonder verplicht veld
#   afgekeurd   een bericht met een verkeerd type
#   doorgelaten een bericht met een onbekend veld
#   doorgelaten een bericht met een onbekende enum-waarde
#
# De bovenste twee vangen een te gulle transformatie: gaat `required` per ongeluk mee eruit,
# dan komt kanarie 1 erdoor en wordt dit rood. De onderste twee vangen een te strenge: blijft
# `additionalProperties: false` staan, dan valt kanarie 3 en breekt elke additieve wijziging.
# Samen bracketten ze de transformatie.
#
# **Op álle payloadschema's en niet op één.** De eerste versie toetste alleen
# RunGestartPayload, met als reden dat dat het eenvoudigste schema was. Dat is een reden over
# gemak en niet over dekking: een kanarie die één van de zes schachten in gaat, bewaakt er
# vijf niet. De generator kon het aanvankelijk ook niet — hij vulde een genest object met {}
# en struikelde over `oneOf` — en dát was de echte reden dat er één stond. Nu volgt hij
# `$ref`, `oneOf` en geneste `required`, en gaan alle zes mee.

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

# Het geldige bericht wordt uit het schema afgeleid en niet met de hand geschreven. De eerste
# versie had `scenarioId` als verplicht veld in de fixtures staan; toen een wijziging dat veld
# legitiem uit `required` haalde, viel de kanarie om terwijl de transformatie in orde was. Een
# kanarie die aan de inhoud van vandaag hangt, meet de verkeerde belofte.
#
# De waarden komen uit de `example` van de spec. Een generator die "x" invult voldoet niet aan
# de `pattern` op `runId`, en dan wordt élk bericht afgekeurd — waarna de eerste twee kanaries
# groen staan op grond van een fout die niets met hun vraag te maken heeft. Vandaar ook de
# nulde controle hieronder: eerst aantonen dat het geldige bericht geldig is.
cat > "${WERK}/bouw.jq" <<'JQ'
def los($s; $doc):
  if ($s["$ref"] // "") != "" then $doc.components.schemas[$s["$ref"] | sub("^#/components/schemas/"; "")] else $s end;
def waarde($s0; $doc):
  los($s0; $doc) as $s1
  | (if ($s1.oneOf // $s1.anyOf) != null then los(($s1.oneOf // $s1.anyOf)[0]; $doc) else $s1 end) as $s
  | if $s.example != null then $s.example
    elif ($s.properties != null) then
      reduce (($s.required // [])[]) as $v ({}; . + { ($v): waarde($s.properties[$v]; $doc) })
    elif $s.type == "array" then (if $s.items != null then [ waarde($s.items; $doc) ] else [] end)
    elif $s.type == "integer" or $s.type == "number" then 1
    elif $s.type == "boolean" then true
    else "x" end;
. as $doc | (.required // []) as $req
| reduce $req[] as $v ({}; . + { ($v): waarde($doc.properties[$v]; $doc) })
JQ

geldig() {
  ajv validate -s "${WERK_REL}/schema.json" -d "${WERK_REL}/$1" --strict=false >/dev/null 2>&1
}

GESLAAGD=0
SCHEMAS=0

toets() {
  _bestand="$1"; _verwacht="$2"; _wat="$3"
  if geldig "${_bestand}"; then _uitkomst=doorgelaten; else _uitkomst=afgekeurd; fi
  if [ "${_uitkomst}" = "${_verwacht}" ]; then
    GESLAAGD=$((GESLAAGD + 1))
  else
    printf '  ROOD  %-22s %-26s %s, verwacht %s\n' "${NAAM}" "${_wat}" "${_uitkomst}" "${_verwacht}" >&2
    fout "de ontvangstvariant van ${NAAM} doet niet wat de belofte zegt"
  fi
}

echo "toets-ontvangstschemas: vier kanaries per payloadschema"

for pad in "${MAP}"/*Payload.json; do
  [ -f "${pad}" ] || continue
  NAAM="$(basename "${pad}" .json)"
  SCHEMAS=$((SCHEMAS + 1))

  cp "${pad}" "${WERK}/schema.json"
  jq -f "${WERK_REL}/bouw.jq" "${WERK_REL}/schema.json" > "${WERK}/geldig.json"

  VERPLICHT="$(jq -r '(.required // []) | length' "${WERK_REL}/schema.json")"
  verwacht_minstens "${VERPLICHT}" 1 "verplichte velden in ${NAAM}"

  # Nulde controle: zonder een aantoonbaar geldig bericht zeggen de vier hieronder niets.
  geldig geldig.json \
    || fout "${NAAM}: het geldige bericht wordt afgekeurd, dus de kanaries zeggen niets.
  Waarschijnlijk mist een schema een bruikbare example.
  Bericht: $(cat "${WERK}/geldig.json")"

  jq --arg v "$(jq -r '.required[-1]' "${WERK_REL}/schema.json")" 'del(.[$v])' \
    "${WERK_REL}/geldig.json" > "${WERK}/mist-verplicht.json"

  jq --arg v "$(jq -r 'first(.required[] as $r
                       | select((.properties[$r]["$ref"] // "") != "" or .properties[$r].type == "string")
                       | $r)' "${WERK_REL}/schema.json")" \
    '.[$v] = 12345' "${WERK_REL}/geldig.json" > "${WERK}/verkeerd-type.json"

  jq '. + {aanleiding: "een veld uit een volgende versie"}' \
    "${WERK_REL}/geldig.json" > "${WERK}/onbekend-veld.json"
  jq '.soort = "run-hervat"' "${WERK_REL}/geldig.json" > "${WERK}/onbekende-enum.json"

  toets mist-verplicht.json  afgekeurd   "verplicht veld ontbreekt"
  toets verkeerd-type.json   afgekeurd   "verkeerd type"
  toets onbekend-veld.json   doorgelaten "onbekend veld"
  toets onbekende-enum.json  doorgelaten "onbekende enum-waarde"

  printf '  ok    %-22s vier kanaries\n' "${NAAM}"
done

verwacht_minstens "${SCHEMAS}" 1 "payloadschema's met kanaries"
verwacht_minstens "${GESLAAGD}" "$((SCHEMAS * 4))" "geslaagde kanaries"
rm -rf "${WERK}"
echo "toets-ontvangstschemas: ${SCHEMAS} schema's, ${GESLAAGD} kanaries — de vorm wordt afgedwongen en de woordenschat niet"
