#!/usr/bin/env bash
#
# Bouwt de stubbundel voor showcase-website: uitpakken, starten, klaar.
#
#   bouw-stubbundel.sh <groep> <scenario-artifact> <stream-artifact> <versie>
#
# De consumer heeft Node en verder niets: geen Docker, geen JDK, en geen betrouwbaar pad
# naar de npm-registry — `npx @stoplight/prism-cli` bleef daar hangen. De bundel bevat
# daarom zijn eigen afhankelijkheden. Na het uitpakken is er geen netwerk meer nodig.
#
# Dat is de tweede keer dat een aanname over gereedschap de levering blokkeerde: eerst
# Docker, toen npx. Wat je meelevert is onderdeel van de afspraak, ook als het niet in de
# spec staat.
#
# Alles in de bundel komt uit de gepubliceerde specs. De WireMock-stub voor ons eigen
# gebruik blijft bestaan; deze vervangt hem niet.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "bouw-stubbundel: $*" >&2
  exit 1
}

[ "$#" -eq 4 ] || fout "gebruik: bouw-stubbundel.sh <groep> <scenario-artifact> <stream-artifact> <versie>"

GROEP="$1"
SCENARIO="$2"
STREAM="$3"
VERSIE="$4"

BUNDEL="${CBT_ROOT}/build/bundel"
REL="build/bundel"
rm -rf "${BUNDEL}"
mkdir -p "${BUNDEL}/runs" "${BUNDEL}/schemas" "${BUNDEL}/tmp"

# --- stap 1: de specs uit het register --------------------------------------------------

SCENARIO_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${SCENARIO}" "${VERSIE}")"
STREAM_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${STREAM}" "${VERSIE}")"

yq -o=json '.' "${SCENARIO_SPEC#"${CBT_ROOT}/"}" > "${BUNDEL}/tmp/scenario.json"
yq -o=json '.' "${STREAM_SPEC#"${CBT_ROOT}/"}"   > "${BUNDEL}/tmp/stream.json"

cp "${SCENARIO_SPEC}" "${BUNDEL}/openapi.yaml"
cp "${STREAM_SPEC}"   "${BUNDEL}/asyncapi.yaml"

echo "stap 1: ${SCENARIO} en ${STREAM} ${VERSIE} opgehaald uit het register"

# --- stap 2: de routes, met hun requestschema -------------------------------------------
#
# Wat de stub serveert komt hier vandaan en nergens anders. De body is de example uit de
# spec; het requestschema is dat van de spec, zodat de stub weigert wat de echte kant ook
# zou weigeren.

STREAMPAD="$(jq -r '.channels | keys | .[0]' "${REL}/tmp/stream.json")"

