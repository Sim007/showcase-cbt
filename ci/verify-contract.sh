#!/usr/bin/env bash
#
# Contractverificatie tegen een gedeployde CI-omgeving.
#
#   verify-contract.sh provider <groep> <artifact> <versie> <basis-url> <netwerk> [stijl]
#   verify-contract.sh consumer <groep> <artifact> <versie> <basis-url> <netwerk> <stub-admin>
#
#   stijl = gegenereerd  (standaard)  uit de spec, met Schemathesis
#           geschreven                 JUnit, tag contract
#           beide                      allebei, achter elkaar
#
# De providerkant kan op twee manieren, en de showcase houdt ze allebei omdat het verschil
# zichtbaar hoort te zijn: wat je zelf opschrijft dekt wat je zelf bedenkt, een generator
# dekt wat het contract toestaat. Zie docs/besluiten.md.
#
# De consumerkant kent die keuze niet. Een generator toetst een server aan zijn spec; er is
# niets vergelijkbaars dat een cliënt uitoefent. Wat Order verstuurt is alleen te zien door
# hem te laten draaien en achteraf in het journaal van de stub te kijken.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

SCHEMATHESIS_IMAGE="schemathesis/schemathesis:4.24.3-trixie"

fout() {
  echo "verify-contract: $*" >&2
  exit 1
}

[ "$#" -ge 6 ] || fout "gebruik: verify-contract.sh <provider|consumer> <groep> <artifact> <versie> <basis-url> <netwerk> [stijl|stub-admin]"

ROL="$1"
GROEP="$2"
ARTIFACT="$3"
VERSIE="$4"
BASIS_URL="$5"
NETWERK="$6"

# De spec komt uit het register, nooit van schijf.
SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}")"
SPEC_NAAM="$(basename "${SPEC}")"
SPEC_REL="../../../build/contracts/${SPEC_NAAM}"
RAPPORT="${CBT_ROOT}/build/contract-rapport"
mkdir -p "${RAPPORT}"

# Elke variant telt zelf hoeveel gevallen er zijn gedraaid. Een verificatie die nul
# testgevallen uitvoerde en toch groen meldt, heeft niets vastgesteld — een spec zonder
# operaties of een testselectie die niets matcht levert precies dat op.
UITVOER="$(mktemp)"
trap 'rm -f "${UITVOER}"' EXIT

tel_gevallen() {
  _n="$(testgevallen "${UITVOER}")"
  verwacht_minstens "${_n}" 1 "gedraaide testgevallen ($1)"
  echo "contract: ${_n} testgevallen ($1)"
}

gegenereerd() {
  echo "contract: provider, gegenereerd uit ${GROEP}/${ARTIFACT} ${VERSIE}"
  docker run --rm --network "${NETWERK}" \
    --user "$(id -u):$(id -g)" \
    --volume "${CBT_ROOT}/build/contracts:/specs:ro" \
    --volume "${RAPPORT}:/rapport" \
    "${SCHEMATHESIS_IMAGE}" \
    run "/specs/${SPEC_NAAM}" --url "${BASIS_URL}" \
    --seed 1 --report junit --report-dir /rapport --coverage-no-report 2>&1 | tee "${UITVOER}" \
    || fout "contractverificatie (provider, gegenereerd) rood"
  tel_gevallen "provider, gegenereerd"
}

# -DexcludedGroups= heft de uitsluiting in de pom op: daar staat contract standaard uit,
# omdat die laag een gedeployd deelsysteem nodig heeft.
geschreven() {
  echo "contract: provider, geschreven, tegen ${BASIS_URL}"
  CBT_NETWERK="${NETWERK}" mvn "deelsystemen/payment/payment-api" test \
    -Dgroups=contract -DexcludedGroups= \
    -Dcontract.base-url="${BASIS_URL}" -Dcontract.spec="${SPEC_REL}" 2>&1 | tee "${UITVOER}" \
    || fout "contractverificatie (provider, geschreven) rood"
  tel_gevallen "provider, geschreven"
}

consumer() {
  STUB_ADMIN="$1"
  echo "contract: consumer, tegen ${BASIS_URL} met de stub op ${STUB_ADMIN}"
  CBT_NETWERK="${NETWERK}" mvn "deelsystemen/order/order-api" test \
    -Dgroups=contract -DexcludedGroups= \
    -Dcontract.base-url="${BASIS_URL}" -Dcontract.spec="${SPEC_REL}" \
    -Dcontract.stub-admin="${STUB_ADMIN}" 2>&1 | tee "${UITVOER}" \
    || fout "contractverificatie (consumer) rood"
  tel_gevallen "consumer"
}

case "${ROL}" in
  provider)
    STIJL="${7:-gegenereerd}"
    case "${STIJL}" in
      gegenereerd) gegenereerd ;;
      geschreven)  geschreven ;;
      beide)       gegenereerd; geschreven ;;
      *) fout "onbekende stijl: ${STIJL}. Kies gegenereerd, geschreven of beide" ;;
    esac
    echo "contractverificatie groen (provider, ${STIJL})"
    ;;
  consumer)
    [ "$#" -ge 7 ] || fout "de consumerkant heeft de admin-URL van de stub nodig"
    consumer "$7"
    echo "contractverificatie groen (consumer)"
    ;;
  *)
    fout "onbekende rol: ${ROL}. Kies provider of consumer"
    ;;
esac
