#!/usr/bin/env bash
#
# Pipeline 2 van 4: het deelsysteem op een efemere CI-omgeving, en daar de contractlaag.
#
#   pipeline-ci.sh <deelsysteem> <deelsysteemversie>
#
# De CI-omgeving bestaat alleen tijdens deze run en wordt daarna opgeruimd — ook als er
# iets faalt, want een blijven staande omgeving houdt poorten bezet en maakt de volgende
# run onbetrouwbaar.
#
# Wat deze pipeline doet, hangt af van de **rol op de grens** en niet van het deelsysteem:
# serveert het deelsysteem een contract, dan volgen drift en providerverificatie; pint hij
# er een, dan een stub en consumerverificatie. Payment doet nu het eerste, Order het
# tweede, en vanaf hoofdstuk 6 doet Payment allebei zonder dat hier iets bij hoeft.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "pipeline-ci: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fout "gebruik: pipeline-ci.sh <deelsysteem> <deelsysteemversie>"

DEELSYSTEEM="$1"
VERSIE="$2"
OMGEVING="ci-${DEELSYSTEEM}"
NETWERK="cbt-${OMGEVING}"
ROLLEN="${CBT_ROOT}/deelsystemen/${DEELSYSTEEM}/grenzen.env"

[ -f "${ROLLEN}" ] || fout "geen grenzen.env voor ${DEELSYSTEEM}; daarin staat welke contracten hij serveert en pint"
# shellcheck disable=SC1090
. "${ROLLEN}"

opruimen() {
  "${CBT_ROOT}/ci/opruimen.sh" "${OMGEVING}" "${DEELSYSTEEM}" >/dev/null 2>&1 || true
}
trap opruimen EXIT

echo "== ${DEELSYSTEEM} ${VERSIE} op een efemere CI-omgeving =="

# --- pint hij een contract? dan eerst de stub, want die moet er staan vóór de deploy ----

EXTRA=""
if [ -n "${PINT:-}" ]; then
  SCENARIOS="deelsystemen/${DEELSYSTEEM}/stub-scenarios"
  [ -d "${CBT_ROOT}/${SCENARIOS}" ] || SCENARIOS=""
  # shellcheck disable=SC2086
  stap "stub uit ${PINT}" "${CBT_ROOT}/ci/generate-stub.sh" ${PINT} ${SCENARIOS}
  grep -E "^stap [0-9]" "${STAP_LOG}" | sed 's/^/    /' || true
  export STUB_MAPPINGS="${CBT_ROOT}/build/stub"
  EXTRA="compose/stub.yml"
fi

# shellcheck disable=SC2086
stap "deploy op ${OMGEVING}" "${CBT_ROOT}/ci/deploy.sh" "${DEELSYSTEEM}" "${VERSIE}" "${OMGEVING}" ${EXTRA}

# --- serveert hij een contract? ---------------------------------------------------------

if [ -n "${SERVEERT:-}" ]; then
  # shellcheck disable=SC2086
  stap "drift" "${CBT_ROOT}/ci/drift.sh" ${SERVEERT} "${RUNTIME_SPEC_URL}"
  grep "^drift:" "${STAP_LOG}" | sed 's/^/    /' || true

  # shellcheck disable=SC2086
  stap "contractverificatie, provider" "${CBT_ROOT}/ci/verify-contract.sh" provider ${SERVEERT} "${INTERNE_URL}" "${NETWERK}" "${CONTRACT_STIJL:-gegenereerd}"
  grep -oE "[0-9]+ generated, [0-9]+ passed|Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+" "${STAP_LOG}" | tail -1 | sed 's/^/    /' || true
fi

# --- pint hij een contract? -------------------------------------------------------------

if [ -n "${PINT:-}" ]; then
  # shellcheck disable=SC2086
  stap "contractverificatie, consumer" "${CBT_ROOT}/ci/verify-contract.sh" consumer ${PINT} "${INTERNE_URL}" "${NETWERK}" "${STUB_ADMIN_URL}"
  grep -oE "Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+" "${STAP_LOG}" | tail -1 | sed 's/^/    /' || true
fi

echo "klaar: ${DEELSYSTEEM} ${VERSIE} voldoet aan zijn contracten"
