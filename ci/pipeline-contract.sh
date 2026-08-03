#!/usr/bin/env bash
#
# Pipeline 1 van 6: het schema naar het register.
#
#   pipeline-contract.sh <groep> <artifact> <versie> <specpad>
#
# Het contract heeft een eigen pipeline omdat het een eigen levenscyclus heeft. Een grens
# wijzigt op een ander moment dan de code die hem implementeert, en de contractversie
# beweegt los van de microserviceversie.
#
# Zou publiceren een stap in de microservicepipeline zijn, dan zou elke codewijziging aan
# de spec komen en zou een spec zonder implementatie niet te publiceren zijn — terwijl
# spec-first juist vraagt dat het contract er eerder is.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "pipeline-contract: $*" >&2
  exit 1
}

[ "$#" -eq 4 ] || fout "gebruik: pipeline-contract.sh <groep> <artifact> <versie> <specpad>"

GROEP="$1"
ARTIFACT="$2"
VERSIE="$3"
SPEC="$4"

[ -f "${CBT_ROOT}/${SPEC}" ] || fout "geen spec op ${SPEC}"

echo "== ${GROEP}/${ARTIFACT} ${VERSIE} naar het register =="
rapport_start "${ARTIFACT} ${VERSIE} → register"

stap "diff-gate en publiceren" \
  "${CBT_ROOT}/ci/publish-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}" "${SPEC}"

# De gate zegt zelf wat hij deed: vergelijken met de vorige versie, of vaststellen dat er
# nog niets was. Die regel is het bewijs en hoort in het rapport.
bijzonderheid "$(grep -E 'register leeg|geen breaking|breaking|aangemaakt op|nieuwe versie' "${STAP_LOG}" | head -1)"

# Terughalen uit het register en niet van schijf. Wat hier gepubliceerd is moet ook op te
# halen zijn, anders is de rest van de keten op zand gebouwd — elke stub en elke
# verificatie begint hier.
stap "ophalen ter controle" \
  "${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}"
bijzonderheid "opgehaald uit het register, niet van schijf"

rapport_oordeel "Oordeel: groen. ${GROEP}/${ARTIFACT} ${VERSIE} staat in het register en is daar op te halen. Vanaf hier is dit de norm voor beide kanten van de grens."
echo "klaar: ${GROEP}/${ARTIFACT} ${VERSIE} staat in het register"
