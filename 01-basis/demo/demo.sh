#!/usr/bin/env bash
#
# De basisdemo van hoofdstuk 1. Vier scènes, in de volgorde van 1.11.
#
#   demo.sh [--stap]     --stap wacht op een toets tussen de scènes
#
# Begint waar hoofdstuk 0 ophoudt: beide deelsystemen draaien, er is net een release
# doorheen gegaan, en er is geen register.
#
# Dit script bedenkt niets zelf: het roept de pipelines aan die een squad ook zou draaien.
# Staat er hier iets wat niet uit ci/ komt, dan toont de demo iets anders dan wat er is.
#
# Begin bewust met Order. Het publiek verwacht dat de consumer als laatste moet, en die
# verwachting omdraaien is de helft van het argument.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${CBT_ROOT}"

STAP="${1:-}"

# De pagina bouwt zich tijdens de run op, zodat je ziet wat er gebeurt in plaats van het
# achteraf te lezen. Met CBT_LIVE=0 blijft alleen de terminal over.
case "${CBT_LIVE:-1}" in
  0|nee|off) CBT_LIVE="" ;;
  *)         CBT_LIVE=1 ;;
esac
export CBT_LIVE

RAPPORT="${CBT_ROOT}/01-basis/rapport/rapport-cbt-01.html"

toon_pagina() {
  [ -n "${CBT_LIVE}" ] || return 0
  # Een leeg rapport aanmaken en tonen, zodat de pagina er staat voordat de eerste stap
  # begint. Daarna vult hij zichzelf.
  . "${CBT_ROOT}/ci/lib/tools.sh"
  rapport_start "demo"
  ci/rapport-html.sh >/dev/null 2>&1 || true
  if command -v open >/dev/null 2>&1; then open "${RAPPORT}"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "${RAPPORT}" >/dev/null 2>&1
  else echo "  open in je browser: ${RAPPORT}"
  fi
}

scene() {
  echo
  echo "─────────────────────────────────────────────────────────────────────"
  echo "  $1"
  echo "─────────────────────────────────────────────────────────────────────"
  [ "${STAP}" = "--stap" ] && { printf '  [enter]'; read -r _; } || true
}

opmerking() {
  echo "  → $1"
}

# --- het register erbij ---------------------------------------------------------------

scene "Het register erbij — en daarna de contracttesten"

docker ps --format '{{.Names}}' | grep -q '^test-' || {
  echo "  Er draait niets op Test. Draai eerst 00-start/demo/demo.sh — dit hoofdstuk" >&2
  echo "  begint waar dat ophoudt." >&2
  exit 1
}

docker compose -f compose/registry.yml up -d >/dev/null 2>&1
ci/wacht-op-gezond.sh registry compose/registry.yml >/dev/null 2>&1 || sleep 10
toon_pagina

ci/pipeline-contract.sh order-payment payment-api 1.0.0 contracts/order-payment/v1.0.0/openapi.yaml

echo
opmerking "Hetzelfde schema dat in hoofdstuk 0 ongelezen bleef, nu gepubliceerd als"
opmerking "payment-api 1.0.0: één plek, immutable, per versie. Vanaf hier is het de norm."
opmerking "Wat hierna volgt is dezelfde gang als in hoofdstuk 0, met dezelfde deelsystemen,"
opmerking "maar nu met de contracttesten erbij."

# --- scène 1 -------------------------------------------------------------------------

scene "Scène 1: Order's pipeline draait groen zonder Payment in zijn omgeving"

ci/pipeline-microservice.sh order order-api
ci/pipeline-ci.sh order 1.0.0

echo
opmerking "Lees terug wat er stond: een stub uit het register, en geen deploy van Payment."
opmerking "Payment draait wél — op Test en op Acceptatie, zoals in elke werkende opzet —"
opmerking "maar niet in Order's CI-omgeving. Daar stond de stub in zijn plaats, met dezelfde"
opmerking "servicenaam, zodat Order het verschil niet merkt."
opmerking ""
opmerking "De verificatie toetste beide richtingen: wat Order verstuurt voldoet aan de spec,"
opmerking "en wat hij met de antwoorden doet klopt. Zonder met iemand af te stemmen."

# --- scène 2 -------------------------------------------------------------------------

scene "Scène 2: Payment's pipeline draait groen"

ci/pipeline-microservice.sh payment payment-api
ci/pipeline-ci.sh payment 1.0.0

echo
opmerking "De contractverificatie is volledig: elke operatie uit de spec, elke"
opmerking "responsecode, happy en unhappy. En de drift-check keek of Payment niet méér"
opmerking "aanbiedt dan zijn contract noemt."

# --- scène 3 -------------------------------------------------------------------------

scene "Scène 3: Test omhoog, en wat er draait is af te lezen"

ci/pipeline-test.sh payment 1.0.0
ci/pipeline-test.sh order 1.0.0

echo
ci/toon-versies.sh test

echo
opmerking "Drie versieniveaus, drie betekenissen. Ze staan nu toevallig gelijk en gaan"
opmerking "vanaf hoofdstuk 2 uit elkaar lopen."

# --- scène 4 -------------------------------------------------------------------------

scene "Scène 4: dezelfde smoke, nu tegen de echte keten"

ci/smoke.sh order http://order-api:8082 cbt-test

echo
opmerking "Dezelfde spec draaide in scène 1 tegen de stub en hier tegen het echte"
opmerking "Payment. Zou hij per omgeving verschillen, dan bewees groen op de ene niets"
opmerking "over de andere."

# --- scène 5 -------------------------------------------------------------------------

scene "Scène 5: Acceptatie — elk deelsysteem op zijn eigen moment"

ci/pipeline-acceptatie.sh order   1.0.0
ci/pipeline-acceptatie.sh payment 1.0.0

echo
opmerking "Geen van beide pipelines wachtte op de ander, en geen van beide draaide een"
opmerking "gebruikersflow. Die spant over de keten en kan dus niet van één squad zijn —"
opmerking "zou hij hier hangen, dan blokkeert de afwezigheid van de buur je release."

# --- scène 6 -------------------------------------------------------------------------

scene "Scène 6: de keten, als gedeelde run die niemand tegenhoudt"

ci/pipeline-gebruikersflows.sh acceptatie

echo
opmerking "Eén scenario, geen tien. De structuur van elke grens is al aangetoond op de"
opmerking "CI-omgevingen; wat hier overblijft is of de keten doet wat een gebruiker"
opmerking "verwacht. Dat is wat contracttesten aan een ketentest verandert."
opmerking ""
opmerking "En valt hij om omdat er een deelsysteem ontbreekt, dan zegt hij dát — een"
opmerking "onvolledige omgeving, geen kapot deelsysteem. Signaal voor de tribe, geen"
opmerking "blokkade voor een squad."

echo
CBT_LIVE= ci/rapport-html.sh

echo
echo "─────────────────────────────────────────────────────────────────────"
echo "  Klaar. Test en Acceptatie blijven staan om naar te kijken."
echo "  Opnieuw beginnen: ci/opruimen-alles.sh en dan 00-start/demo/demo.sh."
echo "─────────────────────────────────────────────────────────────────────"
