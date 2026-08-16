#!/usr/bin/env bash
#
# Draait de stubbundel en toetst dat hij doet wat zijn README belooft.
#
#   toets-stubbundel.sh <bundelversie>
#
# **Deze toets bestond niet.** De README van de repository zegt "twee draaiwijzen, allebei
# getoetst" en toont wat je hoort te zien — maar dat was één keer met de hand nagekeken. Er
# was geen enkel script dat de bundel startte en zijn stream las. Wat er wél getoetst werd,
# was of hij te bóuwen viel.
#
# Dat verschil gaat pas echt tellen nu de stub zijn verbinding openhoudt: een handmatige
# `curl -N` die vroeger vanzelf stopte, blijft dan hangen. En een toets die hangt is erger
# dan een die faalt — hij meldt niets, ook geen rood, en een pipeline die niets meldt lijkt
# nog te draaien.
#
# Daarom leest deze toets **tot een verwacht aantal berichten, met een tijdslimiet** en niet
# tot de verbinding sluit. Dat is dezelfde regel als `verwacht_minstens`: een lus die op EOF
# wacht telt niet wat hij zag, en komt bij nul berichten net zo vrolijk terug als bij twintig.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "toets-stubbundel: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fout "gebruik: toets-stubbundel.sh <bundelversie>"

VERSIE="$1"
TGZ="${CBT_ROOT}/build/stubbundel-${VERSIE}.tgz"
[ -f "${TGZ}" ] || fout "geen bundel op build/stubbundel-${VERSIE}.tgz. Draai eerst ci/bouw-stubbundel.sh"

WERK="${CBT_ROOT}/build/bundeltoets"
rm -rf "${WERK}"
mkdir -p "${WERK}"
tar -xzf "${TGZ}" -C "${WERK}"

POORT=8399
NAAM="cbt-bundeltoets"
docker rm -f "${NAAM}" >/dev/null 2>&1 || true

# Draaien zoals de consumer hem draait: node, geen netwerk naar buiten, verder niets.
docker run -d --rm --name "${NAAM}" \
  --user "$(id -u):$(id -g)" \
  --volume "${WERK}/bundel:/b:ro" \
  --workdir /b \
  --publish "${POORT}:8090" \
  --env HOME=/tmp \
  "${NODE_IMAGE}" node stub.js >/dev/null \
  || fout "de bundel start niet"

opruimen() { docker rm -f "${NAAM}" >/dev/null 2>&1 || true; }
trap opruimen EXIT

# Wachten tot hij luistert, met een grens. Zonder grens hangt dit bij een stub die niet
# opkomt, en dat is precies wat we hier niet willen.
WACHT=0
until curl -fsS "http://localhost:${POORT}/v1/scenarios" >/dev/null 2>&1; do
  WACHT=$((WACHT + 1))
  [ "${WACHT}" -lt 30 ] || fout "de bundel luistert niet op poort ${POORT}"
  sleep 1
done
echo "  ok    de bundel luistert"

# --- de REST-kant --------------------------------------------------------------------------

STATUS="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"01","onzin":true}' \
  "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "400" ] \
  || fout "een niet-gedeclareerd veld gaf ${STATUS} en geen 400 — dan weigert de bundel niet wat de echte kant weigert"
echo "  ok    onbekend veld op POST /v1/runs geeft 400"

# --- de stream, begrensd gelezen -------------------------------------------------------------
#
# --max-time is de grens die ervoor zorgt dat dit faalt in plaats van hangt. Het aantal
# berichten is de grens die ervoor zorgt dat het iets vaststelt.

VERWACHT_MINSTENS=5
UITVOER="${WERK}/stream.txt"
curl -fsS -N --max-time 12 "http://localhost:${POORT}/v1/runs/stream" > "${UITVOER}" 2>/dev/null || true

BERICHTEN="$(grep -c '^data: ' "${UITVOER}" || true)"
verwacht_minstens "${BERICHTEN:-0}" "${VERWACHT_MINSTENS}" "berichten uit de stream van de bundel"
echo "  ok    ${BERICHTEN} berichten gelezen uit de stream"

# Elke regel moet geldige JSON zijn met een `soort`. Een replayer die halve regels stuurt is
# aan de leeskant niet te onderscheiden van een trage verbinding.
ZONDER_SOORT=0
while IFS= read -r regel; do
  printf '%s' "${regel#data: }" | jq -e 'has("soort")' >/dev/null 2>&1 || ZONDER_SOORT=$((ZONDER_SOORT + 1))
done < <(grep '^data: ' "${UITVOER}" | head -20)
[ "${ZONDER_SOORT}" -eq 0 ] || fout "${ZONDER_SOORT} berichten zonder bruikbare soort"
echo "  ok    elk bericht is JSON met een soort"

opruimen
trap - EXIT
rm -rf "${WERK}"
echo "toets-stubbundel: de bundel draait, weigert wat hij moet weigeren en levert ${BERICHTEN} berichten"
