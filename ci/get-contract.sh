#!/usr/bin/env bash
#
# Het enige pad waarlangs iets aan de spec komt. Nooit van schijf, nooit uit de repo
# van de provider: elke pipeline en elke demo haalt hem hier op.
#
#   get-contract.sh <groep> <artifact> <versie>
#
# Schrijft de spec naar build/contracts/<artifact>-<versie>.yaml en drukt dat pad af.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

REGISTRY_URL="${REGISTRY_URL:-http://localhost:8080}"
API="${REGISTRY_URL}/apis/registry/v3"

fout() {
  echo "get-contract: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fout "gebruik: get-contract.sh <groep> <artifact> <versie>"

GROEP="$1"
ARTIFACT="$2"
VERSIE="$3"

command -v curl >/dev/null 2>&1 || fout "curl is niet gevonden op deze machine"

case "${VERSIE}" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) fout "versie moet de vorm X.Y.Z hebben; een consumer pint, hij volgt geen latest: ${VERSIE}" ;;
esac

curl -fsS "${API}/system/info" >/dev/null 2>&1 \
  || fout "register niet bereikbaar op ${REGISTRY_URL} — staat compose/registry.yml omhoog?"

DOEL="${CBT_ROOT}/build/contracts/${ARTIFACT}-${VERSIE}.yaml"
mkdir -p "$(dirname "${DOEL}")"

# -S staat hier bewust uit: de foutregel hieronder is de enige die de gebruiker leest.
curl -fs -o "${DOEL}" \
  "${API}/groups/${GROEP}/artifacts/${ARTIFACT}/versions/${VERSIE}/content" \
  || { rm -f "${DOEL}"; fout "${GROEP}/${ARTIFACT} ${VERSIE} staat niet in het register"; }

echo "${DOEL}"
