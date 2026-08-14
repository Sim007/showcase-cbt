#!/usr/bin/env bash
#
# Leidt de ontvangstvariant van elk berichtschema af uit een AsyncAPI, en publiceert die als
# los JSON-artifact in het werkregister.
#
#   ontvangstschemas.sh <groep> <stream-artifact> <versie>
#
# Waarom dit bestaat: op payloadniveau heeft `run-stream` geen compatibiliteitsnet. Gemeten
# op 2026-08-14 — de COMPATIBILITY-regel is voor artifacttype ASYNCAPI een no-op (zelfs alle
# kanalen weghalen levert HTTP 200), en `asyncapi diff` zet elke schemawijziging in
# unclassified. Voor artifacttype JSON dóét die regel wél inhoudelijk werk, met benoemde
# oorzaken. Vandaar deze afleiding: de payloads apart registreren zodat het register ze kan
# vergelijken.
#
# **De ontvangstvariant en niet het gepubliceerde schema.** Dat is de kern en het is gemeten:
# op het strenge schema — `additionalProperties: false` — wordt élke additieve wijziging
# afgekeurd met PROPERTY_SCHEMAS_NARROWED, en dat is terecht, want een ontvanger die dat
# schema streng toepast breekt op een onbekend veld. Alleen: dat is niet de belofte die wij
# doen. Wij beloven dat een consumer een onbekend veld mag negeren, en dát staat in de
# ontvangstvariant. Compatibiliteit is een uitspraak over de ontvanger, dus hoort de gate op
# het artefact dat de ontvanger beschrijft. Zie docs/besluiten.md, 2026-08-14.
#
# **Afgeleide artefacten gaan niet het kanaal in.** Deze artifacts staan in het werkregister,
# vóór de gate, en komen niet in een release. Zou showcase-website erop kunnen pinnen, dan
# was het een tweede contract — en dan onderhandel je straks over iets dat niemand als
# contract heeft bedoeld.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

REGISTRY_URL="${REGISTRY_URL:-http://localhost:8080}"
API="${REGISTRY_URL}/apis/registry/v3"

