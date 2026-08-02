#!/usr/bin/env bash
#
# Zet alles terug naar de uitgangssituatie: omgevingen weg, register leeg.
#
# Een demo die zijn eigen rommel laat staan, is de tweede keer niet meer te draaien.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

for omgeving in test acceptatie ci-payment ci-order; do
  "${CBT_ROOT}/ci/opruimen.sh" "${omgeving}" payment order >/dev/null
done

# Het register is in memory: herstarten is leegmaken.
docker compose -f "${CBT_ROOT}/compose/registry.yml" restart registry >/dev/null 2>&1 || true
rm -rf "${CBT_ROOT}/build/stub" "${CBT_ROOT}/build/contracts" "${CBT_ROOT}/build/drift" \
       "${CBT_ROOT}/build/contract-rapport" "${CBT_ROOT}/build/smoke-rapport" \
       "${CBT_ROOT}/01-basis/rapport"

echo "uitgangssituatie hersteld"
