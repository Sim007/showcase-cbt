#!/usr/bin/env bash
#
# Genereert de stub van de run-stream, uit de spec uit het register.
#
#   generate-stream-stub.sh <groep> <stream-artifact> <versie> <scenario-artifact> <scenario-versie>
#
# De tegenhanger van generate-stub.sh, voor een grens zonder request-response. Een stream
# heeft geen operaties om te beantwoorden maar een verloop om af te spelen, dus wat hier
# gegenereerd wordt is één run: de berichten in de volgorde waarin ze zouden komen.
#
# Twee bronnen, allebei uit het register en niet van schijf:
#   de AsyncAPI-spec   levert de vorm van elk bericht, uit zijn example
#   de OpenAPI-spec    levert welke stappen er zijn, uit het example van het scenario
#
# Dat de volgorde uit de stamdata komt is geen omweg maar de bedoeling: een stub die zelf
# stappen verzint, toont een run die nergens beschreven staat.
#
# Server-Sent Events over WireMock, met chunkedDribbleDelay zodat de berichten na elkaar
# binnenkomen in plaats van in één klap. Geen extra gereedschap: de stub die de REST-kant
# serveert doet ook deze.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "generate-stream-stub: $*" >&2
  exit 1
}

[ "$#" -eq 5 ] || fout "gebruik: generate-stream-stub.sh <groep> <stream-artifact> <versie> <scenario-artifact> <scenario-versie>"

GROEP="$1"
STREAM="$2"
STREAM_VERSIE="$3"
SCENARIO="$4"
SCENARIO_VERSIE="$5"

UIT="${CBT_ROOT}/build/stub"
TMP="${UIT}/tmp"
REL="build/stub"
mkdir -p "${UIT}/mappings" "${TMP}"

# Schrijft één mapping bij en ruimt de map niet leeg, anders dan generate-stub.sh. Een
# grens die zowel REST als een stream heeft, wordt door één stub bediend: eerst de
# operaties, dan deze erbij.
[ -f "${UIT}/mappings/run-stream.json" ] && rm -f "${UIT}/mappings/run-stream.json"

# --- stap 1: beide specs ophalen, altijd uit het register -------------------------------

STREAM_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}")"
SCENARIO_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}")"

# Het gereedschap draait in een container die de hoofdmap als /work ziet, dus krijgt het
# relatieve paden. De shell zelf werkt met absolute — zelfde afspraak als in generate-stub.
yq -o=json '.' "${STREAM_SPEC#"${CBT_ROOT}/"}"   > "${TMP}/stream.json"
yq -o=json '.' "${SCENARIO_SPEC#"${CBT_ROOT}/"}" > "${TMP}/scenario.json"

echo "stap 1: ${GROEP}/${STREAM} ${STREAM_VERSIE} en ${GROEP}/${SCENARIO} ${SCENARIO_VERSIE} opgehaald"

# --- stap 2: de stappen uit het scenario-example ----------------------------------------

jq -c '.paths."/v1/scenarios/{scenarioId}".get.responses."200".content."application/json".example
       // error("geen example op haalScenario — zonder example valt er geen run af te spelen")' \
  "${REL}/tmp/scenario.json" > "${TMP}/scenario-example.json"

STAPPEN="$(jq -r '.stappen | length' "${REL}/tmp/scenario-example.json")"
[ "${STAPPEN}" -gt 0 ] || fout "het scenario-example heeft geen stappen"
RUN_ID="$(jq -r '.id' "${REL}/tmp/scenario-example.json")"

echo "stap 2: ${STAPPEN} stappen in het example van scenario ${RUN_ID}"

# --- stap 3: het verloop samenstellen ---------------------------------------------------
#
# Eén bericht per regel, met de naam van het berichtschema erbij zodat stap 4 elk bericht
# tegen zijn eigen schema kan houden. De tijd loopt op; POSIX kent geen date-rekenen, dus
# awk doet het.

tijdstip() {
  awk -v n="$1" 'BEGIN {
    s = 9*3600 + 12*60 + 44 + n
    printf "2026-08-06T%02d:%02d:%02dZ", int(s/3600), int(s%3600/60), s%60
  }'
}

: > "${TMP}/verloop.jsonl"
N=0

regel() {
  printf '%s\t%s\n' "$1" "$2" >> "${TMP}/verloop.jsonl"
}

# Bij verbinden eerst de stand van zaken. Hier: een run die net begint, dus nog niets
# afgerond. Zwijgen zou dubbelzinnig zijn — daarom altijd een momentopname.
regel MomentopnamePayload "$(jq -cn --arg t "$(tijdstip $N)" \
  '{soort:"momentopname", tijd:$t, run:null, afgerondeStappen:[]}')"
