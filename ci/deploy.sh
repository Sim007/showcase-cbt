#!/usr/bin/env bash
#
# Zet een deelsysteem neer op een omgeving.
#
#   deploy.sh <deelsysteem> <deelsysteemversie> <omgeving> [extra-compose...]
#
# Deployen is drie dingen samenbrengen, en die drie zijn met opzet gescheiden:
#
#   chart    deelsystemen/<naam>/docker-compose.yml   de structuur, verandert niet
#   release  deelsystemen/<naam>/releases/<versie>.env welke microserviceversies erin gaan
#   waarden  omgevingen/<omgeving>.env                 poorten, adressen, secrets
#
# Een release is onveranderlijk en een omgeving houdt een toestand: welke release draait
# daar. De CI-omgeving is de uitzondering — die is efemeer en wordt na de run opgeruimd.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fout() {
  echo "deploy: $*" >&2
  exit 1
}

[ "$#" -ge 3 ] || fout "gebruik: deploy.sh <deelsysteem> <deelsysteemversie> <omgeving> [extra-compose...]"

DEELSYSTEEM="$1"
VERSIE="$2"
OMGEVING="$3"
shift 3

CHART="${CBT_ROOT}/deelsystemen/${DEELSYSTEEM}/docker-compose.yml"
RELEASE="${CBT_ROOT}/deelsystemen/${DEELSYSTEEM}/releases/${VERSIE}.env"
WAARDEN="${CBT_ROOT}/omgevingen/${OMGEVING}.env"

[ -f "${CHART}" ]   || fout "geen chart voor deelsysteem ${DEELSYSTEEM}"
[ -f "${RELEASE}" ] || fout "release ${VERSIE} bestaat niet voor ${DEELSYSTEEM}. Een release is onveranderlijk; maak een nieuwe in plaats van deze te wijzigen"
[ -f "${WAARDEN}" ] || fout "geen waarden voor omgeving ${OMGEVING}"

# De omgeving is het netwerk; elk deelsysteem is een eigen compose-project. Zo raakt een
# deploy van Order het draaiende Payment niet, en houdt elke omgeving toch zijn eigen
# naamruimte — waarin de stub de servicenaam van de buur mag dragen.
NETWERK="cbt-${OMGEVING}"
docker network inspect "${NETWERK}" >/dev/null 2>&1 || docker network create "${NETWERK}" >/dev/null

export OMGEVING_NETWERK="${NETWERK}"
ARGS="-p ${OMGEVING}-${DEELSYSTEEM} --env-file ${RELEASE} --env-file ${WAARDEN} -f ${CHART}"
for extra in "$@"; do
  ARGS="${ARGS} -f ${CBT_ROOT}/${extra}"
done

echo "deploy: ${DEELSYSTEEM} ${VERSIE} naar ${OMGEVING}"
# shellcheck disable=SC2086
docker compose ${ARGS} up -d --remove-orphans

"${CBT_ROOT}/ci/wacht-op-gezond.sh" "${OMGEVING}-${DEELSYSTEEM}" "${CHART}" "$@"

echo "deploy: ${DEELSYSTEEM} ${VERSIE} draait op ${OMGEVING}"
