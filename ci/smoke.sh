#!/usr/bin/env bash
#
# De gedeelde smoke, tegen welke omgeving dan ook.
#
#   smoke.sh <base-url> <netwerk>
#
# Eén spec, één aanroeppunt, elke omgeving. Op Test tegen de echte keten, op Acceptatie
# tegen dezelfde keten met de buitenwereld eraan, en desgewenst op een CI-omgeving tegen
# de stub. Wat verschilt is de base-URL en verder niets — zou de spec per omgeving
# verschillen, dan bewijst groen op de ene niets over de andere.
#
# De smoke gaat niet over inhoud: status en het doorlopen van de keten, meer niet.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "smoke: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fout "gebruik: smoke.sh <base-url> <netwerk>"

BASE_URL="$1"
NETWERK="$2"

mkdir -p "${CBT_ROOT}/build/smoke-rapport"

echo "smoke: tegen ${BASE_URL}"
playwright "${NETWERK}" "${BASE_URL}" || fout "smoke rood tegen ${BASE_URL}"
echo "smoke: groen tegen ${BASE_URL}"
