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
rapport_start "${DEELSYSTEEM} ${VERSIE} → CI"

# --- pint hij een contract? dan eerst de stub, want die moet er staan vóór de deploy ----

# Is er een register? Dan komt de stub daaruit en volgt de contractlaag. Is die er niet,
# dan draait deze pipeline zoals hij vóór contracttesten draaide: dezelfde efemere
# omgeving, dezelfde e2e binnen het deelsysteem, maar met de stub die de consumer zelf
# heeft geschreven. Eén script, want het ís dezelfde pipeline die stappen erbij krijgt.
REGISTER=""
curl -fsS "${REGISTRY_URL:-http://localhost:8080}/apis/registry/v3/system/info" >/dev/null 2>&1 \
  && REGISTER=1

EXTRA=""
if [ -n "${PINT:-}" ]; then
  if [ -n "${REGISTER}" ]; then
    SCENARIOS="deelsystemen/${DEELSYSTEEM}/stub-scenarios"
    [ -d "${CBT_ROOT}/${SCENARIOS}" ] || SCENARIOS=""
    # shellcheck disable=SC2086
    stap "stub uit ${PINT}" "${CBT_ROOT}/ci/generate-stub.sh" ${PINT} ${SCENARIOS}
    bijzonderheid "$(grep -cE '^stap' "${STAP_LOG}" | tr -d ' ') stappen: mappings, scenario's, schemavalidatie en dekking"
    export STUB_MAPPINGS="${CBT_ROOT}/build/stub"
  else
    HANDGESCHREVEN="${CBT_ROOT}/deelsystemen/${DEELSYSTEEM}/stub-handgeschreven"
    [ -d "${HANDGESCHREVEN}/mappings" ] \
      || fout "geen handgeschreven stub in ${HANDGESCHREVEN}/mappings, en geen register om er een te genereren"
    export STUB_MAPPINGS="${HANDGESCHREVEN}"
    echo "  stub: handgeschreven, uit ${HANDGESCHREVEN#"${CBT_ROOT}/"}"
  fi
  EXTRA="compose/stub.yml"
fi

# shellcheck disable=SC2086
stap "deploy op ${OMGEVING}" "${CBT_ROOT}/ci/deploy.sh" "${DEELSYSTEEM}" "${VERSIE}" "${OMGEVING}" ${EXTRA}

# --- serveert hij een contract? ---------------------------------------------------------

if [ -n "${SERVEERT:-}" ] && [ -n "${REGISTER}" ]; then
  # shellcheck disable=SC2086
  stap "drift" "${CBT_ROOT}/ci/drift.sh" ${SERVEERT} "${RUNTIME_SPEC_URL}"
  bijzonderheid "$(grep '^drift:' "${STAP_LOG}" | tail -1)"

  # shellcheck disable=SC2086
  stap "contractverificatie, provider" "${CBT_ROOT}/ci/verify-contract.sh" provider ${SERVEERT} "${INTERNE_URL}" "${NETWERK}" "${CONTRACT_STIJL:-gegenereerd}"
  bijzonderheid "$(grep -oE '[0-9]+ generated, [0-9]+ passed|Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+' "${STAP_LOG}" | tail -1)"
fi

# --- pint hij een contract? -------------------------------------------------------------

if [ -n "${PINT:-}" ] && [ -n "${REGISTER}" ]; then
  # shellcheck disable=SC2086
  stap "contractverificatie, consumer" "${CBT_ROOT}/ci/verify-contract.sh" consumer ${PINT} "${INTERNE_URL}" "${NETWERK}" "${STUB_ADMIN_URL}"
  bijzonderheid "$(grep -oE 'Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+' "${STAP_LOG}" | tail -1)" || true
fi

# --- e2e binnen het deelsysteem -----------------------------------------------------------
#
# Dit is de laag die er ook zonder contracttesten al was: draait het deelsysteem als geheel,
# met zijn buren vervangen? Zonder register is dit het enige wat de CI-omgeving oplevert;
# met register komt de contractlaag erbij en toont deze stap dat de twee elkaar niet bijten.

stap "e2e binnen ${DEELSYSTEEM}" "${CBT_ROOT}/ci/smoke.sh" "${DEELSYSTEEM}" "${INTERNE_URL}" "${NETWERK}"
bijzonderheid "$(grep -oE '[0-9]+ passed' "${STAP_LOG}" | tail -1)"

if [ -n "${REGISTER}" ]; then
  CONTRACTEN="${SERVEERT:-}${SERVEERT:+ (geserveerd)}${PINT:+${SERVEERT:+, }}${PINT:-}${PINT:+ (gepind)}"
  rapport_oordeel "Oordeel: groen. ${DEELSYSTEEM} ${VERSIE} voldoet aan ${CONTRACTEN}. Dit is het bewijs waarop naar Test gedeployd mag worden."
  echo "klaar: ${DEELSYSTEEM} ${VERSIE} voldoet aan zijn contracten"
else
  rapport_oordeel "Oordeel: groen. ${DEELSYSTEEM} ${VERSIE} draait als geheel op een eigen omgeving. Over de grenzen is hier niets vastgesteld."
  echo "klaar: ${DEELSYSTEEM} ${VERSIE} draait als geheel"
fi