N=$((N + 1))

regel RunGestartPayload "$(jq -cn --arg t "$(tijdstip $N)" --arg s "${RUN_ID}" \
  '{soort:"run-gestart", tijd:$t, runId:"run-7c41a9", scenarioId:$s}')"
N=$((N + 1))

I=0
while [ "${I}" -lt "${STAPPEN}" ]; do
  NUMMER="$(jq -r --argjson i "${I}" '.stappen[$i].nummer' "${REL}/tmp/scenario-example.json")"
  CLI="$(jq -r --argjson i "${I}" '.stappen[$i].cli' "${REL}/tmp/scenario-example.json")"

  regel StapGestartPayload "$(jq -cn --arg t "$(tijdstip $N)" --argjson nr "${NUMMER}" \
    '{soort:"stap-gestart", tijd:$t, runId:"run-7c41a9", stapNummer:$nr}')"
  N=$((N + 1))

  regel CliUitvoerPayload "$(jq -cn --arg t "$(tijdstip $N)" --argjson nr "${NUMMER}" --arg r "$ ${CLI}" \
    '{soort:"cli-uitvoer", tijd:$t, runId:"run-7c41a9", stapNummer:$nr, regel:$r}')"
  N=$((N + 1))

  regel StapAfgerondPayload "$(jq -cn --arg t "$(tijdstip $N)" --argjson nr "${NUMMER}" \
    '{soort:"stap-afgerond", tijd:$t, runId:"run-7c41a9", stapNummer:$nr, uitkomst:"groen"}')"
  N=$((N + 1))

  I=$((I + 1))
done

regel RunAfgerondPayload "$(jq -cn --arg t "$(tijdstip $N)" \
  '{soort:"run-afgerond", tijd:$t, runId:"run-7c41a9", reden:"voltooid"}')"

BERICHTEN="$(wc -l < "${TMP}/verloop.jsonl" | tr -d ' ')"
echo "stap 3: ${BERICHTEN} berichten samengesteld"

# --- stap 4: elk bericht tegen zijn eigen schema -----------------------------------------
#
# Dezelfde artefactcontrole als stap 7 van generate-stub.sh, en om dezelfde reden: een stub
# die iets stuurt wat niet aan de spec voldoet, leert de aanroeper iets aan wat straks
# nergens op slaat.

jq "{ components: { schemas: .components.schemas } }" "${REL}/tmp/stream.json" > "${TMP}/stream-componenten.json"

# De lus leest van fd 3 en niet van stdin: elk gereedschap hierbinnen draait in een
# interactieve container en zou anders de rest van het bestand opslokken. Dan stopt de lus
# na één bericht en meldt de controle groen over veertien berichten die niemand bekeek.
GEVALIDEERD=0
while IFS="$(printf '\t')" read -r schema bericht <&3; do
  jq --arg ref "#/components/schemas/${schema}" '. + {"$ref": $ref}' \
    "${REL}/tmp/stream-componenten.json" > "${TMP}/s-${GEVALIDEERD}.json"
  printf '%s' "${bericht}" > "${TMP}/b-${GEVALIDEERD}.json"

  ajv validate --strict=false -c ajv-formats \
    -s "${REL}/tmp/s-${GEVALIDEERD}.json" \
    -d "${REL}/tmp/b-${GEVALIDEERD}.json" >/dev/null 2>&1 \
    || fout "bericht ${GEVALIDEERD} voldoet niet aan ${schema}: ${bericht}"

  GEVALIDEERD=$((GEVALIDEERD + 1))
done 3< "${TMP}/verloop.jsonl"

echo "stap 4: ${GEVALIDEERD} berichten voldoen aan hun payloadschema"

# --- stap 5: de mapping wegschrijven -----------------------------------------------------

PAD="$(jq -r '.channels | keys | .[0]' "${REL}/tmp/stream.json")"

# Elk bericht als één SSE-event. De lege regel erna sluit het event af; dat is het formaat
# en niet iets van ons.
cut -f2 "${TMP}/verloop.jsonl" | awk '{ printf "data: %s\n\n", $0 }' > "${TMP}/body.txt"

jq -n --arg pad "${PAD}" --rawfile body "${REL}/tmp/body.txt" --argjson n "${BERICHTEN}" \
  '{
     request: { method: "GET", urlPath: $pad },
     response: {
       status: 200,
       headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-cache" },
       body: $body,
       chunkedDribbleDelay: { numberOfChunks: $n, totalDuration: ($n * 400) }
     }
   }' > "${UIT}/mappings/run-stream.json"

echo "stap 5: ${UIT#"${CBT_ROOT}/"}/mappings/run-stream.json — ${BERICHTEN} events over $(( BERICHTEN * 400 / 1000 ))s"
