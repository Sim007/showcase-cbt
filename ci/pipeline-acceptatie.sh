#!/usr/bin/env bash
#
# Pipeline 4 van 4: het deelsysteem naar Acceptatie.
#
#   pipeline-acceptatie.sh <deelsysteem> <deelsysteemversie>
#
# De gate is dat Test groen staat voor dit deelsysteem. Acceptatie is de enige omgeving met
# koppelingen naar buiten; waarom hij er is en wat hem overbodig zou maken, staat in
# bijlage A van docs/showcase-cbt.md.
#
# Geen smoke hier: dat is op Test al aangetoond. Wat hier draait is de gebruikersflow, en
# alleen die van dit deelsysteem — de rest is niet door deze deploy geraakt.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fout() {
  echo "pipeline-acceptatie: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fout "gebruik: pipeline-acceptatie.sh <deelsysteem> <deelsysteemversie>"

DEELSYSTEEM="$1"
VERSIE="$2"

# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

echo "== ${DEELSYSTEEM} ${VERSIE} naar Acceptatie =="
rapport_start

stap "deploy op Acceptatie" "${CBT_ROOT}/ci/deploy.sh" "${DEELSYSTEEM}" "${VERSIE}" acceptatie

# Een gebruikersflow volgt wat een gebruiker doet, en die merkt niets van de indeling in
# deelsystemen — de flow spant er dus overheen. Ontbreekt er een, dan valt hij om, en dan
# hoort de melding dáárover te gaan en niet over een rode test.
. "${CBT_ROOT}/omgevingen/acceptatie.env"
if ! curl -fsS -o /dev/null --max-time 5 "http://localhost:${ORDER_API_POORT}/actuator/health" 2>/dev/null; then
  fout "de gebruikersflow heeft de hele keten nodig en Order draait niet op Acceptatie. Deploy eerst alle deelsystemen; daarna schuift elk op zijn eigen tempo op"
fi

stap "gebruikersflow @${DEELSYSTEEM}" "${CBT_ROOT}/ci/gebruikersflow.sh" "${DEELSYSTEEM}" http://order-api:8082 cbt-acceptatie
bijzonderheid "$(grep -oE '[0-9]+ passed' "${STAP_LOG}" | tail -1)"

rapport_klaar "${CBT_ROOT}/build/rapport/acceptatie-${DEELSYSTEEM}-${VERSIE}.md" \
  "${DEELSYSTEEM} ${VERSIE} op Acceptatie" \
  "Oordeel: groen. De gebruikersflow over de keten doet wat een gebruiker verwacht."
echo "klaar: ${DEELSYSTEEM} ${VERSIE} draait op Acceptatie"
