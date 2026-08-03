#!/usr/bin/env bash
#
# Sluit op deze omgeving alles op elkaar aan?
#
#   versieconformiteit.sh <omgeving>
#
# De vraag is nadrukkelijk niet "draait hier de bedoelde combinatie". Die bestaat niet: elk
# deelsysteem schuift op zijn eigen tempo op, dus er is geen moment waarop een bepaalde
# samenstelling de juiste is. Een lijst met verwachte versies zou die randvoorwaarde
# tegenspreken en zou verouderen zodra een andere squad releaset.
#
# De vraag die wél te beantwoorden is: wordt elke pin die op deze omgeving staat, op deze
# omgeving ook geserveerd? Consumers melden hun pin, providers melden wat ze serveren, en
# daarmee controleert de omgeving zichzelf — zonder dat iemand iets bijhoudt.
#
# Dit is de controle die het afzien van een can-i-deploy-gate verdedigbaar maakt. De smoke
# gaat niet over inhoud en komt groen door een verkeerde versiecombinatie heen; deze niet.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "versieconformiteit: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fout "gebruik: versieconformiteit.sh <omgeving>"
OMGEVING="$1"

ALLE="$(mktemp)"
PINS="$(mktemp)"
GESERVEERD="$(mktemp)"
trap 'rm -f "${ALLE}" "${PINS}" "${GESERVEERD}"' EXIT

info_endpoints "${OMGEVING}" > "${ALLE}"
[ -s "${ALLE}" ] || fout "geen draaiend deelsysteem gevonden op ${OMGEVING}"

# Komma-gescheiden en niet een lijst: vanaf hoofdstuk 3 serveert één provider twee majors
# naast elkaar, en dan staat er "1.0.0,2.0.0" op het info-endpoint.
ontleed() {
  jq -r --arg veld "$1" '
    select(.contract[$veld] != null)
    | . as $d
    | ($d.contract[$veld] | split(",") | map(gsub("^\\s+|\\s+$"; "")) | .[])
    | [$d.contract.groep, $d.contract.artifact, ., $d.deelsysteem.naam] | @tsv
  ' < "${ALLE}"
}

ontleed pin      > "${PINS}"
ontleed serveert > "${GESERVEERD}"

echo "versieconformiteit: ${OMGEVING}"

ROOD=0
GECONTROLEERD=0
while IFS="$(printf '\t')" read -r groep artifact versie consument; do
  [ -n "${groep}" ] || continue
  GECONTROLEERD=$((GECONTROLEERD + 1))

  provider="$(awk -F'\t' -v g="${groep}" -v a="${artifact}" -v v="${versie}" \
              '$1==g && $2==a && $3==v { print $4; exit }' "${GESERVEERD}")"

  if [ -n "${provider}" ]; then
    echo "  ok    ${consument} pint ${groep}/${artifact} ${versie} — geserveerd door ${provider}"
  else
    aanwezig="$(awk -F'\t' -v g="${groep}" -v a="${artifact}" \
                '$1==g && $2==a { printf "%s ", $3 }' "${GESERVEERD}")"
    if [ -n "${aanwezig}" ]; then
      echo "  ROOD  ${consument} pint ${groep}/${artifact} ${versie} — hier draait alleen ${aanwezig% }"
    else
      echo "  ROOD  ${consument} pint ${groep}/${artifact} ${versie} — niemand serveert dit contract op ${OMGEVING}"
    fi
    ROOD=$((ROOD + 1))
  fi
done < "${PINS}"

if [ "${GECONTROLEERD}" -eq 0 ]; then
  echo "  geen enkele pin gevonden op ${OMGEVING}"
  echo "versieconformiteit: niets te controleren"
  exit 0
fi

if [ "${ROOD}" -gt 0 ]; then
  echo "versieconformiteit: ${ROOD} van ${GECONTROLEERD} pins wordt hier niet geserveerd"
  exit 1
fi

echo "versieconformiteit: ${GECONTROLEERD} pins, alle geserveerd"