fout() {
  echo "ontvangstschemas: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fout "gebruik: ontvangstschemas.sh <groep> <stream-artifact> <versie>"

GROEP="$1"
STREAM="$2"
VERSIE="$3"

WERKMAP="${CBT_ROOT}/build/ontvangstschemas"
REL="build/ontvangstschemas"
rm -rf "${WERKMAP}"
mkdir -p "${WERKMAP}"

# --- 1: de spec uit het werkregister ------------------------------------------------------

SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${STREAM}" "${VERSIE}")"
yq -o=json '.' "${SPEC#"${CBT_ROOT}/"}" > "${WERKMAP}/stream.json"

# --- 2: de transformatie ------------------------------------------------------------------
#
# Twee dingen eruit, en niets anders:
#
#   additionalProperties  een onbekend veld mag geen fout zijn
#   enum                  een onbekende waarde in een bekend veld mag geen fout zijn
#
# Wat blijft: required, de propertynamen, en de types. Die dragen de belofte die wél geldt.
# Dezelfde transformatie als in bouw-stubbundel.sh — daar gaat hij mee de bundel in, hier het
# register. Eén afleiding, twee bestemmingen, geen tweede bron.

PAYLOADS="$(jq -r '.components.schemas | keys[] | select(endswith("Payload"))' "${REL}/stream.json")"
AANTAL_PAYLOADS="$(printf '%s\n' "${PAYLOADS}" | grep -c . || true)"
verwacht_minstens "${AANTAL_PAYLOADS}" 1 "payloadschema's in ${STREAM}"

# Alleen de schema's die deze payload werkelijk gebruikt gaan mee, transitief gevolgd. De
# eerste versie kopieerde `components.schemas` in zijn geheel in elk document, en dan
# verschilt elk van de zes zodra er één wijzigt — waarna alle zes een nieuwe versie krijgen.
# Dat is precies de koppeling die apart versioneren moet vermijden, en hij zat in de
# afleiding zelf. Gemeten: een veld toevoegen aan één payload gaf zes publicaties.
for naam in ${PAYLOADS}; do
  jq --arg n "${naam}" '
    def verwijzingen($x): [$x | .. | objects | select(has("$ref"))
                           | .["$ref"] | sub("^#/components/schemas/"; "")];
    . as $doc
    | $doc.components.schemas[$n] as $wortel
    | ([$n] + verwijzingen($wortel)) as $start
    | (reduce range(0; 10) as $_ ($start;
         . as $huidig
         | ($huidig + ([$huidig[] | verwijzingen($doc.components.schemas[.])] | flatten))
         | unique)) as $nodig
    | ($wortel + {components: {schemas: ($doc.components.schemas
                                         | with_entries(select(.key | IN($nodig[]))))}})
    | walk(if type == "object" then del(.additionalProperties, .enum) else . end)' \
    "${REL}/stream.json" > "${WERKMAP}/${naam}.json"
done

# --- 3: de afleiding is aantoonbaar, niet aangenomen --------------------------------------
#
# Een transformatie die te veel weghaalt levert een schema op dat alles goedkeurt, en dan is
# elke gate erachter groen omdat hij niets meer toetst. Hier de structurele helft; de
# gedragshelft staat in ci/toets-ontvangstschemas.sh en draait hieronder.

WEG_VOOR="$(grep -c 'additionalProperties\|"enum"' "${WERKMAP}/stream.json" || true)"
verwacht_minstens "${WEG_VOOR}" 1 "te verwijderen sleutels in de bron"

for naam in ${PAYLOADS}; do
  # Niets van wat blijven moet, mag verdwenen zijn.
  BRON_PROPS="$(jq -r --arg n "${naam}" '.components.schemas[$n].properties | keys | join(",")' "${REL}/stream.json")"
  DOEL_PROPS="$(jq -r '.properties | keys | join(",")' "${REL}/${naam}.json")"
  [ "${BRON_PROPS}" = "${DOEL_PROPS}" ] \
    || fout "${naam}: propertynamen wijken af na de transformatie
  bron: ${BRON_PROPS}
  doel: ${DOEL_PROPS}"

  BRON_REQ="$(jq -c --arg n "${naam}" '.components.schemas[$n].required // []' "${REL}/stream.json")"
  DOEL_REQ="$(jq -c '.required // []' "${REL}/${naam}.json")"
  [ "${BRON_REQ}" = "${DOEL_REQ}" ] \
    || fout "${naam}: required is gewijzigd door de transformatie — ${BRON_REQ} werd ${DOEL_REQ}"

  # En wat weg moest, is ook echt weg.
  RESTANT="$(grep -c 'additionalProperties\|"enum"' "${REL}/${naam}.json" || true)"
  [ "${RESTANT}" = "0" ] \
    || fout "${naam}: er staan nog ${RESTANT} strenge sleutels in de ontvangstvariant"
done

echo "ontvangstschemas: ${AANTAL_PAYLOADS} schema's afgeleid, required en properties ongewijzigd"

# --- 4: het gedrag, met vier kanaries -----------------------------------------------------

"${CBT_ROOT}/ci/toets-ontvangstschemas.sh" "${REL}" | sed 's/^/  /'

# --- 5: publiceren, elk met zijn eigen levensloop ------------------------------------------
#
# Apart versioneren en niet meebewegen met de stream: vijf artifacts een bump geven omdat de
# zesde wijzigde, geeft vijf versienummers die niets betekenen. Dat is hetzelfde bezwaar
# waarom scenario-api en run-stream niet aan elkaar hangen.
#
# Het nummer is de streamversie waarin dít schema voor het laatst wijzigde. Dat is
# afleidbaar en verzint niets: verandert er niets, dan komt er geen versie bij.

NIEUW=0
ONGEWIJZIGD=0
for naam in ${PAYLOADS}; do
  ARTIFACT="${STREAM}-$(printf '%s' "${naam}" | tr '[:upper:]' '[:lower:]')"
  ART_URL="${API}/groups/${GROEP}/artifacts/${ARTIFACT}"

  HUIDIG="$(curl -fsS "${ART_URL}/versions/branch=latest/content" 2>/dev/null || true)"
  if [ -n "${HUIDIG}" ]; then
    printf '%s' "${HUIDIG}" > "${WERKMAP}/${naam}.huidig.json"
    if jq -S . "${REL}/${naam}.huidig.json" > "${WERKMAP}/a.json" 2>/dev/null \
       && jq -S . "${REL}/${naam}.json" > "${WERKMAP}/b.json" 2>/dev/null \
       && cmp -s "${WERKMAP}/a.json" "${WERKMAP}/b.json"; then
      ONGEWIJZIGD=$((ONGEWIJZIGD + 1))
      continue
    fi
  fi

  jq -Rs --arg v "${VERSIE}" '{version: $v, content: {content: ., contentType: "application/json"}}' \
    < "${WERKMAP}/${naam}.json" > "${WERKMAP}/payload.json"

  if [ -z "${HUIDIG}" ]; then
    jq -Rs --arg id "${ARTIFACT}" --arg v "${VERSIE}" \
      '{artifactId: $id, artifactType: "JSON",
        firstVersion: {version: $v, content: {content: ., contentType: "application/json"}}}' \
      < "${WERKMAP}/${naam}.json" > "${WERKMAP}/payload.json"
    curl -fsS -X POST -H "Content-Type: application/json" --data-binary "@${WERKMAP}/payload.json" \
      "${API}/groups/${GROEP}/artifacts?ifExists=FAIL" >/dev/null \
      || fout "kon ${ARTIFACT} niet aanmaken"
    curl -fsS -X POST -H "Content-Type: application/json" \
      -d '{"ruleType":"COMPATIBILITY","config":"FORWARD"}' \
      "${ART_URL}/rules" >/dev/null \
      || fout "kon de compatibility rule niet op FORWARD zetten voor ${ARTIFACT}"
  else
    # Hier vuurt het net: het register weigert een wijziging die showcase-website breekt.
    #
    # Zonder -f, want juist de foutbody is het interessante deel: Apicurio noemt de oorzaak
    # met naam. Met -f gooit curl die weg en houd je "HTTP 400" over, en dan is de gate wel
    # rood maar niet leesbaar.
    HTTPCODE="$(curl -sS -X POST -H "Content-Type: application/json" \
      --data-binary "@${WERKMAP}/payload.json" \
      -o "${WERKMAP}/antwoord.json" -w '%{http_code}' "${ART_URL}/versions")"

    if [ "${HTTPCODE}" != "200" ]; then
      VORIGE="$(curl -fsS "${ART_URL}/versions?limit=500" 2>/dev/null \
        | jq -r '[.versions[]?.version] | last // "onbekend"' 2>/dev/null || echo onbekend)"
      echo "ontvangstschemas: het register weigert ${ARTIFACT} ${VERSIE} (HTTP ${HTTPCODE})." >&2
      echo "  Dit breekt een consumer die op ${VORIGE} pint." >&2
      jq -r '.causes[]? | "    \(.description) op \(.context)"' "${REL}/antwoord.json" 2>/dev/null >&2 \
        || sed 's/^/    /' "${WERKMAP}/antwoord.json" >&2
      fout "compatibiliteitsgate rood op ${ARTIFACT}"
    fi
  fi
  NIEUW=$((NIEUW + 1))
done

verwacht_minstens "$((NIEUW + ONGEWIJZIGD))" 1 "payloadschema's beoordeeld"
echo "ontvangstschemas: ${NIEUW} gepubliceerd, ${ONGEWIJZIGD} ongewijzigd — compatibility rule FORWARD"
