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

# --- elk scenario zijn eigen inhoud ------------------------------------------------------------
#
# Tot 0.11.1 gaf elke scenarioId scenario 01 terug: er was één example in de spec en dus één
# body voor alle id's. showcase-website toonde de stappen van 01 onder de kop van 00, en juist
# het verschil tussen die twee is wat deze showcase te vertellen heeft.

for ID in 00 01; do
  HAAL="${WERK}/scenario-${ID}.json"
  STATUS="$(curl -sS -o "${HAAL}" -w '%{http_code}' "http://localhost:${POORT}/v1/scenarios/${ID}")"
  [ "${STATUS}" = "200" ] || fout "GET /v1/scenarios/${ID} gaf ${STATUS}"
  GEKREGEN="$(jq -r '.id' < "${HAAL}")"
  [ "${GEKREGEN}" = "${ID}" ] \
    || fout "GET /v1/scenarios/${ID} gaf scenario ${GEKREGEN} — dan bedient de bundel elk id met dezelfde body"

  # En het aantal stappen komt uit de stamdata in de bundel zelf, niet uit dit script.
  VERWACHT_STAPPEN="$(jq -r --arg id "${ID}" \
    '.routes[] | select(.operationId == "haalScenario") | .bodyPerId[$id].stappen | length' \
    < "${WERK}/bundel/stub-data.json")"
  GEZIEN_STAPPEN="$(jq -r '.stappen | length' < "${HAAL}")"
  [ "${GEZIEN_STAPPEN}" = "${VERWACHT_STAPPEN}" ] \
    || fout "scenario ${ID} leverde ${GEZIEN_STAPPEN} stappen, ${VERWACHT_STAPPEN} in de stamdata"
  echo "  ok    GET /v1/scenarios/${ID} geeft scenario ${ID} met ${GEZIEN_STAPPEN} stappen"
done

ONBEKEND="${WERK}/onbekend.json"
STATUS="$(curl -sS -o "${ONBEKEND}" -w '%{http_code}' "http://localhost:${POORT}/v1/scenarios/42")"
[ "${STATUS}" = "404" ] \
  || fout "een onbekende scenarioId gaf ${STATUS} en geen 404 — de spec beschrijft daar SCENARIO_ONBEKEND"
jq -e '.code == "SCENARIO_ONBEKEND"' < "${ONBEKEND}" >/dev/null \
  || fout "de 404 draagt niet de code uit de spec"
echo "  ok    een onbekende scenarioId geeft 404 SCENARIO_ONBEKEND"

# --- de verbinding open, en de momentopname erop ---------------------------------------------
#
# --max-time is het vangnet: gaat er iets mis, dan faalt dit in plaats van te hangen.

UITVOER="${WERK}/stream.txt"
: > "${UITVOER}"
# De grens staat ruim: een volledige opname van scenario 01 is 84 berichten op 400 ms, dus
# ruim een halve minuut, en daar komt de wachttijd op de hartslag nog bij. Dit is een vangnet
# tegen hangen en geen meetlat — te krap zetten maakt de toets rood op zijn eigen klok.
curl -fsS -N --max-time 150 "http://localhost:${POORT}/v1/runs/stream" > "${UITVOER}" 2>/dev/null &
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

# --- verbinden terwijl de run loopt -------------------------------------------------------------
#
# Dit pad is door squad 2 gemeten en niet door ons: de stub stuurde de openingsregel van de
# opname, dus `run: null` terwijl er een run liep. Hun reducer zette scenarioId op null en kon
# de stapberichten erna nergens aan hangen. Wij hadden dat als beperking in de README gezet in
# plaats van als toets, en daarmee stond er niets tussen.

sleep 3
TWEEDE_STROOM="${WERK}/stream2.txt"
curl -fsS -N --max-time 3 "http://localhost:${POORT}/v1/runs/stream" > "${TWEEDE_STROOM}" 2>/dev/null || true

MIDDENIN="$(grep -m1 '^data: ' "${TWEEDE_STROOM}" | sed 's/^data: //')"
[ -n "${MIDDENIN}" ] || fout "een tweede verbinding tijdens de run kreeg geen momentopname"

printf '%s' "${MIDDENIN}" | jq -e --arg runid "${RUNID}" \
  '.soort == "momentopname" and .run.runId == $runid' >/dev/null \
  || fout "de momentopname midden in de run draagt niet de lopende run — dat is precies wat squad 2 stukliep"

# De stand moet meebewegen met wat er verstuurd is. Na drie seconden op 400ms per bericht zijn
# er stappen afgerond; blijft dit op nul staan, dan stuurt de stub een beginstand.
printf '%s' "${MIDDENIN}" | jq -e '.afgerondeStappen | length > 0' >/dev/null \
  || fout "de momentopname midden in de run meldt geen afgeronde stappen, terwijl er al berichten uit zijn"
echo "  ok    verbinden tijdens de run geeft de stand van die run"

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
verwacht_minstens "${BERICHTEN:-0}" "${VERWACHT}" "berichten uit de stream van de bundel"
# En niet meer dan dat: te veel berichten betekent dat er iets in de stroom zit wat niet in
# de opname staat, en dat is net zo goed drift als te weinig.
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
