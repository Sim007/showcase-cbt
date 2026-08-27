#!/usr/bin/env bash
#
# Draait de provider en toetst zijn gedrag.
#
#   toets-provider.sh <providerversie>
#
# **Deze toets bestond niet.** De provider werd in `controle.sh` alleen gebóuwd. Alles wat er
# over hem is gemeld — de momentopname midden in een run, de 409, de 503 — is één keer met de
# hand gemeten en werd bij geen enkele push opnieuw nagekeken. Dat is dezelfde soort belofte
# als "twee draaiwijzen, allebei getoetst" en het heeft dezelfde waarde: die van de dag waarop
# iemand het deed.
#
# **Zonder een echte pipeline.** De provider vertaalt kale gebeurtenissen naar berichten; wat
# die gebeurtenissen veroorzaakt doet er voor hem niet toe. Deze toets voert ze rechtstreeks
# aan, en is daarmee in seconden klaar in plaats van in anderhalve minuut. Wat hij níét dekt,
# is de runner die ze in het echt aanlevert — dat is een demo en die draait niet bij een push.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "toets-provider: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fout "gebruik: toets-provider.sh <providerversie>"

VERSIE="$1"
docker image inspect "cbt/provider:${VERSIE}" >/dev/null 2>&1 \
  || fout "geen image cbt/provider:${VERSIE}. Draai eerst ci/bouw-provider.sh"

POORT=8398
NAAM="cbt-providertoets"
POLL_PID=""
WERK="${CBT_ROOT}/build/providertoets"
rm -rf "${WERK}"; mkdir -p "${WERK}"

docker rm -f "${NAAM}" >/dev/null 2>&1 || true
docker run -d --rm --name "${NAAM}" --publish "${POORT}:8090" \
  --env RUNNER_STIL_MS=3000 \
  "cbt/provider:${VERSIE}" >/dev/null || fout "de provider start niet"

opruimen() {
  if [ -n "${POLL_PID}" ]; then
    kill "${POLL_PID}" 2>/dev/null || true
    wait "${POLL_PID}" 2>/dev/null || true
    POLL_PID=""
  fi
  docker rm -f "${NAAM}" >/dev/null 2>&1 || true
}
trap opruimen EXIT

WACHT=0
until curl -fsS "http://localhost:${POORT}/v1/scenarios" >/dev/null 2>&1; do
  WACHT=$((WACHT + 1))
  [ "${WACHT}" -lt 30 ] || fout "de provider luistert niet op poort ${POORT}"
  sleep 1
done
echo "  ok    de provider luistert"

# --- de scenario's ---------------------------------------------------------------------------

for ID in 00 01; do
  STATUS="$(curl -sS -o "${WERK}/${ID}.json" -w '%{http_code}' "http://localhost:${POORT}/v1/scenarios/${ID}")"
  [ "${STATUS}" = "200" ] || fout "GET /v1/scenarios/${ID} gaf ${STATUS}"
  [ "$(jq -r '.id' < "${WERK}/${ID}.json")" = "${ID}" ] || fout "scenario ${ID} gaf een ander id terug"
  echo "  ok    GET /v1/scenarios/${ID} geeft $(jq -r '.stappen | length' < "${WERK}/${ID}.json") stappen"
done

STATUS="$(curl -sS -o "${WERK}/onbekend.json" -w '%{http_code}' "http://localhost:${POORT}/v1/scenarios/07")"
[ "${STATUS}" = "404" ] || fout "een onbekend scenario gaf ${STATUS} en geen 404"
jq -e '.message | contains("07")' < "${WERK}/onbekend.json" >/dev/null \
  || fout "de 404 noemt niet het id dat gevraagd is"
echo "  ok    een onbekend scenario geeft 404, met dat id erin"

# --- de preflight, want zonder hem komt de POST er nooit ----------------------------------------
#
# **Dit ontbrak, en het kostte een demo.** Een POST met een JSON-body is geen simple request:
# de browser vraagt eerst toestemming met OPTIONS. De provider had geen OPTIONS-tak, dus die
# vraag kreeg 404 en de POST werd nooit verstuurd — in het providerlog stond niets, en het
# beeld was "ik druk en er gebeurt niets".
#
# Dat het bij mij altijd werkte, kwam doordat `curl -X POST` geen preflight stuurt. Deze toets
# stuurt hem daarom zoals de browser hem stuurt, mét de drie kopteksten die hem veroorzaken.
# Een toets die het verzoek anders vormt dan de consumer, meet iets anders dan de grens.

for PAD in /v1/runs /v1/runs/run-000000/afbreken; do
  KOP="${WERK}/preflight.txt"
  STATUS="$(curl -sS -D "${KOP}" -o /dev/null -w '%{http_code}' -X OPTIONS \
    -H 'Origin: http://localhost:5173' \
    -H 'Access-Control-Request-Method: POST' \
    -H 'Access-Control-Request-Headers: content-type' \
    "http://localhost:${POORT}${PAD}")"
  [ "${STATUS}" = "204" ] \
    || fout "de preflight op ${PAD} gaf ${STATUS} en geen 204 — dan verstuurt de browser de POST nooit"
  grep -qi 'access-control-allow-methods' "${KOP}" || fout "de preflight op ${PAD} noemt geen toegestane methoden"
  grep -qi 'access-control-allow-headers' "${KOP}" || fout "de preflight op ${PAD} noemt geen toegestane kopteksten"
  echo "  ok    preflight op ${PAD} geeft 204 met de drie kopteksten"
done

# --- zonder runner: 503, en dat is de helft die bewijst dat het net werkt ----------------------
#
# Er polt hier nog niemand, dus de provider hoort een start te weigeren. Zonder deze helft
# toont de rest alleen aan dat hij zwíjgt — niet dat hij het geval kan herkennen.

