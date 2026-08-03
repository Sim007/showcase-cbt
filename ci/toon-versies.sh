#!/usr/bin/env bash
#
# Toont wat er op een omgeving draait, uitgelezen bij de containers zelf.
#
#   toon-versies.sh <omgeving>
#
# Er wordt niets vergeleken met een lijst van verwachte versies: die bestaat niet en hoort
# niet te bestaan. Elk deelsysteem schuift op zijn eigen tempo op, dus wat er draait is
# alleen bij de draaiende containers zelf op te halen.
#
# Welke containers erbij horen komt uit het compose-project (<omgeving>-<deelsysteem>) en
# de poort uit de portmapping. Zo hoeft dit script niet te weten welke deelsystemen er
# bestaan — het ziet wat er staat.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

[ "$#" -eq 1 ] || { echo "gebruik: toon-versies.sh <omgeving>" >&2; exit 1; }
OMGEVING="$1"

GEVONDEN=0
while read -r info; do
  regel="$(printf '%s' "${info}" | jq -r '
    [ .deelsysteem.naam    // "?",
      .deelsysteem.versie  // "?",
      .build.version       // "?",
      (if .contract.serveert then "serveert" elif .contract.pin then "pin" else "—" end),
      (.contract.serveert // .contract.pin // "—")
    ] | @tsv')"

  # Op tab splitsen en niet op spatie: een provider serveert vanaf hoofdstuk 3 meerdere
  # versies, komma-gescheiden, en die horen in één veld te blijven.
  oud_ifs="${IFS}"
  IFS="$(printf '\t')"
  # shellcheck disable=SC2086
  set -- ${regel}
  IFS="${oud_ifs}"

  printf '  %-9s deelsysteem %-7s microservice %-7s contract %-8s %s\n' "$1" "$2" "$3" "$4" "$5"
  GEVONDEN=$((GEVONDEN + 1))
done <<EOF
$(info_endpoints "${OMGEVING}")
EOF

[ "${GEVONDEN}" -gt 0 ] || echo "  (geen draaiend deelsysteem gevonden op ${OMGEVING})"
