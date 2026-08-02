#!/usr/bin/env bash
#
# Haalt een omgeving weg, inclusief zijn netwerk als er niets meer in hangt.
#
#   opruimen.sh <omgeving> <deelsysteem>...
#
# Een CI-omgeving is efemeer, en dat is alleen waar als iemand hem ook echt opruimt. Blijft
# hij staan, dan houdt hij poorten bezet en is de volgende run onbetrouwbaar.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ "$#" -ge 2 ] || { echo "gebruik: opruimen.sh <omgeving> <deelsysteem>..." >&2; exit 1; }

OMGEVING="$1"
shift

export OMGEVING_NETWERK="cbt-${OMGEVING}"

for DEELSYSTEEM in "$@"; do
  CHART="${CBT_ROOT}/deelsystemen/${DEELSYSTEEM}/docker-compose.yml"
  [ -f "${CHART}" ] || continue
  docker compose -p "${OMGEVING}-${DEELSYSTEEM}" -f "${CHART}" -f "${CBT_ROOT}/compose/stub.yml" \
    down --remove-orphans >/dev/null 2>&1 || true
  docker compose -p "${OMGEVING}-${DEELSYSTEEM}" -f "${CHART}" \
    down --remove-orphans >/dev/null 2>&1 || true
done

# Het netwerk verdwijnt pas als er niets meer in hangt; dat faalt vanzelf als een andere
# omgeving hem nog gebruikt, en dat is precies de bedoeling.
docker network rm "cbt-${OMGEVING}" >/dev/null 2>&1 || true

echo "opgeruimd: ${OMGEVING}"
