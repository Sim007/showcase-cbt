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
# Sinds run-stream 0.11.0 houdt de stub zijn verbinding open. Een `curl -N` die vroeger
# vanzelf stopte, blijft nu hangen — en een toets die hangt is erger dan een die faalt: hij
# meldt niets, ook geen rood, en een pipeline die niets meldt lijkt nog te draaien.
#
# Daarom leest deze toets **tot `run-afgerond`**, met een tijdslimiet als vangnet daaromheen.
# Niet tot de verbinding sluit, want die sluit niet meer. En niet tot een aantal berichten:
# dat aantal was mijn keuze en niet die van de opname, en dan toetst de gate zijn eigen
# aanname. Het aantal dat hij wél eist komt uit de fixture in de bundel zelf.
#
# HARTSLAG_MS staat hier laag. De spec zegt 20 seconden, en een run duurt er acht — zonder
# die schakelaar wordt de hartslag door geen enkele toets gezien en is "er is een heartbeat"
# opnieuw een bewering zonder iets eronder.

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
HARTSLAG_MS=1000
STREAM_PID=""
docker rm -f "${NAAM}" >/dev/null 2>&1 || true

# Draaien zoals de consumer hem draait: node, geen netwerk naar buiten, verder niets.
docker run -d --rm --name "${NAAM}" \
  --user "$(id -u):$(id -g)" \
  --volume "${WERK}/bundel:/b:ro" \
  --workdir /b \
  --publish "${POORT}:8090" \
  --env HOME=/tmp \
  --env "HARTSLAG_MS=${HARTSLAG_MS}" \
  "${NODE_IMAGE}" node stub.js >/dev/null \
  || fout "de bundel start niet"

opruimen() {
  if [ -n "${STREAM_PID}" ]; then
    kill "${STREAM_PID}" 2>/dev/null || true
    # Opeisen, anders meldt de shell de beëindigde taak zelf en staat er "Terminated" in de
    # uitvoer van een gate die groen is.
    wait "${STREAM_PID}" 2>/dev/null || true
    STREAM_PID=""
  fi
  docker rm -f "${NAAM}" >/dev/null 2>&1 || true
}
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

# --- de verbinding open, en de momentopname erop ---------------------------------------------
#
# --max-time is het vangnet: gaat er iets mis, dan faalt dit in plaats van te hangen.

UITVOER="${WERK}/stream.txt"
: > "${UITVOER}"
curl -fsS -N --max-time 60 "http://localhost:${POORT}/v1/runs/stream" > "${UITVOER}" 2>/dev/null &
STREAM_PID=$!

WACHT=0
until grep -q '^data: ' "${UITVOER}" 2>/dev/null; do
  WACHT=$((WACHT + 1))
  [ "${WACHT}" -lt 20 ] || fout "geen momentopname bij het verbinden"
  sleep 1
done

EERSTE="$(grep -m1 '^data: ' "${UITVOER}" | sed 's/^data: //')"
printf '%s' "${EERSTE}" | jq -e '.soort == "momentopname" and .run == null' >/dev/null \
  || fout "de momentopname bij verbinden draagt geen run: null — dat is de normale begintoestand van een sessie"
echo "  ok    verbinden geeft een momentopname met run: null"

# --- een run starten over dezelfde verbinding -------------------------------------------------

START="${WERK}/start.json"
STATUS="$(curl -sS -o "${START}" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"01"}' \
  "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "201" ] || fout "POST /v1/runs gaf ${STATUS} en geen 201"
# Via stdin en niet als bestandsnaam: jq draait in een container met de repo op /work, en
# een absoluut pad van deze kant bestaat daar niet.
RUNID="$(jq -r '.runId' < "${START}")"
[ -n "${RUNID}" ] && [ "${RUNID}" != "null" ] || fout "de 201 draagt geen runId"
echo "  ok    POST /v1/runs geeft 201 met runId ${RUNID}"

# De spec: er kan één run tegelijk lopen. Een stub die hier 201 blijft geven, weigert niet
# wat de echte kant weigert — en dat is zijn hele bestaansreden.
TWEEDE="${WERK}/tweede.json"
STATUS="$(curl -sS -o "${TWEEDE}" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"01"}' \
  "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "409" ] || fout "een tweede start tijdens een lopende run gaf ${STATUS} en geen 409"
grep -q "${RUNID}" "${TWEEDE}" \
  || fout "de 409 noemt niet het runId van de lopende run — dan wijst hij een andere run aan dan de stream afspeelt"
echo "  ok    tweede start tijdens de run geeft 409 met datzelfde runId"

# --- lezen tot run-afgerond --------------------------------------------------------------------

WACHT=0
until grep -q '"soort":"run-afgerond"' "${UITVOER}" 2>/dev/null; do
  WACHT=$((WACHT + 1))
  [ "${WACHT}" -lt 45 ] || fout "geen run-afgerond binnen 45s — de stream loopt niet af zoals de opname"
  sleep 1
done
echo "  ok    gelezen tot run-afgerond"

# Het aantal komt uit de opname in de bundel en niet uit dit script: één momentopname bij het
# verbinden, en daarna de opname zonder de zijne. Zo blijft de gate meebewegen met de fixture
# in plaats van met een getal dat ik ooit heb gekozen.
VERWACHT="$(wc -l < "${WERK}/bundel/runs/voltooid.jsonl" | tr -d ' ')"
BERICHTEN="$(grep -c '^data: ' "${UITVOER}" || true)"
[ "${BERICHTEN}" = "${VERWACHT}" ] \
  || fout "${BERICHTEN} berichten gelezen, ${VERWACHT} in de opname — de stream levert niet wat er is vastgelegd"
echo "  ok    ${BERICHTEN} berichten, precies de opname"

grep '^data: ' "${UITVOER}" | sed 's/^data: //' | jq -es 'all(has("soort"))' >/dev/null \
  || fout "niet elk bericht is JSON met een soort"
echo "  ok    elk bericht is JSON met een soort"

# Alles ná de momentopname hoort bij de run die zojuist gestart is. Droegen die berichten een
# ander nummer, dan volgt een consumer die op runId bijhoudt welke run loopt, de verkeerde.
ANDERE="$(grep '^data: ' "${UITVOER}" | sed 's/^data: //' | tail -n +2 \
  | jq -r 'select(.runId != null) | .runId' | grep -vc "^${RUNID}$" || true)"
[ "${ANDERE}" = "0" ] || fout "${ANDERE} berichten dragen een ander runId dan de 201"
echo "  ok    elk bericht van de run draagt ${RUNID}"

# --- de hartslag ----------------------------------------------------------------------------
#
# Nu is het stil: de run is afgelopen en de verbinding staat nog open. Precies de toestand
# waar de hartslag voor bestaat.

sleep "$(( (HARTSLAG_MS / 1000) + 2 ))"
grep -q '^: hartslag' "${UITVOER}" \
  || fout "geen hartslag op een stille verbinding — dan houdt 'de verbinding blijft open' het bij de eerste proxy niet"
echo "  ok    stille verbinding krijgt een hartslag"

# De verbinding staat er nog. Zou de stub hem na de run hebben gesloten, dan was curl gestopt.
kill -0 "${STREAM_PID}" 2>/dev/null \
  || fout "de verbinding is gesloten na de run — de consumer sluit hem, niet de provider"
echo "  ok    de verbinding staat na de run nog open"

opruimen
trap - EXIT
rm -rf "${WERK}"
echo "toets-stubbundel: de bundel draait, weigert wat hij moet weigeren en houdt zijn verbinding open"