STATUS="$(curl -sS -o "${WERK}/geen-runner.json" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"00"}' "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "503" ] \
  || fout "zonder runner gaf een start ${STATUS} en geen 503 — dan neemt hij een knop aan waar niemand op reageert"
jq -e '.code == "GEEN_RUNNER"' < "${WERK}/geen-runner.json" >/dev/null || fout "de 503 draagt niet de juiste code"
echo "  ok    zonder runner geeft een start 503 GEEN_RUNNER"

# --- met een pollende runner: geen 503 meer -----------------------------------------------------
#
# Een runner die alleen maar luistert, meer heeft de provider niet nodig om te weten dat er
# iemand is. Hij blíjft pollen — ook straks als er een run loopt, want dat is precies wat er
# fout was: de echte runner zweeg tijdens zijn werk en de provider concludeerde daaruit dat
# hij weg was.

( while true; do curl -fsS "http://localhost:${POORT}/intern/werk" >/dev/null 2>&1 || true; sleep 1; done ) &
POLL_PID=$!
sleep 2

START="${WERK}/start.json"
STATUS="$(curl -sS -o "${START}" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"00"}' "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "201" ] || fout "met een pollende runner gaf een start ${STATUS} en geen 201"
RUNID="$(jq -r '.runId' < "${START}")"
echo "  ok    met een runner geeft een start 201 met runId ${RUNID}"

# --- tijdens de run: 409 en geen 503 ------------------------------------------------------------

STATUS="$(curl -sS -o "${WERK}/tweede.json" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"01"}' "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "409" ] \
  || fout "een tweede start tijdens een lopende run gaf ${STATUS} en geen 409"
grep -q "${RUNID}" "${WERK}/tweede.json" || fout "de 409 noemt niet het runId van de lopende run"
echo "  ok    tijdens de run geeft een tweede start 409, met dat runId"

# De gebeurtenissen die de pipeline zou sturen, rechtstreeks aangevoerd.
gebeurtenis() {
  curl -fsS -o /dev/null -X POST -H 'Content-Type: application/json' --data "$1" \
    "http://localhost:${POORT}/intern/gebeurtenis" || fout "gebeurtenis geweigerd: $1"
}

TIJD="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
gebeurtenis "{\"soort\":\"run-gestart\",\"tijd\":\"${TIJD}\",\"scenarioId\":\"00\"}"
gebeurtenis "{\"soort\":\"stap-gestart\",\"tijd\":\"${TIJD}\",\"omschrijving\":\"unit\"}"
gebeurtenis "{\"soort\":\"stap-afgerond\",\"tijd\":\"${TIJD}\",\"omschrijving\":\"unit\",\"uitkomst\":\"geslaagd\"}"

# --- en direct ná de run: 201, niet 503 ----------------------------------------------------------
#
# Dit is het geval dat op 27 augustus misging. De run is klaar, de runner leeft en polt, en
# dan hoort een nieuwe start gewoon aangenomen te worden.

gebeurtenis "{\"soort\":\"run-afgerond\",\"tijd\":\"${TIJD}\",\"reden\":\"voltooid\"}"

STATUS="$(curl -sS -o "${WERK}/opnieuw.json" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"00"}' "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "201" ] \
  || fout "direct na de run gaf een start ${STATUS} en geen 201 — dan denkt de provider dat de runner weg is terwijl hij polt"
echo "  ok    direct na de run geeft een start 201 en geen 503"

# Die tweede run ook netjes afronden, anders is de provider nog bezet en antwoordt hij straks
# 409 in plaats van 503 — dan zou de tegenproef hieronder het verkeerde meten.
sleep 2
gebeurtenis "{\"soort\":\"run-gestart\",\"tijd\":\"${TIJD}\",\"scenarioId\":\"00\"}"
gebeurtenis "{\"soort\":\"run-afgerond\",\"tijd\":\"${TIJD}\",\"reden\":\"voltooid\"}"

# --- de runner weg: de 503 komt terug ------------------------------------------------------------
#
# De tweede helft van de tegenproef. Een gate die het geval niet meer kan reproduceren bewijst
# niets; hier gaat de runner werkelijk weg en dan hoort het antwoord te veranderen.

kill "${POLL_PID}" 2>/dev/null || true
wait "${POLL_PID}" 2>/dev/null || true
POLL_PID=""
sleep 5

STATUS="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"scenarioId":"01"}' "http://localhost:${POORT}/v1/runs")"
[ "${STATUS}" = "503" ] \
  || fout "met een weggevallen runner gaf een start ${STATUS} en geen 503 — dan is het net verdwenen"
echo "  ok    valt de runner weg, dan komt de 503 terug"

# --- elk verzoek staat in het log ------------------------------------------------------------------

docker logs "${NAAM}" > "${WERK}/provider.log" 2>&1

toon_en_faal() {
  echo "toets-provider: $1. Wat er wél in het log staat:" >&2
  grep -E '(GET|POST) /' "${WERK}/provider.log" | sed 's/^/    /' >&2
  exit 1
}

REGELS="$(grep -cE '(GET|POST) /' "${WERK}/provider.log" || true)"
verwacht_minstens "${REGELS}" 8 "gelogde verzoeken"
grep -q "POST /v1/runs 201 ${RUNID}" "${WERK}/provider.log" \
  || toon_en_faal "de succesvolle start staat niet met zijn runId in het log"
grep -q "POST /v1/runs 503" "${WERK}/provider.log" \
  || toon_en_faal "de geweigerde start staat niet in het log"
echo "  ok    ${REGELS} verzoeken gelogd, met status en runId"

opruimen
trap - EXIT
rm -rf "${WERK}"
echo "toets-provider: de provider serveert, weigert wat hij moet weigeren, en laat een spoor na"
