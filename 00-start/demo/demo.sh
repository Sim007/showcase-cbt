#!/usr/bin/env bash
#
# Hoofdstuk 0: de startsituatie. Beide deelsystemen door de bestaande pipeline.
#
#   demo.sh [--stap]     --stap wacht op een toets tussen de delen
#
# Dit script raakt het register niet aan en roept geen enkel contractscript aan. Dat is
# geen belofte maar de reden dat dit hoofdstuk apart staat: wat hier draait, draaide er al
# voordat contracttesten bestonden.
#
# Hoofdstuk 1 doet exact hetzelfde, met dezelfde deelsystemen en dezelfde versies, maar dan
# mét contracttesten. Het verschil tussen de twee rapporten is daarmee precies het werk dat
# contracttesten toevoegt — en niets anders.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${CBT_ROOT}"

STAP="${1:-}"

# Eigen rapport. Zonder dit schrijft elke pipeline in dat van hoofdstuk 1, en dan is het
# verschil tussen de twee — de kern van deze opzet — juist niet meer te zien.
export CBT_RAPPORT="${CBT_ROOT}/00-start/rapport/rapport-cbt-00.md"

case "${CBT_LIVE:-1}" in
  0|nee|off) CBT_LIVE="" ;;
  *)         CBT_LIVE=1 ;;
esac
export CBT_LIVE

RAPPORT="${CBT_RAPPORT%.md}.html"

toon_pagina() {
  [ -n "${CBT_LIVE}" ] || return 0
  . "${CBT_ROOT}/ci/lib/tools.sh"
  rapport_start "demo"
  ci/rapport-html.sh "${CBT_RAPPORT}" >/dev/null 2>&1 || true
  if command -v open >/dev/null 2>&1; then open "${RAPPORT}"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "${RAPPORT}" >/dev/null 2>&1
  else echo "  open in je browser: ${RAPPORT}"
  fi
}

deel() {
  echo
  echo "─────────────────────────────────────────────────────────────────────"
  echo "  $1"
  echo "─────────────────────────────────────────────────────────────────────"
  [ "${STAP}" = "--stap" ] && { printf '  [enter]'; read -r _; } || true
}

opmerking() {
  echo "  → $1"
}

ci/opruimen-alles.sh >/dev/null
toon_pagina

# --- bouwen en testen -----------------------------------------------------------------

deel "De microservices bouwen en testen"

ci/pipeline-microservice.sh payment payment-api
ci/pipeline-microservice.sh order   order-api

echo
opmerking "Unit en integratie aan beide kanten, en een image per microservice."

# --- naar Test ------------------------------------------------------------------------

deel "Naar Test: draait de samenstelling?"

ci/pipeline-test.sh payment 1.0.0
ci/pipeline-test.sh order   1.0.0

echo
ci/toon-versies.sh test

echo
opmerking "De smoke loopt door de grens heen: Order roept Payment aan en krijgt antwoord."
opmerking "De grens wordt dus geraakt. Maar geen enkele test heeft hem als onderwerp —"
opmerking "valt hij om, dan zie je een rode smoke en begint het zoeken."

# --- naar Acceptatie ------------------------------------------------------------------

deel "Naar Acceptatie: doet de keten wat een gebruiker verwacht?"

# Een gebruikersflow spant over deelsystemen heen, dus op een lege Acceptatie moet de
# omgeving eerst compleet zijn voordat er een flow kan draaien. Daarna schuift elk
# deelsysteem op zijn eigen tempo op en speelt dit niet meer.
ci/deploy.sh order 1.0.0 acceptatie >/dev/null 2>&1

ci/pipeline-acceptatie.sh payment 1.0.0
ci/pipeline-acceptatie.sh order   1.0.0

echo
ci/toon-versies.sh acceptatie

echo
opmerking "Beide deelsystemen groen op Acceptatie. Kijk nu terug naar wat er is gedraaid:"
opmerking "unit, integratie, images, een smoke, een gebruikersflow — en nergens het schema"
opmerking "van de grens. Het ligt in contracts/, het is niet gelezen, niets viel erop."
opmerking ""
opmerking "Wat er is, toetst tegen een norm die de schrijver zelf heeft bedacht. Order's"
opmerking "integratietest mockt Payment en schrijft het antwoord van de buur zelf voor."
opmerking "Die mock is niet fout — hij is onbewijsbaar, en blijft groen als Payment wijzigt."

echo
CBT_LIVE= ci/rapport-html.sh "${CBT_RAPPORT}"

echo
echo "─────────────────────────────────────────────────────────────────────"
echo "  Klaar. Hoofdstuk 1 doet dit nog een keer, met contracttesten."
echo "  Zelfde deelsystemen, zelfde versies. Volgende: 01-basis/demo/demo.sh"
echo "─────────────────────────────────────────────────────────────────────"
