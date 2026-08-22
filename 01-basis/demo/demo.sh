#!/usr/bin/env bash
#
# De basisdemo van scenario 1. Vier scènes, in de volgorde van 1.11.
#
#   demo.sh [--stap]     --stap wacht op een toets tussen de scènes
#
# Begint waar scenario 0 ophoudt: beide deelsystemen draaien, er is net een release
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

# De gebeurtenissen van deze run, naast het rapport en van dezelfde soort: allebei horen ze
# bij één doorloop en niet bij de broncode. Wordt hier een opname van gemaakt, dan is dat een
# eigen handeling — zie ci/neem-op.sh.
export CBT_SCENARIO=01
export CBT_GEBEURTENISSEN="${CBT_ROOT}/01-basis/rapport/gebeurtenissen.jsonl"

# shellcheck source=../../ci/lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

# Een run die halverwege omvalt is een gestopte run en hoort dat te melden. Zonder deze trap
# eindigt het bestand zonder afsluiter, en dan is niet te zien of hij klaar was of afgebroken.
afsluiten_run() {
  _code=$?
  if [ "${_code}" -eq 0 ]; then
    gebeurtenis run-afgerond '"reden":"voltooid"'
  else
    gebeurtenis run-afgerond '"reden":"gestopt"'
  fi
}
trap afsluiten_run EXIT

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
  echo "  Er draait niets op Test. Draai eerst 00-start/demo/demo.sh — dit scenario" >&2
  echo "  begint waar dat ophoudt." >&2
  exit 1
}

# Eigen sporen opruimen, en alleen die. Test en Acceptatie blijven staan: dat is de
# uitgangssituatie uit scenario 0 waar dit scenario op verdergaat.
#
# Nodig omdat een contractversie onveranderlijk is: 1.0.0 opnieuw publiceren levert een 409
# en dat hoort ook zo. Het register is in memory, dus omlaag en omhoog is leegmaken.
for omgeving in ci-payment ci-order; do
  ci/opruimen.sh "${omgeving}" payment order >/dev/null 2>&1 || true
done
docker compose -f compose/registry.yml down >/dev/null 2>&1 || true
rm -rf 01-basis/rapport build/stub build/contracts build/drift \
       build/contract-rapport build/smoke-rapport

docker compose -f compose/registry.yml up -d >/dev/null 2>&1
ci/wacht-op-gezond.sh registry compose/registry.yml >/dev/null 2>&1 || sleep 10

# Ná het opruimen en niet ervoor: het blok hierboven wist 01-basis/rapport/, en het
# gebeurtenissenbestand hoort daar — het is een artefact van één run, net als het rapport.
# Eerder gezet betekent dat de eerste regel meteen weer weg is. Bij scenario 00 is precies
# dat de eerste opname komen te bederven.
mkdir -p "$(dirname "${CBT_GEBEURTENISSEN}")"
rm -f "${CBT_GEBEURTENISSEN}"
gebeurtenis run-gestart "\"scenarioId\":\"${CBT_SCENARIO}\""

toon_pagina

ci/pipeline-contract.sh payment payment-api 1.0.0 contracts/payment/payment-api/1.0.0/openapi.yaml

echo
opmerking "Hetzelfde schema dat in scenario 0 ongelezen bleef, nu gepubliceerd als"
opmerking "payment-api 1.0.0: één plek, immutable, per versie. Vanaf hier is het de norm."
opmerking "Wat hierna volgt is dezelfde gang als in scenario 0, met dezelfde deelsystemen,"
opmerking "maar nu met de contracttesten erbij."

# --- payment, van code tot Acceptatie ---------------------------------------------------

scene "Payment: van code naar Acceptatie"

ci/pipeline-microservice.sh payment payment-api
ci/pipeline-ci.sh           payment 1.0.0
ci/pipeline-test.sh         payment 1.0.0
ci/pipeline-acceptatie.sh   payment 1.0.0

echo
opmerking "Zelfde gang als in scenario 0, met drie stappen erbij. Op de CI-omgeving keek"
opmerking "de drift-check of Payment niet méér aanbiedt dan zijn contract noemt, en toetste"
opmerking "de verificatie elke operatie uit de spec — elke responsecode, happy en unhappy."
opmerking "Op Test kwam de versieconformiteit erbij."
opmerking ""
opmerking "Payment staat nu op Acceptatie. Order is nergens geraadpleegd."

# --- order, van code tot Acceptatie -----------------------------------------------------

scene "Order: van code naar Acceptatie, zonder Payment in zijn omgeving"

ci/pipeline-microservice.sh order order-api
ci/pipeline-ci.sh           order 1.0.0
ci/pipeline-test.sh         order 1.0.0
ci/pipeline-acceptatie.sh   order 1.0.0

echo
ci/toon-versies.sh test

echo
opmerking "Lees terug wat er op de CI-omgeving stond: een stub uit het register, en geen"
opmerking "deploy van Payment. Payment draait wél — op Test en op Acceptatie, hij is er net"
opmerking "langsgekomen — maar niet in Order's CI-omgeving. Daar stond de stub in zijn"
opmerking "plaats, met dezelfde servicenaam, zodat Order het verschil niet merkt."
opmerking ""
opmerking "In scenario 0 stond daar ook een stub. Het verschil is de herkomst: toen met de"
opmerking "hand geschreven door Order zelf, nu gegenereerd uit de gepubliceerde spec."
opmerking ""
opmerking "De verificatie toetste beide richtingen: wat Order verstuurt voldoet aan de spec,"
opmerking "en wat hij met de antwoorden doet klopt. Zonder met iemand af te stemmen."
opmerking ""
opmerking "En geen van beide Acceptatie-pipelines wachtte op de ander."

# --- de keten -----------------------------------------------------------------------

scene "De keten: als gedeelde run die niemand tegenhoudt"

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

# De stamdata die showcase-website toont, tegen wat er zojuist werkelijk is gedraaid. Alleen
# hier te doen: op een runner bestaat dit rapport niet.
echo
ci/toets-stamdata.sh 01 "${CBT_RAPPORT:-${CBT_ROOT}/01-basis/rapport/rapport-cbt-01.md}" | sed 's/^/  /'

# --- de aftrekking ---------------------------------------------------------------------

RAPPORT_00="${CBT_ROOT}/00-start/rapport/rapport-cbt-00.md"
if [ -f "${RAPPORT_00}" ]; then
  scene "De aftrekking: wat contracttesten precies heeft toegevoegd"
  ci/vergelijk-rapporten.sh "${RAPPORT_00}" "${CBT_RAPPORT:-${CBT_ROOT}/01-basis/rapport/rapport-cbt-01.md}"
  echo
  opmerking "Dat lijstje is niet geteld maar afgeleid: elke stap uit scenario 0 komt in"
  opmerking "dezelfde volgorde terug, en wat overblijft is de toevoeging. Loopt er ooit"
  opmerking "iets uiteen — een deelsysteem erbij, een andere volgorde — dan wordt dit rood"
  opmerking "en klopt de vergelijking niet meer."
else
  echo
  opmerking "Geen rapport van scenario 0 gevonden, dus de aftrekking is niet te maken."
  opmerking "Draai 00-start/demo/demo.sh en daarna dit scenario opnieuw."
fi

echo
echo "─────────────────────────────────────────────────────────────────────"
echo "  Klaar. Test en Acceptatie blijven staan om naar te kijken."
echo "  Opnieuw beginnen: ci/opruimen-alles.sh en dan 00-start/demo/demo.sh."
echo "─────────────────────────────────────────────────────────────────────"
