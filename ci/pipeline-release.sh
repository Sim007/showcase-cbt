#!/usr/bin/env bash
#
# De pipeline achter een tag: werkregister vullen, asset bouwen, publiceren.
#
#   pipeline-release.sh <tag>
#
# De tagnaam bepaalt wat er uitgegeven wordt, en niets anders — dat is dezelfde regel als
# bij `get-contract`: de aanroeper zegt wát, het script weet hóé.
#
#   scenario-api-0.10.0   een spec uit groep showcase-cbt
#   run-stream-0.10.0     idem
#   stubbundel-0.10.0     de bundel, afgeleid van beide specs
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
#
# De versie komt uit de tag en uit de mappen, en niet uit een glob met `head -1`. Die oude
# vorm nam de eerste versiemap die het bestandssysteem opleverde: met één map klopte dat
# altijd, met twee is het willekeurig. Zodra er een 0.11.0 naast een 0.10.0 staat zou een
# release stilzwijgend de verkeerde spec kunnen bevatten — en dat is niet te zien aan de tag.
#
# Voor een spec-tag zegt de tag zelf welke versie het is. Voor de bundel is dat er niet, want
# die is van beide afgeleid; daar geldt de hoogste versiemap per artifact. Dat is een keuze en
# geen toeval: een bundel hoort bij de nieuwste specs.
hoogste_map() {
  # Sorteert X.Y.Z numeriek zonder sort -V, dat GNU-specifiek is.
  ls -1 "${CBT_ROOT}/contracts/${GROEP}/$1" 2>/dev/null \
    | awk -F. 'NF==3 {printf "%010d%010d%010d %s\n", $1, $2, $3, $0}' \
    | sort | tail -1 | cut -d' ' -f2
}

if [ "${ARTIFACT}" = "stubbundel" ]; then
  SCENARIO_VERSIE="$(hoogste_map scenario-api)"
  STREAM_VERSIE="$(hoogste_map run-stream)"
else
  # De tag bepaalt zijn eigen artifact; de ander gaat mee op zijn hoogste, want het
  # werkregister moet gevuld zijn voordat er iets afgeleid wordt.
  case "${ARTIFACT}" in
    scenario-api) SCENARIO_VERSIE="${VERSIE}"; STREAM_VERSIE="$(hoogste_map run-stream)" ;;
    run-stream)   STREAM_VERSIE="${VERSIE}";   SCENARIO_VERSIE="$(hoogste_map scenario-api)" ;;
    *) fout "onbekend artifact in tag ${TAG}: ${ARTIFACT}" ;;
  esac
fi

[ -n "${SCENARIO_VERSIE}" ] || fout "geen versiemap gevonden voor scenario-api"
[ -n "${STREAM_VERSIE}" ]   || fout "geen versiemap gevonden voor run-stream"
[ -d "${CBT_ROOT}/contracts/${GROEP}/scenario-api/${SCENARIO_VERSIE}" ] \
  || fout "contracts/${GROEP}/scenario-api/${SCENARIO_VERSIE}/ bestaat niet"
[ -d "${CBT_ROOT}/contracts/${GROEP}/run-stream/${STREAM_VERSIE}" ] \
  || fout "contracts/${GROEP}/run-stream/${STREAM_VERSIE}/ bestaat niet"

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
  # De tag mag niet iets anders beweren dan de spec zelf zegt. Vergelijken met `info.version`
  # uit het bestand en niet met de variabele hierboven: die is voor een spec-tag uit de tag
  # afgeleid, en dan vergelijkt de controle de tag met zichzelf. Zo'n controle staat er wel
  # en doet niets — het patroon dat deze repository blijft opruimen.
  case "${ARTIFACT}" in
    scenario-api) SPECBESTAND="contracts/${GROEP}/scenario-api/${VERSIE}/openapi.yaml" ;;
    run-stream)   SPECBESTAND="contracts/${GROEP}/run-stream/${VERSIE}/asyncapi.yaml" ;;
    *)            fout "onbekend artifact in tag ${TAG}: ${ARTIFACT}" ;;
  esac
  [ -f "${CBT_ROOT}/${SPECBESTAND}" ] || fout "tag ${TAG} wijst naar ${SPECBESTAND}, dat er niet is"

  IN_SPEC="$(sed -n 's/^  version: //p' "${CBT_ROOT}/${SPECBESTAND}" | head -1)"
  [ "${VERSIE}" = "${IN_SPEC}" ] \
    || fout "tag ${TAG} noemt versie ${VERSIE}, maar ${SPECBESTAND} zegt ${IN_SPEC}"

  "${CBT_ROOT}/ci/bouw-release.sh" spec "${GROEP}" "${ARTIFACT}" "${VERSIE}"
fi

# --- publiceren ------------------------------------------------------------------------------

"${CBT_ROOT}/ci/publiceer-release.sh" "${TAG}"

docker compose -f "${CBT_ROOT}/compose/registry.yml" down >/dev/null 2>&1 || true

echo "== release ${TAG}: klaar =="
