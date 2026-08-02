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

echo "== ${DEELSYSTEEM} ${VERSIE} naar Acceptatie =="

echo "-- deploy"
"${CBT_ROOT}/ci/deploy.sh" "${DEELSYSTEEM}" "${VERSIE}" acceptatie

echo "-- gebruikersflow met label ${DEELSYSTEEM}"
"${CBT_ROOT}/ci/gebruikersflow.sh" "${DEELSYSTEEM}" http://order-api:8082 cbt-acceptatie

echo "klaar: ${DEELSYSTEEM} ${VERSIE} draait op Acceptatie"
