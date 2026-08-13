#!/usr/bin/env bash
#
# De pipeline achter een tag: werkregister vullen, asset bouwen, publiceren.
#
#   pipeline-release.sh <tag>
#
# De tagnaam bepaalt wat er uitgegeven wordt, en niets anders — dat is dezelfde regel als
# bij `get-contract`: de aanroeper zegt wát, het script weet hóé.
#
#   scenario-api-0.9.0   een spec uit groep showcase-cbt
#   run-stream-0.9.0     idem
#   stubbundel-0.9.0     de bundel, afgeleid van beide specs
#
# Het werkregister gaat hier omhoog omdat de asset dáár vandaan komt en niet van schijf.
# Wat de gates hebben gezien staat in het register; wat in contracts/ staat is de werkkopie.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "pipeline-release: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fout "gebruik: pipeline-release.sh <tag>"

TAG="$1"
GROEP=showcase-cbt

# Artifact en versie uit de tag: alles vóór het laatste streepje is de naam, erna de versie.
VERSIE="${TAG##*-}"
ARTIFACT="${TAG%-*}"

case "${VERSIE}" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) fout "tag ${TAG} eindigt niet op een versie van de vorm X.Y.Z" ;;
esac

echo "== release ${ARTIFACT} ${VERSIE} =="

# --- het werkregister omhoog en gevuld ----------------------------------------------------

docker compose -f "${CBT_ROOT}/compose/registry.yml" down >/dev/null 2>&1 || true
docker compose -f "${CBT_ROOT}/compose/registry.yml" up -d >/dev/null 2>&1
"${CBT_ROOT}/ci/wacht-op-gezond.sh" registry "${CBT_ROOT}/compose/registry.yml" >/dev/null 2>&1 || sleep 12

# Publiceren in het werkregister is tegelijk de geldigheidsgate en de diff-gate: zonder die
# twee komt er niets in, en dus ook niets in de release.
SCENARIO_VERSIE="$(sed -n 's/^  version: //p' "${CBT_ROOT}/contracts/${GROEP}/scenario-api/"*/openapi.yaml | head -1)"
STREAM_VERSIE="$(sed -n 's/^  version: //p' "${CBT_ROOT}/contracts/${GROEP}/run-stream/"*/asyncapi.yaml | head -1)"

"${CBT_ROOT}/ci/publish-contract.sh" "${GROEP}" scenario-api "${SCENARIO_VERSIE}" \
  "contracts/${GROEP}/scenario-api/${SCENARIO_VERSIE}/openapi.yaml" >/dev/null
"${CBT_ROOT}/ci/publish-contract.sh" "${GROEP}" run-stream "${STREAM_VERSIE}" \
  "contracts/${GROEP}/run-stream/${STREAM_VERSIE}/asyncapi.yaml" >/dev/null

echo "  werkregister gevuld: scenario-api ${SCENARIO_VERSIE}, run-stream ${STREAM_VERSIE}"

# --- de asset -------------------------------------------------------------------------------

if [ "${ARTIFACT}" = "stubbundel" ]; then
  "${CBT_ROOT}/ci/bouw-stubbundel.sh" "${GROEP}" scenario-api "${SCENARIO_VERSIE}" \
    run-stream "${STREAM_VERSIE}" "${VERSIE}" >/dev/null
  "${CBT_ROOT}/ci/bouw-release.sh" bundel "${VERSIE}"
else
  # De tag mag niet iets anders beweren dan de spec zelf zegt. Zonder deze controle geeft
  # een verschrijving in de tagnaam een release uit onder een versie die nergens bestaat.
  case "${ARTIFACT}" in
    scenario-api) IN_SPEC="${SCENARIO_VERSIE}" ;;
    run-stream)   IN_SPEC="${STREAM_VERSIE}" ;;
    *)            fout "onbekend artifact in tag ${TAG}: ${ARTIFACT}" ;;
  esac
  [ "${VERSIE}" = "${IN_SPEC}" ] \
    || fout "tag ${TAG} noemt versie ${VERSIE}, maar de spec zegt ${IN_SPEC}"

  "${CBT_ROOT}/ci/bouw-release.sh" spec "${GROEP}" "${ARTIFACT}" "${VERSIE}"
fi

# --- publiceren ------------------------------------------------------------------------------

"${CBT_ROOT}/ci/publiceer-release.sh" "${TAG}"

docker compose -f "${CBT_ROOT}/compose/registry.yml" down >/dev/null 2>&1 || true

echo "== release ${TAG}: klaar =="
