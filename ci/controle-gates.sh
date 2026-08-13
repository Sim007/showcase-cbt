#!/usr/bin/env bash
#
# Toetst de scripts die de gates dragen: ci/ en de demoscripts.
#
#   controle-gates.sh
#
#   1  telling        elk script declareert met verwacht_minstens hoeveel het verwachtte
#   2  oplosbaarheid  elk commandowoord lost ergens naar op
#
# Beide regels zijn omgekeerd geformuleerd: niet "wie wil meedoen meldt zich", maar
# "iedereen doet mee tenzij hij met reden is vrijgesteld". Vergeten is dan geen optie meer,
# en dat is het enige wat werkt.
#
# Regel 2 bestaat omdat regel 1 een voornemen toetste. Hij keek of de tekst
# `verwacht_minstens` in het bestand vóórkwam, niet of die aanroep ook iets zou doen.
# vergelijk-rapporten.sh riep hem aan zonder lib/tools.sh te sourcen: exitcode 127, en deze
# gate meldde groen. De gate die stil groen moest uitroeien, was zelf stil groen. Zie
# docs/besluiten.md onder Geleerd.
#
# De demoscripts vallen hier ook onder. Zij zijn het enige dat het grootste deel van ci/
# draait; toetst dit script alleen ci/, dan blijft de aanroeper zelf ongetoetst — en juist
# via een demoscript kwam de bug hierboven aan het licht.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "controle-gates: $*" >&2
  exit 1
}

# De scripts die dit script beoordeelt: alles in ci/ plus elke demo.
SCRIPTS="$(ls "${CBT_ROOT}"/ci/*.sh "${CBT_ROOT}"/*/demo/demo.sh 2>/dev/null)"

# Shell-sleutelwoorden lossen op maar staan niet in PATH en zijn geen functie.
SLEUTELWOORDEN=" if then else elif fi for while until do done case esac in function
select time return break continue local export readonly shift set trap exit eval exec "

# Vrijgesteld van regel 1, met de reden erbij. Een script hoort hier alleen te staan als het
# geen oordeel velt over een verzameling — dan valt er niets te tellen.
vrijstelling_telling() {
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
    demo.sh)                  echo "vertelt een verhaal; de gates zitten in wat het aanroept" ;;
    pipeline-acceptatie.sh)   echo "deployt en checkt health; de gates zitten in de aangeroepen scripts" ;;
    pipeline-contract.sh)     echo "roept publish- en get-contract aan; die gates zitten daar" ;;
    pipeline-microservice.sh) echo "roept Maven en Docker aan; die melden zelf hun aantallen" ;;
    pipeline-test.sh)         echo "roept versieconformiteit en smoke aan; de gates zitten daar" ;;
    pipeline-ci.sh)           echo "roept stub, drift en verificatie aan; de gates zitten daar" ;;
    pipeline-gebruikersflows.sh) echo "roept gebruikersflow aan; de gate zit daar" ;;
    *) echo "" ;;
  esac
}

