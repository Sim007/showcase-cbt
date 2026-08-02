#!/usr/bin/env bash
#
# Wacht tot elke container van een omgeving gezond is, en faalt als dat niet gebeurt.
#
#   wacht-op-gezond.sh <omgeving> <compose-bestand> [extra-compose...]
#
# Dit script bestaat omdat het alternatief stil is. Een wachtlus die afloopt en daarna
# gewoon doorgaat, laat de volgende stap falen op een reden die niets met de fout te maken
# heeft — en dan zoek je op de verkeerde plek. Hier valt het meteen, met de status van
# elke container erbij.

set -euo pipefail

fout() {
  echo "wacht-op-gezond: $*" >&2
  exit 1
}

[ "$#" -ge 2 ] || fout "gebruik: wacht-op-gezond.sh <omgeving> <compose-bestand> [extra...]"

OMGEVING="$1"
shift

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARGS="-p ${OMGEVING}"
for bestand in "$@"; do
  case "${bestand}" in
    /*) ARGS="${ARGS} -f ${bestand}" ;;
    *)  ARGS="${ARGS} -f ${CBT_ROOT}/${bestand}" ;;
  esac
done

POGINGEN="${WACHT_POGINGEN:-40}"
INTERVAL="${WACHT_INTERVAL:-2}"

for _ in $(seq 1 "${POGINGEN}"); do
  # shellcheck disable=SC2086
  STATUS="$(docker compose ${ARGS} ps --format '{{.Service}} {{.State}} {{.Health}}' 2>/dev/null || true)"

  [ -n "${STATUS}" ] || fout "omgeving ${OMGEVING} heeft geen containers. Is de deploy gelukt?"

  ONGEZOND="$(printf '%s\n' "${STATUS}" | grep -v ' running healthy$' || true)"
  if [ -z "${ONGEZOND}" ]; then
    echo "gezond: $(printf '%s\n' "${STATUS}" | wc -l | tr -d ' ') containers op ${OMGEVING}"
    exit 0
  fi

  sleep "${INTERVAL}"
done

echo "wacht-op-gezond: niet alle containers op ${OMGEVING} zijn gezond geworden binnen $((POGINGEN * INTERVAL))s:" >&2
printf '%s\n' "${STATUS}" | sed 's/^/  /' >&2
exit 1
