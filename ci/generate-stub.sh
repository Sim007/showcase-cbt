#!/usr/bin/env bash
#
# Genereert de stub waarmee een consumer zijn buur nabootst, uit de spec uit het register.
#
#   generate-stub.sh <groep> <artifact> <versie> [scenariomap]
#
# De stub bestaat alleen op Build en in de CI-omgeving, wordt elke run opnieuw gemaakt en
# wordt nooit gecommit. Zie 1.6 van docs/showcase-cbt.md.
#
# Stap 7 en 8 — schemavalidatie en dekkingscheck — zijn geen test maar een
# artefactcontrole, in dezelfde familie als de drift-check.
#
# Padconventie: het gereedschap draait in een container die de hoofdmap als /work ziet,
# dus krijgt het relatieve paden. De shell zelf werkt met absolute.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "generate-stub: $*" >&2
  exit 1
}

[ "$#" -ge 3 ] || fout "gebruik: generate-stub.sh <groep> <artifact> <versie> [scenariomap]"

GROEP="$1"
ARTIFACT="$2"
VERSIE="$3"
SCENARIOMAP="${4:-}"

REL="build/stub"
WERKMAP="${CBT_ROOT}/${REL}"
MAPPINGS="${WERKMAP}/mappings"
TMP="${WERKMAP}/tmp"

# --- stap 1: de spec komt uit het register, nooit van schijf --------------------------

SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}")"
SPEC_REL="${SPEC#"${CBT_ROOT}/"}"

rm -rf "${MAPPINGS}" "${TMP}"
mkdir -p "${MAPPINGS}" "${TMP}"

# --- stap 2: spec parsen --------------------------------------------------------------

yq -o=json '.' "${SPEC_REL}" > "${TMP}/spec.json"

