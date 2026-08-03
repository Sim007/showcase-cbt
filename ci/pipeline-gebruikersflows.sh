#!/usr/bin/env bash
#
# Gedeelde pipeline: doet de keten wat een gebruiker verwacht?
#
#   pipeline-gebruikersflows.sh <omgeving>
#
# Hangt aan geen enkele deploy. Een gebruikersflow volgt wat een gebruiker doet, en die
# merkt niets van de indeling in deelsystemen — hij spant er dus overheen en kan niet van
# één squad zijn. Zat hij in de Acceptatie-pipeline van een deelsysteem, dan blokkeerde de
# afwezigheid van de buur de release van dit deelsysteem, en wachtte de ene squad op de
# andere. Dat is de afstemming die contracttesten wegneemt, alleen in gereedschap gegoten.
#
# Hij draait daarom gepland en is van de tribe. Valt hij om omdat een deelsysteem ontbreekt,
# dan is dat een juiste uitkomst met een juiste boodschap — deze omgeving is niet compleet —
# en een signaal in plaats van een blokkade.
#
# Dat er hier iets kan falen is geen tekort van contracttesten. De verificatie op de
# CI-omgeving heeft al vastgesteld dat elke kant van elke grens klopt, zonder dat er een
# buur draaide. Wat hier overblijft gaat over de samenstelling en niet over de grens.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "pipeline-gebruikersflows: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fout "gebruik: pipeline-gebruikersflows.sh <omgeving>"
OMGEVING="$1"

echo "== gebruikersflows over de keten op ${OMGEVING} =="
rapport_start "keten op ${OMGEVING}"

# Eerst kijken of de omgeving compleet is, zodat de melding gaat over wat er ontbreekt en
# niet over een rode test. Welke deelsystemen erbij horen komt uit wat er draait: een lijst
# met verwachte deelsystemen zou verouderen zodra er een bijkomt.
ONTBREEKT=""
for _map in "${CBT_ROOT}"/deelsystemen/*/; do
  _naam="$(basename "${_map}")"
  [ -f "${_map}/docker-compose.yml" ] || continue
  docker ps --format '{{.Names}}' | grep -q "^${OMGEVING}-${_naam}-" || ONTBREEKT="${ONTBREEKT} ${_naam}"
done

if [ -n "${ONTBREEKT}" ]; then
  _rapport_regel "keten compleet?" "**ROOD**"
  bijzonderheid "ontbreekt op ${OMGEVING}:${ONTBREEKT}"
  fout "de keten is niet compleet op ${OMGEVING} —${ONTBREEKT} draait er niet. Dat is geen fout in een deelsysteem maar een onvolledige omgeving"
fi

stap "gebruikersflows over de keten" \
  "${CBT_ROOT}/ci/gebruikersflow.sh" keten http://order-api:8082 "cbt-${OMGEVING}"
bijzonderheid "$(grep -oE '[0-9]+ passed' "${STAP_LOG}" | tail -1)"

rapport_oordeel "Oordeel: groen. De keten op ${OMGEVING} doet wat een gebruiker verwacht."
echo "klaar: de keten op ${OMGEVING} doet wat een gebruiker verwacht"
