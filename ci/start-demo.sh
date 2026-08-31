#!/usr/bin/env bash
#
# Zet de volledige demo neer: van een lege machine tot een browser waarin op start gedrukt
# kan worden. showcase-CBT (register, provider, runner) én showcase-website, in containers.
#
#   start-demo.sh
#
# **Waarom dit één script is en geen acht.** Gemeten op 2026-08-31: acht losse commando's,
# 27 seconden met een warme cache, en vijf punten waar de aanroeper kennis nodig heeft die
# nergens in deze repo of die van showcase-website staat opgeschreven — drie versienummers,
# dat de provider gebouwd en niet opgehaald wordt, dat het compose-bestand van squad 2's
# `master` komt, en de precieze image-tag. Elk van die vijf is hier vastgelegd.
#
# **Wat dit script niet is: een vervanging van ci/controle.sh of van de scenario-demo's.**
# Het zet alleen de omgeving neer waarin de PO op de knop kan drukken. Wat er daarna gebeurt
# — het echte draaien van scenario 00 of 01 — loopt via showcase-website en de provider,
# precies zoals die twee dat al doen.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${CBT_ROOT}"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

# --- meldingen ------------------------------------------------------------------------------
#
# De PO ziet de codebase niet. Een stop is daarom altijd één ding: wat er mis is, en wat hij
# eraan kan doen. Geen exitcode, geen pad naar een script, geen stacktrace.

fout() {
  echo >&2
  echo "STOP — $*" >&2
  exit 1
}

stap() {
  echo
  echo "→ $*"
}

# --- versies ---------------------------------------------------------------------------------
#
# Dezelfde drie als in ci/controle.sh. Er is geen gedeeld bestand dat dit vastlegt — dat is
# zelf een van de vijf kennispunten uit de meting, en dit script lost het op door de nummers
# hier hard te zetten, net als controle.sh dat doet.

GROEP=showcase-cbt
SCENARIO_VERSIE=0.13.0
STREAM_VERSIE=0.11.0
PROVIDERVERSIE=0.3.0

# De tag van showcase-website is hún levering, niet de onze — er is geen manier om "de
# nieuwste bevestigd werkende" hier automatisch af te leiden. Laatst geverifieerd op
# 2026-08-31 (zie de smoke-test in docs/besluiten.md). Controleer bij twijfel bij squad 2 of
# er een nieuwere is voordat je dit wijzigt.
WEBSITE_TAG="demo-20260824b"
WEBSITE_COMPOSE_URL="https://raw.githubusercontent.com/Sim007/showcase-website/master/docker-compose.release.yml"

POORT_WEBSITE=5173
POORT_PROVIDER=8090

# --- opruimen: alleen van onszelf, nooit van de machine -------------------------------------
#
# Containers van een vorige poging weg, zodat een herstart altijd van hetzelfde punt begint.
# Geen `docker system prune`, geen image weggooien: dat sloopt precies de cache die een start
# van 27 seconden mogelijk maakt, en op deze machine ook werk dat niets met deze showcase te
# maken heeft.

stap "Opruimen van een eventuele vorige poging"

docker rm -f cbt-provider >/dev/null 2>&1 || true
pkill -f "${CBT_ROOT}/ci/runner.sh" 2>/dev/null || true
# -p registry, om dezelfde reden als bij het starten verderop: zonder projectnaam mist dit
# een registry die met -p registry is gestart, en dat geeft bij de volgende up-d een
# naamconflict op cbt-registry / cbt-registry-ui.
docker compose -p registry -f compose/registry.yml down >/dev/null 2>&1 || true

WEBSITE_MAP="${CBT_ROOT}/build/demo-website"
if [ -f "${WEBSITE_MAP}/docker-compose.release.yml" ]; then
  ( cd "${WEBSITE_MAP}" && TAG="${WEBSITE_TAG}" docker compose -f docker-compose.release.yml down >/dev/null 2>&1 || true )
fi

echo "  gedaan"

# --- vooraf: staat het benodigde materiaal al lokaal? ----------------------------------------
#
# Geen stop — een waarschuwing. De PO moet weten wáárom hij wacht en niet denken dat het
# script is vastgelopen.

stap "Controleren of het benodigde materiaal al lokaal staat"