# Per operation de laagste 2xx-response: dat is de standaardmapping. Andere statuscodes
# vragen een matcher die niet uit de spec volgt en horen daarom bij de scenario's.
jq -c '
  .paths | to_entries[] as $pad
  | $pad.value | to_entries[] as $methode
  | select($methode.key | IN("get","post","put","patch","delete"))
  | ($methode.value.responses | to_entries
      | map(select(.key | test("^2"))) | sort_by(.key) | first) as $ok
  | {
      operationId: ($methode.value.operationId // "\($methode.key)"),
      methode: ($methode.key | ascii_upcase),
      padpatroon: ($pad.key | gsub("\\{[^}]+\\}"; "[^/]+")),
      status: ($ok.key // "geen"),
      example: ($ok.value.content."application/json".example // null),
      schemaRef: ($ok.value.content."application/json".schema."$ref" // null),
      schema: ($ok.value.content."application/json".schema // null),
      heeftRequestBody: ($methode.value.requestBody != null)
    }' "${REL}/tmp/spec.json" > "${TMP}/werklijst.jsonl"

[ -s "${TMP}/werklijst.jsonl" ] || fout "geen operations gevonden in de spec"

# --- stap 3 t/m 5: matcher, body, wegschrijven ----------------------------------------

AANTAL=0
while IFS= read -r regel; do
  OP="$(printf '%s' "${regel}" | jq -r '.operationId')"
  STATUS="$(printf '%s' "${regel}" | jq -r '.status')"

  [ "${STATUS}" != "geen" ] || fout "${OP}: geen 2xx-response in de spec"

  # Stap 4 — de body komt uit de example en nergens anders. Een body uit het schema
  # gegenereerd levert typegeldige maar betekenisloze waarden op, en dan verliest de
  # consumertest zijn waarde.
  LEEG="$(printf '%s' "${regel}" | jq -r '.example | if . == null or . == {} then "ja" else "nee" end')"
  [ "${LEEG}" = "nee" ] \
    || fout "${OP}: response ${STATUS} heeft geen of een lege example. Elke response in de spec hoort er een te hebben"

  # Stap 3 — padparameters. OpenAPI-paden zijn templates; WireMock matcht daar niet
  # vanzelf op, dus wordt {paymentId} een patroon.
  printf '%s' "${regel}" | jq '{
    priority: 5,
    request: ({
        method: .methode,
        urlPathPattern: .padpatroon
      } + (if .heeftRequestBody
           then { headers: { "Content-Type": { contains: "application/json" } } }
           else {} end)),
    response: {
      status: (.status | tonumber),
      headers: { "Content-Type": "application/json" },
      jsonBody: .example
    }
  }' > "${MAPPINGS}/${OP}.json"

  AANTAL=$((AANTAL + 1))
done < "${TMP}/werklijst.jsonl"

echo "stap 3-5: ${AANTAL} mappings gegenereerd uit ${GROEP}/${ARTIFACT} ${VERSIE}"

# --- stap 6: scenario-mappings --------------------------------------------------------
#
# Een spec beschrijft per status één response; een consumertest heeft ook een afgewezen
# betaling nodig. Die scheidslijn is semantiek en volgt niet uit de spec. Handgeschreven
# scenario's mogen daarom, mits ze door dezelfde validatie gaan als de gegenereerde.
# Wat niet mag: een test die zijn eigen mapping meebrengt.

SCENARIOS=0
: > "${TMP}/scenario-schemas.jsonl"
if [ -n "${SCENARIOMAP}" ]; then
  [ -d "${CBT_ROOT}/${SCENARIOMAP}" ] || fout "scenariomap niet gevonden: ${SCENARIOMAP}"
  for bestand in "${CBT_ROOT}/${SCENARIOMAP}"/*.json; do
    [ -e "${bestand}" ] || break
    BRON="${SCENARIOMAP}/$(basename "${bestand}")"
    NAAM="scenario-$(basename "${bestand}" .json)"

    REF="$(jq -r '."x-schema" // empty' "${BRON}")"
    [ -n "${REF}" ] \
      || fout "${BRON}: geen \"x-schema\". Een scenario-mapping hoort te zeggen aan welk schema zijn body voldoet"
    jq -c -n --arg naam "${NAAM}" --arg ref "${REF}" '{naam: $naam, ref: $ref}' \
      >> "${TMP}/scenario-schemas.jsonl"

    # WireMock weigert onbekende velden, dus de toelichting en het schema blijven in het
    # bronbestand achter. De mapping die hij te zien krijgt, bevat alleen wat hij kent.
    jq 'del(._toelichting, ."x-schema")' "${BRON}" > "${MAPPINGS}/${NAAM}.json"
    SCENARIOS=$((SCENARIOS + 1))
  done
  echo "stap 6: ${SCENARIOS} scenario-mappings toegevoegd uit ${SCENARIOMAP}"
fi

# --- stap 7: elke body tegen zijn responseschema --------------------------------------

jq '{ components: .components }' "${REL}/tmp/spec.json" > "${TMP}/componenten.json"

GEVALIDEERD=0
for mapping in "${MAPPINGS}"/*.json; do
  NAAM="$(basename "${mapping}" .json)"

  # Bij een gegenereerde mapping staat het schema in de werklijst; een scenario-mapping
  # noemt het zelf in "x-schema", zodat hij door dezelfde controle gaat.
  REF="$(jq -r --arg op "${NAAM}" 'select(.operationId == $op) | .schemaRef // empty' "${REL}/tmp/werklijst.jsonl" | head -1)"

  if [ -n "${REF}" ]; then
    jq --arg ref "${REF}" '. + {"$ref": $ref}' "${REL}/tmp/componenten.json" > "${TMP}/schema-${NAAM}.json"
  else
    # Niet elke response verwijst naar een benoemd schema. Een lijst staat vaak inline als
    # {type: array, items: {$ref}}, en dat is geen tekortkoming van die spec maar geldig
    # OpenAPI. Het schema staat er dan gewoon, alleen niet achter een $ref.
    INLINE="$(jq -c --arg op "${NAAM}" 'select(.operationId == $op) | .schema // empty' "${REL}/tmp/werklijst.jsonl" | head -1)"
    if [ -n "${INLINE}" ] && [ "${INLINE}" != "null" ]; then
      jq --argjson s "${INLINE}" '. + $s' "${REL}/tmp/componenten.json" > "${TMP}/schema-${NAAM}.json"
      REF="het inline schema"
    else
      REF="$(jq -r --arg naam "${NAAM}" 'select(.naam == $naam) | .ref' "${REL}/tmp/scenario-schemas.jsonl" | head -1)"
      [ -n "${REF}" ] || fout "${NAAM}: geen schema om tegen te valideren"
      jq --arg ref "${REF}" '. + {"$ref": $ref}' "${REL}/tmp/componenten.json" > "${TMP}/schema-${NAAM}.json"
    fi
  fi
  jq '.response.jsonBody' "${REL}/mappings/${NAAM}.json" > "${TMP}/body-${NAAM}.json"

  ajv validate --strict=false -c ajv-formats \
    -s "${REL}/tmp/schema-${NAAM}.json" \
    -d "${REL}/tmp/body-${NAAM}.json" >/dev/null 2>&1 \
    || fout "${NAAM}: responsebody voldoet niet aan ${REF}"

  GEVALIDEERD=$((GEVALIDEERD + 1))
done

echo "stap 7: ${GEVALIDEERD} bodies voldoen aan hun responseschema"

# --- stap 8: dekkingscheck ------------------------------------------------------------

while IFS= read -r regel; do
  OP="$(printf '%s' "${regel}" | jq -r '.operationId')"
  [ -f "${MAPPINGS}/${OP}.json" ] || fout "dekking: ${OP} heeft geen mapping"
done < "${TMP}/werklijst.jsonl"

echo "stap 8: elke operation heeft minstens één mapping"
echo "${MAPPINGS}"
