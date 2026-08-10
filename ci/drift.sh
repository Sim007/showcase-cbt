#!/usr/bin/env bash
#
# Drift: biedt een draaiend deelsysteem precies de operaties die zijn contract belooft?
#
#   drift.sh <groep> <artifact> <versie> <runtime-spec-url>
#
# Vergelijkt paden en methoden, niet schema's en niet statuscodes. Dat is smal met opzet.
# De contractverificatie dekt de inhoud al en doet dat beter: die toetst gedrag, niet een
# beschrijving. Wat zij principieel níét kan zien is een operatie die de service aanbiedt
# en de spec niet noemt — zij kijkt immers vanuit de spec. Dat gat vult dit script, en dat
# is het enige dat het vult.
#
# Waarom niet breder: docs/besluiten.md, 2026-08-02.
#
# Dit is geen test maar een artefactcontrole, in dezelfde familie als de stubvalidatie en
# de diff-gate.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "drift: $*" >&2
  exit 1
}

[ "$#" -eq 4 ] || fout "gebruik: drift.sh <groep> <artifact> <versie> <runtime-spec-url>"

GROEP="$1"
ARTIFACT="$2"
VERSIE="$3"
RUNTIME_URL="$4"

command -v curl >/dev/null 2>&1 || fout "curl is niet gevonden op deze machine"

REL="build/drift"
WERKMAP="${CBT_ROOT}/${REL}"
mkdir -p "${WERKMAP}"

# De spec komt uit het register, nooit van schijf.
SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}")"
SPEC_REL="${SPEC#"${CBT_ROOT}/"}"

curl -fsS -o "${WERKMAP}/runtime.json" "${RUNTIME_URL}" \
  || fout "kon de runtime-spec niet ophalen op ${RUNTIME_URL}"

# Eén operatie per regel: METHODE pad. Gesorteerd, zodat comm ze kan vergelijken.
operaties() {
  jq -r '.paths | to_entries[]
         | .key as $pad
         | .value | to_entries[]
         | select(.key | IN("get","post","put","patch","delete","head","options"))
         | "\(.key | ascii_upcase) \($pad)"' "$1" | sort
}

yq -o=json '.' "${SPEC_REL}" > "${WERKMAP}/contract.json"
operaties "${REL}/contract.json" > "${WERKMAP}/beloofd.txt"
operaties "${REL}/runtime.json"  > "${WERKMAP}/aangeboden.txt"

ONTBREEKT="$(comm -23 "${WERKMAP}/beloofd.txt" "${WERKMAP}/aangeboden.txt")"
TEVEEL="$(comm -13 "${WERKMAP}/beloofd.txt" "${WERKMAP}/aangeboden.txt")"

if [ -n "${ONTBREEKT}" ]; then
  echo "drift: het contract belooft operaties die de service niet aanbiedt:" >&2
  printf '%s\n' "${ONTBREEKT}" | sed 's/^/  /' >&2
fi

if [ -n "${TEVEEL}" ]; then
  echo "drift: de service biedt operaties aan die het contract niet noemt:" >&2
  printf '%s\n' "${TEVEEL}" | sed 's/^/  /' >&2
  echo "  Een grens die niet in het contract staat, is een grens waar niemand op let." >&2
fi

[ -z "${ONTBREEKT}${TEVEEL}" ] || exit 1

# Twee lege lijsten komen ook overeen. Zonder deze regel meldt drift "geen verschil" over
# een contract zonder operaties of een runtime-spec die niet geladen kon worden.
BELOOFD="$(wc -l < "${WERKMAP}/beloofd.txt" | tr -d ' ')"
verwacht_minstens "${BELOOFD}" 1 "operaties in het contract om te vergelijken"

echo "drift: geen — ${BELOOFD} operaties, contract en runtime komen overeen"
