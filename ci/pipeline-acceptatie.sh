#!/usr/bin/env bash
#
# Pipeline 5 van 6: het deelsysteem naar Acceptatie.
#
#   pipeline-acceptatie.sh <deelsysteem> <deelsysteemversie>
#
# De gate is dat Test groen staat voor dit deelsysteem. Acceptatie is de enige omgeving met
# koppelingen naar buiten; waarom hij er is en wat hem overbodig zou maken, staat in
# bijlage A van docs/showcase-cbt.md.
#
# Geen smoke hier: dat is op Test al aangetoond. En geen gebruikersflow, want die spant over
# de keten en kan dus niet van één squad zijn — hij zit in ci/pipeline-gebruikersflows.sh en
# hangt aan geen enkele deploy. Zou hij hier staan, dan blokkeerde de afwezigheid van de
# buur de release van dit deelsysteem.
#
# Wat overblijft is wat alleen over dit deelsysteem gaat: draait het, en werken zijn eigen
# koppelingen naar buiten. Die laatste komen in scenario 7.

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
rapport_start "${DEELSYSTEEM} ${VERSIE} → Acceptatie"

stap "deploy op Acceptatie" "${CBT_ROOT}/ci/deploy.sh" "${DEELSYSTEEM}" "${VERSIE}" acceptatie

rapport_oordeel "Oordeel: groen. ${DEELSYSTEEM} ${VERSIE} draait op Acceptatie. Of de keten doet wat een gebruiker verwacht, stelt de gedeelde gebruikersflow vast — die hangt niet aan deze deploy."
echo "klaar: ${DEELSYSTEEM} ${VERSIE} draait op Acceptatie"
