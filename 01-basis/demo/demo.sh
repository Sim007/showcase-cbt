#!/usr/bin/env bash
#
# De basisdemo van hoofdstuk 1. Vier scènes, in de volgorde van 1.11.
#
#   demo.sh [--stap]     --stap wacht op een toets tussen de scènes
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

# --- stap 0: de uitgangssituatie ------------------------------------------------------

scene "Stap 0: de uitgangssituatie — wat er al draait"

01-basis/demo/opruimen.sh >/dev/null

# Dit is het gegeven, niet de demo. Twee deelsystemen die gebouwd en gedeployd worden met
# pipelines die er al zijn. Daarom gaat het stil: het argument begint pas als contracten
# erbij komen. Deze stappen staan bewust niet in het rapport — dat is het testbewijs van
# déze run, en niet van wat er al stond.
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
opmerking "code, met een versienummer erin. Dat is de uitgangssituatie."
opmerking ""
opmerking "Twee dingen ontbreken, en die twee zijn de hele showcase:"
opmerking ""
opmerking "  het register       de spec staat in een repository, niet gepubliceerd per"
opmerking "                     versie. Dus geen gate op een wijziging."
opmerking "  de contracttesten  niets toetst aan die spec. Geen stub die eruit komt, geen"
opmerking "                     verificatie aan een van beide kanten, geen drift-check."
opmerking ""
opmerking "Het schema bindt dus niets. Het is documentatie, geen norm waar een build op valt."

# --- stap 1: contracttesten komt erbij ------------------------------------------------

scene "Stap 1: het register erbij — en daarna de contracttesten"

docker compose -f compose/registry.yml up -d >/dev/null 2>&1
ci/wacht-op-gezond.sh registry compose/registry.yml >/dev/null 2>&1 || sleep 10
toon_pagina

ci/publish-contract.sh order-payment payment-api 1.0.0 contracts/order-payment/v1.0.0/openapi.yaml

echo
opmerking "Hetzelfde schema, nu gepubliceerd als payment-api 1.0.0: één plek, immutable,"
opmerking "per versie. Het kwam door de diff-gate — vanaf hoofdstuk 2 doet die gate werk,"
opmerking "hier is er nog niets om mee te vergelijken."
opmerking ""
opmerking "Daarmee is het eerste ontbrekende stuk er. Wat hierna volgt is dezelfde gang als"
opmerking "daarnet, met dezelfde deelsystemen — maar nu met de contracttesten erbij."

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

scene "Scène 5: Acceptatie, en de gebruikersflow over de keten"

# Een gebruikersflow spant over deelsystemen heen. Op een blijvende omgeving staan ze er
# allebei al; deze demo begint met een schone lei en moet die eerste vulling dus zelf doen
# voordat er een flow kan draaien.
ci/deploy.sh payment 1.0.0 acceptatie >/dev/null
ci/pipeline-acceptatie.sh order   1.0.0
ci/pipeline-acceptatie.sh payment 1.0.0

echo
opmerking "Eén scenario, geen tien. De structuur van de grens is al aangetoond op de"
opmerking "CI-omgeving; wat hier overblijft is of de keten doet wat een gebruiker"
opmerking "verwacht. Dat is wat contracttesten aan een ketentest verandert."

echo
CBT_LIVE= ci/rapport-html.sh

echo
echo "─────────────────────────────────────────────────────────────────────"
echo "  Klaar. Test en Acceptatie blijven staan om naar te kijken."
echo "  Opnieuw draaien kan meteen: de demo ruimt zelf op voordat hij begint."
echo "─────────────────────────────────────────────────────────────────────"