ONTBREEKT=""
docker image inspect node:22.23.2-alpine >/dev/null 2>&1 || ONTBREEKT="${ONTBREEKT} node:22.23.2-alpine"
docker image inspect quay.io/apicurio/apicurio-registry:3.3.1 >/dev/null 2>&1 || ONTBREEKT="${ONTBREEKT} apicurio-registry"
docker image inspect quay.io/apicurio/apicurio-registry-ui:3.3.1 >/dev/null 2>&1 || ONTBREEKT="${ONTBREEKT} apicurio-registry-ui"
docker image inspect "ghcr.io/sim007/showcase-website/client:${WEBSITE_TAG}" >/dev/null 2>&1 || ONTBREEKT="${ONTBREEKT} showcase-website-client"
docker image inspect "ghcr.io/sim007/showcase-website/server:${WEBSITE_TAG}" >/dev/null 2>&1 || ONTBREEKT="${ONTBREEKT} showcase-website-server"

if [ -n "${ONTBREEKT}" ]; then
  echo "  Nog niet alles staat lokaal:${ONTBREEKT}"
  echo "  De eerste start duurt daardoor ongeveer 5 tot 15 minuten — dat is downloaden,"
  echo "  geen vastloper. Elke volgende start is weer snel."
else
  echo "  Alles staat al lokaal. Dit wordt een snelle start."
fi

# --- vooraf: zijn de twee poorten vrij? -------------------------------------------------------
#
# Na het opruimen hierboven, met opzet: onze eigen vorige provider zou anders foutief als
# "bezet" gemeld worden. Wat híér nog bezet is, is van iets anders — en dat is een echte stop,
# want geen van beide poorten is te verplaatsen. showcase-website verwacht 5173 vast in zijn
# instellingen; de provider accepteert alleen verzoeken die zeggen vanaf 5173 te komen. En
# 8090 is de poort van showcase-CBT zelf, ook niet in te stellen.

poort_bezet() {
  # Puur een TCP-test, geen aanname over wat er op de poort spreekt: exitcode 7 van curl
  # betekent "kon niet verbinden", elke andere uitkomst betekent dat er iets luistert.
  curl -s -o /dev/null --max-time 1 "http://localhost:$1" >/dev/null 2>&1
  [ "$?" -ne 7 ]
}

wat_zit_op_poort() {
  _poort="$1"
  _container="$(docker ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null \
    | awk -v p=":${_poort}->" '$0 ~ p { print $1; exit }')"
  if [ -n "${_container}" ]; then
    echo "container '${_container}'"
    return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    _proc="$(lsof -nP -iTCP:"${_poort}" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 { print $1 " (proces " $2 ")" }')"
    if [ -n "${_proc}" ]; then
      echo "${_proc}"
      return 0
    fi
  fi
  echo "een ander proces"
}

stap "Controleren of de poorten vrij zijn"

if poort_bezet "${POORT_WEBSITE}"; then
  fout "Poort ${POORT_WEBSITE} is bezet door $(wat_zit_op_poort "${POORT_WEBSITE}"). showcase-website
moet op precies deze poort staan — de provider accepteert alleen verzoeken die zeggen vanaf
localhost:${POORT_WEBSITE} te komen, dus een andere poort kiezen lost dit niet op. Stop wat er
op ${POORT_WEBSITE} draait en draai dit script opnieuw."
fi

if poort_bezet "${POORT_PROVIDER}"; then
  fout "Poort ${POORT_PROVIDER} is bezet door $(wat_zit_op_poort "${POORT_PROVIDER}"). Dat is de
poort van showcase-CBT zelf, ook niet te verplaatsen. Stop wat er op ${POORT_PROVIDER} draait
en draai dit script opnieuw."
fi

echo "  beide poorten zijn vrij"

# --- 1/5: het contractregister ----------------------------------------------------------------

stap "1/5 — Het contractregister starten"
# -p registry, expliciet: zonder projectnaam krijgt compose de mapnaam ("compose") als
# project, en dan zoekt wacht-op-gezond.sh — die -p registry gebruikt — in een lege
# namespace. Dezelfde mismatch zit in ci/controle.sh, daar gemaskeerd door "|| sleep 12".
# Hier niet gemaskeerd: als het register niet gezond wordt, stopt dit script en zegt het dat.
docker compose -p registry -f compose/registry.yml up -d >/dev/null 2>&1 \
  || fout "Het register kon niet starten. Controleer of Docker Desktop actief is."

