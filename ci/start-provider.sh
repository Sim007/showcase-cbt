#!/usr/bin/env bash
#
# Zet de echte kant van showcase-CBT neer: de provider en zijn runner.
#
#   start-provider.sh [providerversie]        standaard de versie hieronder
#   start-provider.sh --stop                  beide weer weg
#
# **Twee processen en niet één, en dat is geen omslachtigheid.** De provider draait in een
# container en serveert `scenario-api` en `run-stream`; de runner draait op de host en start
# het scenario dat gevraagd wordt. Zou de provider dat zelf doen, dan had hij de Docker-socket
# nodig — root-equivalent op deze machine — plus een mount van de repository. De afweging
# staat in docs/security.md.
#
# Zonder runner neemt de provider geen start aan: `POST /v1/runs` geeft dan 503 in plaats van
# de knop stil aan te nemen en er niets mee te doen.
#
# Poort 8090 is niet vrij te kiezen: showcase-website heeft dat adres in zijn instellingen, en
# de browser lost het op — geen servicenaam dus. De stubbundel gebruikt dezelfde poort, dus
# die twee draaien niet tegelijk.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${CBT_ROOT}"

NAAM="cbt-provider"
POORT=8090
VERSIE="${1:-0.3.0}"

if [ "${VERSIE}" = "--stop" ]; then
  pkill -f "${CBT_ROOT}/ci/runner.sh" 2>/dev/null || true
  docker rm -f "${NAAM}" >/dev/null 2>&1 || true
  echo "provider en runner gestopt"
  exit 0
fi

docker image inspect "cbt/provider:${VERSIE}" >/dev/null 2>&1 \
  || { echo "geen image cbt/provider:${VERSIE}. Draai eerst ci/bouw-provider.sh" >&2; exit 1; }

docker rm -f "${NAAM}" >/dev/null 2>&1 || true
docker run -d --name "${NAAM}" -p "${POORT}:8090" "cbt/provider:${VERSIE}" >/dev/null
echo "provider: cbt/provider:${VERSIE} op http://localhost:${POORT}"

# De runner op de achtergrond, met zijn uitvoer waar hij te lezen is. Hij hoort bij deze
# provider en niet bij een scenario, dus hij start en stopt hiermee mee.
mkdir -p "${CBT_ROOT}/build"
nohup "${CBT_ROOT}/ci/runner.sh" "http://localhost:${POORT}" \
  > "${CBT_ROOT}/build/runner.log" 2>&1 &
echo "runner:   gestart, log in build/runner.log"

echo
echo "  showcase-website: http://localhost:5173"
echo "  stoppen:          ci/start-provider.sh --stop"
