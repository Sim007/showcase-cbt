#!/usr/bin/env bash
#
# Toetst dat elke gate zegt hoeveel hij verwachtte te zien.
#
#   controle-gates.sh
#
# De eis staat in CLAUDE.md: een gate faalt bij een lege verzameling, tenzij het verwachte
# aantal expliciet is opgeschreven. Maar een regel in een document is een afspraak, en een
# afspraak breekt stil — precies wat deze showcase over grenzen betoogt. Dit script maakt er
# een controle van.
#
# Aanleiding: drie keer in één week meldde eigen gereedschap groen na nul dingen te hebben
# bekeken. Zie docs/besluiten.md onder Geleerd.
#
# De richting is met opzet omgekeerd: elk script in ci/ moet `verwacht_minstens` aanroepen,
# tenzij het hieronder staat met een reden. Een nieuw script moet dus iets declareren of
# expliciet worden vrijgesteld — vergeten is geen optie meer.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "controle-gates: $*" >&2
  exit 1
}

# Vrijgesteld, met de reden erbij. Een script hoort hier alleen te staan als het geen
# oordeel velt over een verzameling — dan valt er niets te tellen.
vrijstelling() {
  case "$1" in
    controle-gates.sh)        echo "toetst de gates zelf; zijn verzameling is deze lijst" ;;
    controle.sh)              echo "roept andere controles aan en velt zelf geen oordeel" ;;
    deploy.sh)                echo "zet iets neer, telt niets" ;;
    opruimen.sh)              echo "ruimt op, telt niets" ;;
    opruimen-alles.sh)        echo "ruimt op, telt niets" ;;
    get-contract.sh)          echo "haalt één bestand op; ontbreken is al een fout" ;;
    rapport-html.sh)          echo "zet een rapport om; een leeg rapport is geen fout" ;;
    toon-versies.sh)          echo "toont wat er draait en oordeelt niet" ;;
    wacht-op-gezond.sh)       echo "wacht op één toestand, geen verzameling" ;;
    bouw-stubbundel.sh)       echo "" ;;
    pipeline-acceptatie.sh)   echo "deployt en checkt health; de gates zitten in de aangeroepen scripts" ;;
    pipeline-contract.sh)     echo "roept publish- en get-contract aan; die gaten zitten daar" ;;
    pipeline-microservice.sh) echo "roept Maven en Docker aan; die melden zelf hun aantallen" ;;
    pipeline-test.sh)         echo "roept versieconformiteit en smoke aan; de gates zitten daar" ;;
    pipeline-ci.sh)           echo "roept stub, drift en verificatie aan; de gates zitten daar" ;;
    pipeline-gebruikersflows.sh) echo "roept gebruikersflow aan; de gate zit daar" ;;
    *) echo "" ;;
  esac
}

TOTAAL=0
DECLAREERT=0
VRIJ=0
MIST=""

for script in "${CBT_ROOT}"/ci/*.sh; do
  NAAM="$(basename "${script}")"
  TOTAAL=$((TOTAAL + 1))

  if grep -q 'verwacht_minstens' "${script}"; then
    DECLAREERT=$((DECLAREERT + 1))
    continue
  fi

  REDEN="$(vrijstelling "${NAAM}")"
  if [ -n "${REDEN}" ]; then
    VRIJ=$((VRIJ + 1))
    continue
  fi

  MIST="${MIST} ${NAAM}"
done

verwacht_minstens "${TOTAAL}" 20 "scripts in ci/ nagelopen"

if [ -n "${MIST}" ]; then
  echo "controle-gates: deze scripts vellen een oordeel zonder te zeggen hoeveel ze verwachtten:" >&2
  for n in ${MIST}; do echo "    ${n}" >&2; done
  echo >&2
  echo "  Roep verwacht_minstens <gevonden> <ondergrens> <omschrijving> aan, of zet het" >&2
  echo "  script in de vrijstellingslijst met een reden. Zie CLAUDE.md." >&2
  exit 1
fi

echo "controle-gates: ${TOTAAL} scripts — ${DECLAREERT} declareren een verwachting, ${VRIJ} vrijgesteld met reden"
