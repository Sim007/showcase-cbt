#!/usr/bin/env bash
#
# De smoke, tegen welke omgeving dan ook.
#
#   smoke.sh <deelsysteem|keten> <base-url> <netwerk>
#
# Twee soorten, en het verschil is eigenaarschap:
#
#   <deelsysteem>  de smoke van dat deelsysteem, uit deelsystemen/<naam>/smoke/,
#                  van de squad. Draait na een deploy.
#   keten          de smoke over alle grenzen, uit playwright/keten/, van de tribe.
#                  Hangt niet aan een deploy maar draait gepland.
#
# Eén spec per doel, één aanroeppunt, elke omgeving. Wat verschilt is de base-URL en
# verder niets — zou de spec per omgeving verschillen, dan bewijst groen op de ene niets
# over de andere.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "smoke: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fout "gebruik: smoke.sh <deelsysteem|keten> <base-url> <netwerk>"

DOEL="$1"
BASE_URL="$2"
NETWERK="$3"

mkdir -p "${CBT_ROOT}/build/smoke-rapport"

UITVOER="$(mktemp)"
trap 'rm -f "${UITVOER}"' EXIT

if [ "${DOEL}" = "keten" ]; then
  echo "smoke: keten, tegen ${BASE_URL}"
  playwright "${NETWERK}" "${BASE_URL}" --project=keten 2>&1 | tee "${UITVOER}" \
    || fout "ketensmoke rood tegen ${BASE_URL}"
else
  [ -d "${CBT_ROOT}/deelsystemen/${DOEL}/smoke" ] \
    || fout "deelsysteem ${DOEL} heeft geen smoke in deelsystemen/${DOEL}/smoke/"
  echo "smoke: ${DOEL}, tegen ${BASE_URL}"
  playwright "${NETWERK}" "${BASE_URL}" --project=deelsysteem "${DOEL}/smoke/" 2>&1 | tee "${UITVOER}" \
    || fout "smoke van ${DOEL} rood tegen ${BASE_URL}"
fi

# Playwright faalt zelf al bij "No tests found", maar dan leunt deze gate op het
# standaardgedrag van een gereedschap dat bij een tagbump kan veranderen. Het aantal staat
# hier als eigen bewering.
GESLAAGD="$(testgevallen "${UITVOER}")"
verwacht_minstens "${GESLAAGD}" 1 "geslaagde smoketests tegen ${BASE_URL}"

echo "smoke: groen — ${GESLAAGD} tests"
