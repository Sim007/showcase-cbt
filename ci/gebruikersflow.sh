#!/usr/bin/env bash
#
# De gebruikersflow op Acceptatie, gefilterd op het deelsysteem dat is gedeployd.
#
#   gebruikersflow.sh <deelsysteem|keten> <base-url> <netwerk>
#
# Deze test bestond al vóór contracttesten; hij hoort bij de startsituatie. Wat CBT eraan
# verandert is hoe klein hij mag zijn: de structuur van elke grens is al aangetoond, dus
# wat hier overblijft is of de keten doet wat een gebruiker verwacht.
#
# `keten` draait alle flows. Dat is de normale modus, want een gebruikersflow volgt wat een
# gebruiker doet en die merkt niets van de indeling in deelsystemen — hij spant er dus
# overheen en kan niet van één squad zijn. Hij hangt daarom aan geen enkele deploy.
#
# Een enkel label blijft mogelijk voor wie gericht wil kijken, maar mag nooit een gate voor
# één deelsysteem worden: dan blokkeert de afwezigheid van de buur de release van dit
# deelsysteem, en wacht de ene squad op de andere.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "gebruikersflow: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fout "gebruik: gebruikersflow.sh <deelsysteem|keten> <base-url> <netwerk>"

WAT="$1"
BASE_URL="$2"
NETWERK="$3"

if [ "${WAT}" = "keten" ]; then
  echo "gebruikersflow: alle flows over de keten, tegen ${BASE_URL}"
  playwright "${NETWERK}" "${BASE_URL}" --project=gebruikersflow \
    || fout "gebruikersflow rood tegen ${BASE_URL}"
else
  echo "gebruikersflow: label @${WAT}, tegen ${BASE_URL}"
  playwright "${NETWERK}" "${BASE_URL}" --project=gebruikersflow --grep "@${WAT}" \
    || fout "gebruikersflow rood tegen ${BASE_URL}"
fi
echo "gebruikersflow: groen"