# Niet ci/wacht-op-gezond.sh: die eist van élke service "running healthy", en registry-ui
# heeft in compose/registry.yml geen healthcheck. Zijn Health-veld is dus altijd leeg en de
# wacht kan nooit slagen — een bestaand gat, in ci/controle.sh tot nu toe gemaskeerd door
# "|| sleep 12". Hier direct op wat ertoe doet: kan het register API bereikt worden.
WACHT=0
until curl -fsS -o /dev/null "http://localhost:8080/apis/registry/v3/system/info" 2>/dev/null; do
  WACHT=$((WACHT + 1))
  [ "${WACHT}" -lt 40 ] || fout "Het register werd niet op tijd bereikbaar. Draai dit script opnieuw."
  sleep 1
done

# --- 2/5: de contracten -----------------------------------------------------------------------

stap "2/5 — De contracten publiceren"
"${CBT_ROOT}/ci/publish-contract.sh" "${GROEP}" scenario-api "${SCENARIO_VERSIE}" \
  "contracts/${GROEP}/scenario-api/${SCENARIO_VERSIE}/openapi.yaml" >/dev/null \
  || fout "Het contract scenario-api ${SCENARIO_VERSIE} kon niet gepubliceerd worden."
"${CBT_ROOT}/ci/publish-contract.sh" "${GROEP}" run-stream "${STREAM_VERSIE}" \
  "contracts/${GROEP}/run-stream/${STREAM_VERSIE}/asyncapi.yaml" >/dev/null \
  || fout "Het contract run-stream ${STREAM_VERSIE} kon niet gepubliceerd worden."

# --- 3/5 en 4/5: de provider --------------------------------------------------------------------

stap "3/5 — showcase-CBT bouwen"
"${CBT_ROOT}/ci/bouw-provider.sh" "${GROEP}" scenario-api "${SCENARIO_VERSIE}" \
  run-stream "${STREAM_VERSIE}" "${PROVIDERVERSIE}" >/dev/null \
  || fout "De image van showcase-CBT bouwde niet."

stap "4/5 — showcase-CBT starten"
"${CBT_ROOT}/ci/start-provider.sh" "${PROVIDERVERSIE}" >/dev/null \
  || fout "showcase-CBT startte niet."

# Niet alleen "de container draait": wachten tot /v1/info werkelijk antwoordt en de juiste
# herkomst meldt, vóórdat de website erbij komt. Een website die verbindt met iets dat nog
# niet leeft, laat de PO een lege pagina zien zonder duidelijke reden.
GEZOND=""
for _ in $(seq 1 30); do
  ANTWOORD="$(curl -fsS "http://localhost:${POORT_PROVIDER}/v1/info" 2>/dev/null || true)"
  case "${ANTWOORD}" in
    *'"bron":"pipeline"'*) GEZOND=1; break ;;
  esac
  sleep 1
done
[ -n "${GEZOND}" ] \
  || fout "showcase-CBT is gestart maar antwoordt niet op /v1/info. Draai 'docker logs cbt-provider' om te zien wat er misgaat."

echo "  showcase-CBT is gezond en meldt zichzelf als de echte pipeline"

# --- 5/5: showcase-website ---------------------------------------------------------------------

stap "5/5 — showcase-website starten"
mkdir -p "${WEBSITE_MAP}"
curl -fsSL -o "${WEBSITE_MAP}/docker-compose.release.yml" "${WEBSITE_COMPOSE_URL}" \
  || fout "Het compose-bestand van showcase-website kon niet opgehaald worden. Is er internet?"
( cd "${WEBSITE_MAP}" && TAG="${WEBSITE_TAG}" docker compose -f docker-compose.release.yml up -d >/dev/null 2>&1 ) \
  || fout "showcase-website startte niet."

WACHT=0
until curl -fsS -o /dev/null "http://localhost:${POORT_WEBSITE}/" 2>/dev/null; do
  WACHT=$((WACHT + 1))
  [ "${WACHT}" -lt 60 ] \
    || fout "showcase-website is niet bereikbaar geworden op http://localhost:${POORT_WEBSITE}/."
  sleep 1
done

# --- klaar ---------------------------------------------------------------------------------

INFO="$(curl -fsS "http://localhost:${POORT_PROVIDER}/v1/info" 2>/dev/null || echo '{}')"
REGEL="$(printf '%s' "${INFO}" | jq -r '"\(.naam) \(.versie) — bron: \(.bron)"' 2>/dev/null || echo 'onbekend')"

echo
echo "───────────────────────────────────────────────────────────"
echo "  Klaar. Open:  http://localhost:${POORT_WEBSITE}"
echo
echo "  Op poort ${POORT_PROVIDER} draait: ${REGEL}"
echo "───────────────────────────────────────────────────────────"
