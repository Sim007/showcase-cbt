#!/usr/bin/env bash
#
# Pipeline 3 van 4: het deelsysteem naar Test.
#
#   pipeline-test.sh <deelsysteem> <deelsysteemversie>
#
# Test blijft staan en houdt een toestand: hier draait een bepaalde deelsysteemversie. De
# gate is dat pipeline 2 groen was — daar is de inhoud van de grens aangetoond, en daarom
# volstaat hier dat het loopt.
#
# Geen contractverificatie: die hoort op de CI-omgeving, waar het deelsysteem alleen staat
# en een run goedkoop is. Herhalen verplaatst werk naar een duurdere plek.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fout() {
  echo "pipeline-test: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fout "gebruik: pipeline-test.sh <deelsysteem> <deelsysteemversie>"

DEELSYSTEEM="$1"
VERSIE="$2"
WAARDEN="${CBT_ROOT}/omgevingen/test.env"

# shellcheck disable=SC1090
. "${WAARDEN}"
POORT_VAR="$(echo "${DEELSYSTEEM}" | tr '[:lower:]' '[:upper:]')_API_POORT"
POORT="$(eval echo "\${${POORT_VAR}}")"

# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

echo "== ${DEELSYSTEEM} ${VERSIE} naar Test =="
rapport_start "${DEELSYSTEEM} ${VERSIE} → Test"

stap "deploy op Test" "${CBT_ROOT}/ci/deploy.sh" "${DEELSYSTEEM}" "${VERSIE}" test
stap "smoke van ${DEELSYSTEEM}" "${CBT_ROOT}/ci/smoke.sh" "${DEELSYSTEEM}" "http://${DEELSYSTEEM}-api:${POORT#*:}" cbt-test
bijzonderheid "$(grep -oE '[0-9]+ passed' "${STAP_LOG}" | tail -1)"

rapport_oordeel "Oordeel: groen. Het deelsysteem draait op Test en de keten loopt."
echo "klaar: ${DEELSYSTEEM} ${VERSIE} draait op Test"