# --- regel 2: oplosbaarheid ---------------------------------------------------------------
#
# Elk commandowoord moet ergens naar oplossen: een builtin, iets in PATH, een functie in het
# script zelf, of een functie uit een bestand dat het script sourcet. Dat laatste is de kern
# — haal de source-regel weg en het antwoord verandert. Een tekstmatch doet dat niet.
#
# De naam is met opzet oplosbaarheid en niet uitvoerbaarheid. Wat dit niet ziet: een functie
# die bestaat maar verkeerd wordt aangeroepen, en een commandonaam die pas bij expansie
# ontstaat. Een gate die meer belooft dan hij doet is hetzelfde patroon als een lus die
# groen meldt over ongecontroleerde berichten, en dat is precies wat hier wordt opgeruimd.
# De resolutie draait in een vérse bash en niet in een subshell. Dat is geen detail: dit
# script sourcet zelf tools.sh, en een subshell erft die functies. De eerste versie hiervan
# meldde daardoor groen op een script waar de source-regel uit was gehaald — de toets keek
# naar zijn eigen omgeving in plaats van naar die van het script. Precies de fout die hij
# moet vangen, één niveau hoger.
onoplosbaar() {
  _script="$1"
  _eigen=" $(grep -o '^[a-zA-Z_][a-zA-Z_0-9]*()' "${_script}" | tr -d '()' | tr '\n' ' ') "
  _bronnen="$(grep -o 'CBT_ROOT}/ci/lib/[a-z.]*\.sh' "${_script}" \
              | sed "s|CBT_ROOT}|${CBT_ROOT}|" | sort -u | tr '\n' ' ')"
  _woorden="$(awk -f "${CBT_ROOT}/ci/lib/commandowoorden.awk" "${_script}" | sort -u | tr '\n' ' ')"

  BRONNEN="${_bronnen}" WOORDEN="${_woorden}" EIGEN="${_eigen}" SLEUTEL="${SLEUTELWOORDEN}" \
  bash --noprofile --norc -c '
    for b in ${BRONNEN}; do . "${b}"; done
    for w in ${WOORDEN}; do
      case "${SLEUTEL}" in *" ${w} "*) continue ;; esac
      case "${EIGEN}" in *" ${w} "*) continue ;; esac
      command -v "${w}" >/dev/null 2>&1 || printf "%s " "${w}"
    done
  '
}

# --- de ronde -----------------------------------------------------------------------------

TOTAAL=0
DECLAREERT=0
VRIJ_TELLING=0
MIST_TELLING=""
MIST_OPLOSSING=""

for script in ${SCRIPTS}; do
  NAAM="$(basename "${script}")"
  KORT="${script#"${CBT_ROOT}/"}"
  TOTAAL=$((TOTAAL + 1))

  # --- 1: telling ---
  if grep -q 'verwacht_minstens' "${script}"; then
    DECLAREERT=$((DECLAREERT + 1))
  else
    REDEN="$(vrijstelling_telling "${NAAM}")"
    if [ -n "${REDEN}" ]; then
      VRIJ_TELLING=$((VRIJ_TELLING + 1))
    else
      MIST_TELLING="${MIST_TELLING} ${KORT}"
    fi
  fi

  # --- 2: oplosbaarheid ---
  ONBEKEND="$(onoplosbaar "${script}")"
  if [ -n "${ONBEKEND}" ]; then
    MIST_OPLOSSING="${MIST_OPLOSSING}
    ${KORT}: ${ONBEKEND}"
  fi
done

verwacht_minstens "${TOTAAL}" 20 "scripts nagelopen"

MELD=0

if [ -n "${MIST_TELLING}" ]; then
  MELD=1
  echo "controle-gates: deze scripts vellen een oordeel zonder te zeggen hoeveel ze verwachtten:" >&2
  for n in ${MIST_TELLING}; do echo "    ${n}" >&2; done
  echo "  Roep verwacht_minstens aan, of zet het script in vrijstelling_telling met reden." >&2
  echo >&2
fi

if [ -n "${MIST_OPLOSSING}" ]; then
  MELD=1
  echo "controle-gates: deze commando's lossen nergens naar op:" >&2
  printf '%s\n' "${MIST_OPLOSSING}" >&2
  echo "  Een aanroep die niet oplost is exitcode 127 op runtime, en geen enkele gate." >&2
  echo "  Meestal ontbreekt er een . \"\${CBT_ROOT}/ci/lib/tools.sh\"." >&2
  echo >&2
fi

[ "${MELD}" -eq 0 ] || exit 1

echo "controle-gates: ${TOTAAL} scripts"
echo "  telling        ${DECLAREERT} declareren een verwachting, ${VRIJ_TELLING} vrijgesteld met reden"
echo "  oplosbaarheid  elk commandowoord lost op"
