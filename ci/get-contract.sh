#!/usr/bin/env bash
#
# Het enige pad waarlangs iets aan de spec komt. Nooit van schijf, nooit uit de repo
# van de provider: elke pipeline en elke demo haalt hem hier op.
#
#   get-contract.sh <groep> <artifact> <versie> [--uit werkregister|release]
#
# Schrijft de spec naar build/contracts/<artifact>-<versie>.yaml en drukt dat pad af.
#
# Twee bronnen, en welke de juiste is hangt af van waar je staat. Vóór de gates lees je uit
# het werkregister — dat is gevuld uit de werkboom en bevat dus wat er beoordeeld moet
# worden. Ná de gates, als consumer buiten deze repository, lees je uit het kanaal, want dan
# moet je hebben wat er is uitgegeven. Dezelfde spec, twee bronnen, en de verkeerde kiezen
# levert een gate op die toetst wat er al uit is. Zie docs/besluiten.md, 2026-08-13.
#
# De standaard per groep staat in ci/registers.env, als data. Dit script weet daarmee niet
# wélke grens het ophaalt, alleen langs welke weg — en dat moet zo blijven.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

REGISTRY_URL="${REGISTRY_URL:-http://localhost:8080}"
API="${REGISTRY_URL}/apis/registry/v3"

fout() {
  echo "get-contract: $*" >&2
  exit 1
}

[ "$#" -ge 3 ] || fout "gebruik: get-contract.sh <groep> <artifact> <versie> [--uit werkregister|release]"

GROEP="$1"
ARTIFACT="$2"
VERSIE="$3"
shift 3

BRON=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --uit) [ "$#" -ge 2 ] || fout "--uit vraagt een waarde: werkregister of release"; BRON="$2"; shift 2 ;;
    *) fout "onbekend argument: $1" ;;
  esac
done

command -v curl >/dev/null 2>&1 || fout "curl is niet gevonden op deze machine"

case "${VERSIE}" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) fout "versie moet de vorm X.Y.Z hebben; een consumer pint, hij volgt geen latest: ${VERSIE}" ;;
esac

# De standaard per groep als data. Geen --uit meegegeven, dan geldt wat ci/registers.env zegt.
# shellcheck source=registers.env
. "${CBT_ROOT}/ci/registers.env"
if [ -z "${BRON}" ]; then
  _sleutel="REGISTER_$(printf '%s' "${GROEP}" | tr '-' '_')"
  eval "BRON=\${${_sleutel}:-}"
  [ -n "${BRON}" ] || fout "geen bron bekend voor groep ${GROEP}. Zet REGISTER_... in ci/registers.env"
fi

DOEL="${CBT_ROOT}/build/contracts/${ARTIFACT}-${VERSIE}.yaml"
mkdir -p "$(dirname "${DOEL}")"

case "${BRON}" in
  werkregister)
    curl -fsS "${API}/system/info" >/dev/null 2>&1 \
      || fout "register niet bereikbaar op ${REGISTRY_URL} — staat compose/registry.yml omhoog?"

    # -S staat hier bewust uit: de foutregel hieronder is de enige die de gebruiker leest.
    curl -fs -o "${DOEL}" \
      "${API}/groups/${GROEP}/artifacts/${ARTIFACT}/versions/${VERSIE}/content" \
      || { rm -f "${DOEL}"; fout "${GROEP}/${ARTIFACT} ${VERSIE} staat niet in het register"; }
    ;;

  release)
    # Langs precies de URL-vorm die showcase-website gebruikt, en met dezelfde verificatie. Doen we
    # dat anders, dan toetsen we een pad dat niemand anders loopt.
    BASIS="https://github.com/${RELEASE_REPO}/releases/download/${ARTIFACT}-${VERSIE}"
    curl -fsSL -o "${DOEL}" "${BASIS}/${ARTIFACT}-${VERSIE}.yaml" \
      || { rm -f "${DOEL}"; fout "${ARTIFACT} ${VERSIE} is niet uitgegeven op ${RELEASE_REPO}"; }

    # Eén checksumbestand per asset, met de assetnaam erin. Zie docs/besluiten.md: één
    # `SHA256SUMS` per release botst zodra iemand twee releases naar dezelfde map haalt.
    SOMMEN="${CBT_ROOT}/build/contracts/${ARTIFACT}-${VERSIE}.yaml.sha256"
    curl -fsSL -o "${SOMMEN}" "${BASIS}/${ARTIFACT}-${VERSIE}.yaml.sha256" \
      || fout "release ${ARTIFACT}-${VERSIE} heeft geen checksumbestand — niet te verifiëren"

    VERWACHT="$(awk -v n="${ARTIFACT}-${VERSIE}.yaml" '$2 == n { print $1 }' "${SOMMEN}")"
    [ -n "${VERWACHT}" ] || fout "${ARTIFACT}-${VERSIE}.yaml.sha256 noemt dat bestand zelf niet"

    GEVONDEN="$(sha256som "build/contracts" "${ARTIFACT}-${VERSIE}.yaml" | cut -d' ' -f1)"
    [ "${GEVONDEN}" = "${VERWACHT}" ] \
      || fout "de uitgegeven ${ARTIFACT} ${VERSIE} klopt niet met zijn checksum: ${GEVONDEN} tegen ${VERWACHT}"
    ;;

  *)
    fout "onbekende bron: ${BRON} — kies werkregister of release"
    ;;
esac

echo "${DOEL}"