jq --arg streampad "${STREAMPAD}" '
  . as $doc
  | {
      streampad: $streampad,
      origin: ($doc.components.headers.AccessControlAllowOrigin.schema.example // "*"),
      componenten: { components: $doc.components },
      routes: [
        .paths | to_entries[] as $pad
        | $pad.value | to_entries[] as $methode
        | select($methode.key | IN("get","post","put","patch","delete","options"))
        | ($methode.value.responses | to_entries
            | map(select(.key | test("^2"))) | sort_by(.key) | first) as $ok
        | {
            methode: ($methode.key | ascii_upcase),
            patroon: ("^" + ($pad.key | gsub("\\{[^}]+\\}"; "[^/]+")) + "$"),
            status: ($ok.key | tonumber),
            kopteksten: (
              (if $ok.value.content then { "Content-Type": "application/json" } else {} end)
              + (($ok.value.headers // {}) | to_entries | map({
                  key: .key,
                  value: ((if .value["$ref"]
                           then $doc.components.headers[.value["$ref"] | sub("^#/components/headers/"; "")]
                           else .value end)
                          | (.schema.example // (.schema.enum // [])[0] // ""))
                }) | from_entries)
            ),
            body: ($ok.value.content."application/json".example // null),
            verzoekSchema: ($methode.value.requestBody.content."application/json".schema // null)
          }
      ]
    }' "${REL}/tmp/scenario.json" > "${BUNDEL}/stub-data.json"

ROUTES="$(jq -r '.routes | length' "${REL}/stub-data.json")"
[ "${ROUTES}" -gt 0 ] || fout "geen routes uit de spec gehaald"
echo "stap 2: ${ROUTES} routes, waarvan $(jq -r '[.routes[] | select(.verzoekSchema)] | length' "${REL}/stub-data.json") met een requestschema"

# --- stap 3: de fixtures ----------------------------------------------------------

RUNS="${CBT_ROOT}/contracts/${GROEP}/${STREAM}/${VERSIE}/runs"
[ -d "${RUNS}" ] || fout "geen runs in ${RUNS}. Draai eerst ci/generate-stream-stub.sh"
cp "${RUNS}"/*.jsonl "${BUNDEL}/runs/"
echo "stap 3: $(ls "${BUNDEL}/runs" | wc -l | tr -d ' ') fixtures"

# --- stap 4: het ontvangstschema ---------------------------------------------------------
#
# De replayer toetst niets. Dit schema is er zodat de consumer de berichten in zijn eigen
# testsuite wél kan valideren — met ajv, die toch al in de bundel zit.
#
# Nadrukkelijk niet de gepubliceerde schema's zelf. Die staan streng: additionalProperties
# op false en enums met vaste waarden. Dat is een ware uitspraak over wat wij versturen en
# een nuttige controle aan ónze kant, maar aan de ontvangende kant maakt hij elke additieve
# wijziging brekend — en dat is precies wat scenario 02 niet-brekend noemt.
#
# Er gaat er dus maar één mee, en dat is deze. Twee schemasets naast elkaar zou betekenen
# dat er nog steeds een verkeerde te pakken valt; dan is de val verplaatst en niet weg.
#
# Wat eruit gaat en waarom, in de volgorde van de drie tolerantie-eisen:
#   additionalProperties  een onbekend veld mag geen fout zijn
#   enum op Soort         een onbekend berichttype mag geen fout zijn
#   enum op de rest       een onbekende waarde in een bekend veld mag geen fout zijn
#
# Wat overblijft toetst de vorm en niet de woordenschat. Zie de README van de bundel.

jq '{ components: { schemas: (.components.schemas
       | walk(if type == "object" then del(.additionalProperties, .enum) else . end)) } }' \
  "${REL}/tmp/stream.json" > "${BUNDEL}/tmp/ontvangst.json"

# De index: van de waarde die in het bericht staat naar het schema dat erbij hoort. Zonder
# dit moet de consumer zelf een switch bijhouden, en die vergeet hij bij te werken zodra er
# een berichtsoort bij komt — terwijl "onbekend type overslaan" juist een opzoeking hoort te
# zijn die vanzelf goed gaat.
jq '.components.messages
    | to_entries
    | map({ key: .value.name, value: (.value.payload["$ref"] | split("/") | last) })
    | from_entries' "${REL}/tmp/stream.json" > "${BUNDEL}/tmp/index.json"

jq --slurpfile idx "${REL}/tmp/index.json" '. + { soortIndex: $idx[0] }' \
  "${REL}/tmp/ontvangst.json" > "${BUNDEL}/schemas/berichten-ontvangst.json"

AANTAL_SCHEMAS="$(jq -r '.components.schemas | keys | length' "${REL}/schemas/berichten-ontvangst.json")"
verwacht_minstens "${AANTAL_SCHEMAS}" 6 "berichtschema's in het ontvangstschema"
echo "stap 4: ${AANTAL_SCHEMAS} berichtschema's als ontvangstvariant, met een index op soort"

# --- stap 5: de afhankelijkheden mee ------------------------------------------------------

docker run --rm --user "$(id -u):$(id -g)" \
  --volume "${BUNDEL}:/b" --workdir /b --env HOME=/b \
  "$NODE_IMAGE" npm install --no-fund --no-audit --omit=dev --silent \
  "ajv@${AJV_VERSIE_BUNDEL}" "ajv-formats@${AJV_FORMATS_VERSIE}" 2>&1 | tail -2

cp "${CBT_ROOT}/ci/stubbundel/stub.js" "${BUNDEL}/stub.js"
cp "${CBT_ROOT}/ci/stubbundel/README.md" "${BUNDEL}/README.md"
rm -rf "${BUNDEL}/tmp" "${BUNDEL}/.npm"

echo "stap 5: afhankelijkheden meegepakt ($(du -sh "${BUNDEL}/node_modules" | cut -f1))"

# --- stap 6: inpakken ---------------------------------------------------------------------

UIT="${CBT_ROOT}/build/${SCENARIO}-stubbundel-${VERSIE}.tgz"
tar -czf "${UIT}" -C "${CBT_ROOT}/build" bundel
echo "stap 6: ${UIT#"${CBT_ROOT}/"} ($(du -h "${UIT}" | cut -f1))"
