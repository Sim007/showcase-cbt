#!/usr/bin/env bash
#
# De gebruikersflow op Acceptatie, gefilterd op het deelsysteem dat is gedeployd.
#
#   gebruikersflow.sh <deelsysteem> <base-url> <netwerk>
#
# Deze test bestond al vóór contracttesten; hij hoort bij de startsituatie. Wat CBT eraan
# verandert is hoe klein hij mag zijn: de structuur van elke grens is al aangetoond, dus
# wat hier overblijft is of de keten doet wat een gebruiker verwacht.
#
# Het label bepaalt welke flows draaien. Deployt Payment, dan draaien de flows die Payment
# raken; de rest is door die deploy niet aangeroerd.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "gebruikersflow: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fout "gebruik: gebruikersflow.sh <deelsysteem> <base-url> <netwerk>"

DEELSYSTEEM="$1"
BASE_URL="$2"
NETWERK="$3"

echo "gebruikersflow: label @${DEELSYSTEEM}, tegen ${BASE_URL}"
playwright "${NETWERK}" "${BASE_URL}" --project=gebruikersflow --grep "@${DEELSYSTEEM}" \
  || fout "gebruikersflow rood tegen ${BASE_URL}"
echo "gebruikersflow: groen"
