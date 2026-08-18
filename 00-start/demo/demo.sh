#!/usr/bin/env bash
#
# Scenario 0: de startsituatie. Beide deelsystemen door de bestaande pipeline.
#
#   demo.sh [--stap]     --stap wacht op een toets tussen de delen
#
# Dit script raakt het register niet aan en roept geen enkel contractscript aan. Dat is
# geen belofte maar de reden dat dit scenario apart staat: wat hier draait, draaide er al
# voordat contracttesten bestonden.
#
# Scenario 1 doet exact hetzelfde, met dezelfde deelsystemen en dezelfde versies, maar dan
# mét contracttesten. Het verschil tussen de twee rapporten is daarmee precies het werk dat
# contracttesten toevoegt — en niets anders.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${CBT_ROOT}"

STAP="${1:-}"

# Eigen rapport. Zonder dit schrijft elke pipeline in dat van scenario 1, en dan is het
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

# --- payment, van code tot Acceptatie ---------------------------------------------------

deel "Payment: van code naar Acceptatie"

ci/pipeline-microservice.sh payment payment-api
ci/pipeline-ci.sh           payment 1.0.0
ci/pipeline-test.sh         payment 1.0.0
ci/pipeline-acceptatie.sh   payment 1.0.0

echo
opmerking "Payment is provider en roept niemand aan, dus op zijn CI-omgeving staat geen"
opmerking "stub. Wat daar draait is het deelsysteem als geheel, op zichzelf."

# --- order, van code tot Acceptatie -----------------------------------------------------

deel "Order: van code naar Acceptatie"

ci/pipeline-microservice.sh order order-api
ci/pipeline-ci.sh           order 1.0.0
ci/pipeline-test.sh         order 1.0.0
ci/pipeline-acceptatie.sh   order 1.0.0

echo
opmerking "Order roept Payment aan, dus op zijn CI-omgeving stond een stub — met de hand"
opmerking "geschreven door Order zelf, op basis van wat hij denkt dat Payment doet."
opmerking "Zie deelsystemen/order/stub-handgeschreven/. Hij dekt het gelukkige pad en"
opmerking "verder niets, want er is geen norm om meer uit af te leiden."

# --- de keten -----------------------------------------------------------------------

deel "De keten: doet het geheel wat een gebruiker verwacht?"

ci/pipeline-gebruikersflows.sh acceptatie

echo
ci/toon-versies.sh acceptatie

echo
opmerking "Beide deelsystemen groen op Acceptatie. Kijk nu terug naar wat er is gedraaid:"
opmerking "unit, integratie, images, een efemere CI-omgeving met stub, een smoke en een"
opmerking "gebruikersflow — en nergens het schema van de grens. Het ligt in contracts/,"
opmerking "het is niet gelezen, en niets viel erop."
opmerking ""
opmerking "De smoke op Test liep wél door de grens heen. De grens wordt dus geraakt, maar"
opmerking "geen enkele test heeft hem als onderwerp: valt hij om, dan zie je een rode"
opmerking "smoke en begint het zoeken."
opmerking ""
opmerking "Wat er is, toetst tegen een norm die de schrijver zelf heeft bedacht. Order's"
opmerking "integratietest mockt Payment en schrijft het antwoord van de buur zelf voor."
opmerking "Die mock is niet fout — hij is onbewijsbaar, en blijft groen als Payment wijzigt."

echo
CBT_LIVE= ci/rapport-html.sh "${CBT_RAPPORT}"

# De stamdata die showcase-website toont, tegen wat er zojuist werkelijk is gedraaid. Alleen
# hier te doen: op een runner bestaat dit rapport niet.
echo
ci/toets-stamdata.sh 00 "${CBT_RAPPORT}" | sed 's/^/  /'

echo
echo "─────────────────────────────────────────────────────────────────────"
echo "  Klaar. Scenario 1 doet dit nog een keer, met contracttesten."
echo "  Zelfde deelsystemen, zelfde versies. Volgende: 01-basis/demo/demo.sh"
echo "─────────────────────────────────────────────────────────────────────"
