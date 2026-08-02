#!/usr/bin/env bash
#
# Contractverificatie aan de providerkant, tegen een gedeployd deelsysteem.
#
#   verify-contract.sh <groep> <artifact> <versie> <basis-url> <netwerk> [stijl]
#
#   stijl = gegenereerd  (standaard)  uit de spec, met Schemathesis
#           geschreven                 JUnit, -Dgroups=contract
#           beide                      allebei, achter elkaar
#
# De showcase houdt beide stijlen omdat het verschil zichtbaar hoort te zijn. Wat je zelf
# opschrijft dekt wat je zelf bedenkt; een generator uit de spec dekt wat het contract
# toestaat. In hoofdstuk 1 vond de gegenereerde variant vijf gebreken die de geschreven
# tests niet vonden — zie docs/besluiten.md.
#
# Een pipeline kiest er één. Beide draaien is voor de demo.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

SCHEMATHESIS_IMAGE="schemathesis/schemathesis:4.24.3-trixie"

fout() {
  echo "verify-contract: $*" >&2
  exit 1
}

[ "$#" -ge 5 ] || fout "gebruik: verify-contract.sh <groep> <artifact> <versie> <basis-url> <netwerk> [stijl]"

GROEP="$1"
ARTIFACT="$2"
VERSIE="$3"
BASIS_URL="$4"
NETWERK="$5"
STIJL="${6:-gegenereerd}"

case "${STIJL}" in
  gegenereerd|geschreven|beide) ;;
  *) fout "onbekende stijl: ${STIJL}. Kies gegenereerd, geschreven of beide" ;;
esac

# De spec komt uit het register, nooit van schijf.
SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}")"
SPEC_NAAM="$(basename "${SPEC}")"
RAPPORT="${CBT_ROOT}/build/contract-rapport"
mkdir -p "${RAPPORT}"

gegenereerd() {
  echo "contract: gegenereerd uit ${GROEP}/${ARTIFACT} ${VERSIE}"
  docker run --rm --network "${NETWERK}" \
    --user "$(id -u):$(id -g)" \
    --volume "${CBT_ROOT}/build/contracts:/specs:ro" \
    --volume "${RAPPORT}:/rapport" \
    "${SCHEMATHESIS_IMAGE}" \
    run "/specs/${SPEC_NAAM}" --url "${BASIS_URL}" \
    --seed 1 --report junit --report-dir /rapport --coverage-no-report \
    || fout "contractverificatie (gegenereerd) rood"
}

geschreven() {
  echo "contract: geschreven, tegen ${BASIS_URL}"
  # -DexcludedGroups= heft de uitsluiting in de pom op: daar staat contract standaard uit,
  # omdat die laag een gedeployd deelsysteem nodig heeft.
  CBT_NETWERK="${NETWERK}" mvn "deelsystemen/payment/payment-api" test \
    -Dgroups=contract -DexcludedGroups= -Dcontract.base-url="${BASIS_URL}" \
    || fout "contractverificatie (geschreven) rood"
}

case "${STIJL}" in
  gegenereerd) gegenereerd ;;
  geschreven)  geschreven ;;
  beide)       gegenereerd; geschreven ;;
esac

echo "contractverificatie groen (${STIJL})"
