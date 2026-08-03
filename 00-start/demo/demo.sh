#!/usr/bin/env bash
#
# Hoofdstuk 0: de startsituatie. Twee bedrijven, in de volgorde van 0.1.
#
#   demo.sh [--stap]     --stap wacht op een toets tussen de bedrijven
#
# Dit script raakt het register niet aan en roept geen enkel contractscript aan. Dat is
# geen belofte maar de reden dat dit hoofdstuk apart staat: wat hier draait, draaide er al
# voordat contracttesten bestonden.

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

bedrijf() {
  echo
  echo "─────────────────────────────────────────────────────────────────────"
  echo "  $1"
  echo "─────────────────────────────────────────────────────────────────────"
  [ "${STAP}" = "--stap" ] && { printf '  [enter]'; read -r _; } || true
}

opmerking() {
  echo "  → $1"
}

# --- a: de uitgangssituatie -----------------------------------------------------------

bedrijf "a — de uitgangssituatie: wat er draait"

ci/opruimen-alles.sh >/dev/null

# Stil, want dit is het gegeven en niet het argument. Het bewijs begint bij b: daar loopt
# een release door de bestaande pipeline en komt elke stap in het rapport.
echo "  bestaande CI/CD: images bouwen en deployen…"
(
  export CBT_ROOT="${CBT_ROOT}"
  . ci/lib/tools.sh
  mvn deelsystemen/payment/payment-api -q package -DskipTests
  mvn deelsystemen/order/order-api     -q package -DskipTests
) >/dev/null 2>&1
docker build -q -t cbt/payment-api:1.0.0 deelsystemen/payment/payment-api >/dev/null
docker build -q -t cbt/order-api:1.0.0   deelsystemen/order/order-api     >/dev/null

for omgeving in test acceptatie; do
  for deelsysteem in payment order; do
    ci/deploy.sh "${deelsysteem}" 1.0.0 "${omgeving}" >/dev/null 2>&1
  done
done

echo
echo "  Test:"
ci/toon-versies.sh test
echo "  Acceptatie:"
ci/toon-versies.sh acceptatie

echo
opmerking "Dit draait al: pipelines, omgevingen, unit- en integratietests, een smoke en"
opmerking "een gebruikersflow. Ook het schema van de grens ligt er — als bestand naast de"
opmerking "code, met een versienummer erin."
opmerking ""
opmerking "Twee dingen ontbreken, en die twee zijn de hele showcase:"
opmerking ""
opmerking "  het register       de spec staat in een repository, niet gepubliceerd per"
opmerking "                     versie. Dus geen gate op een wijziging."
opmerking "  de contracttesten  niets toetst aan die spec. Geen stub die eruit komt, geen"
opmerking "                     verificatie aan een van beide kanten, geen drift-check."

# --- b: een release zoals het nu gaat -------------------------------------------------

bedrijf "b — een release zoals het nu gaat: payment 1.0.1 naar Acceptatie"

toon_pagina

opmerking "Payment repareert een bug: bedragen werden op wisselende schaal opgeslagen."
opmerking "Puur intern — amount staat niet in de response. Let op wat de pipeline doet."
echo

ci/pipeline-microservice.sh payment payment-api
ci/pipeline-test.sh         payment 1.0.1
ci/pipeline-acceptatie.sh   payment 1.0.1

echo
echo "  Acceptatie:"
ci/toon-versies.sh acceptatie

echo
opmerking "Groen, en terecht: de fix is goed. Kijk nu terug naar wat er is uitgevoerd."
opmerking "Unit, integratie, een image, een smoke, een gebruikersflow — en nergens het"
opmerking "schema van de grens. Het lag er, het is niet gelezen, niets viel erop."
opmerking ""
opmerking "Payment 1.0.1 staat op Acceptatie en alles was groen. Weet Order dat?"
opmerking ""
opmerking "Deze wijziging raakte de grens niet. Maar dat weet je omdat iemand de code heeft"
opmerking "gelezen, niet omdat de pipeline het heeft vastgesteld — en een wijziging die de"
opmerking "grens wél raakt, geeft precies dezelfde uitkomst."

echo
CBT_LIVE= ci/rapport-html.sh "${CBT_RAPPORT}"

echo
echo "─────────────────────────────────────────────────────────────────────"
echo "  Klaar. Test en Acceptatie blijven staan; hoofdstuk 1 gaat hier verder."
echo "  Volgende: 01-basis/demo/demo.sh"
echo "─────────────────────────────────────────────────────────────────────"
