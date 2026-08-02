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

# --- opzet ---------------------------------------------------------------------------

scene "Opzet: schone lei, het register omhoog en het contract erin"

# Eerst opruimen, niet achteraf. Een demo die alleen vanaf een handmatig schoongemaakte
# machine werkt, valt om op het moment dat er publiek bij zit — en het register weigert
# terecht een tweede publicatie van dezelfde versie.
01-basis/demo/opruimen.sh

docker compose -f compose/registry.yml up -d >/dev/null
ci/wacht-op-gezond.sh registry compose/registry.yml >/dev/null 2>&1 || sleep 10
ci/publish-contract.sh order-payment payment-api 1.0.0 contracts/order-payment/v1.0.0/openapi.yaml

echo
opmerking "Het contract kwam door de diff-gate. Vanaf hoofdstuk 2 doet die gate werk;"
opmerking "hier is er nog niets om mee te vergelijken."

# --- scène 1 -------------------------------------------------------------------------

scene "Scène 1: Order's pipeline draait groen terwijl Payment nergens draait"

ci/pipeline-microservice.sh order order-api
ci/pipeline-ci.sh order 1.0.0

echo
opmerking "Payment draaide hier niet. Wat Order tegenkwam was een stub die uit de spec"
opmerking "uit het register is gegenereerd — en de verificatie toetste beide richtingen:"
opmerking "wat Order verstuurt voldoet aan de spec, en wat hij met de antwoorden doet klopt."
docker ps --format '{{.Names}}' | grep -q payment && echo "  !! er draait toch een payment-container" || \
  opmerking "Bevestigd: geen enkele payment-container draait."

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
for poort in 8081 8082; do
  curl -s "http://localhost:${poort}/actuator/info" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  %-9s deelsysteem %-7s microservice %-7s contract %s' % (
    d['deelsysteem']['naam'],
    d['deelsysteem']['versie'],
    d['build']['version'],
    d['contract'].get('serveert') or d['contract'].get('pin')))"
done

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

echo
ci/rapport-html.sh

echo
echo "─────────────────────────────────────────────────────────────────────"
echo "  Klaar. Test blijft staan om naar te kijken."
echo "  Opnieuw draaien kan meteen: de demo ruimt zelf op voordat hij begint."
echo "─────────────────────────────────────────────────────────────────────"
