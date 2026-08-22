#!/usr/bin/env bash
#
# Toetst de scripts die de gates dragen: ci/ en de demoscripts.
#
#   controle-gates.sh
#
#   1  telling         elk script declareert met verwacht_minstens hoeveel het verwachtte
#   2  oplosbaarheid   elk commandowoord lost ergens naar op
#   3  uitvoering      controle.sh draait elk script dat zonder deelsystemen kan draaien
#   4  bereikbaarheid  elk script wordt ergens aangeroepen
#
# Alle vier zijn omgekeerd geformuleerd: niet "wie wil meedoen meldt zich", maar "iedereen
# doet mee tenzij hij met reden is vrijgesteld". Vergeten is dan geen optie meer, en dat is
# het enige wat werkt.
#
# Regel 3 en 4 bestaan omdat een script dat nergens draait geen gate is maar een voornemen
# in een andere vorm. vergelijk-rapporten.sh werd alleen door de demo van scenario 1
# aangeroepen, en die draait niet in CI — daarom bleef exitcode 127 maanden onzichtbaar.
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

VANDAAG="$(date -u '+%Y-%m-%d')"

# --- vrijstellingen -----------------------------------------------------------------------
#
# Elke vrijstelling heeft een reden én een moment waarop hij opnieuw beoordeeld wordt. Zonder
# dat wordt vrijstellen de standaardroute: de eerste is altijd verdedigbaar, en op de tiende
# komt niemand terug. Staat de datum in het verleden, dan wordt dit script rood met de vraag
# om opnieuw te beslissen — niet omdat er iets stuk is, maar omdat de reden aan herijking toe
# is. Dezelfde behandeling als de uitzondering op de gegenereerde runbestanden.
#
# Dit raakt de demo's niet: controle-gates.sh draait in controle.sh en nergens anders, dus
# een verlopen datum maakt een push rood en geen presentatie.
#
# Vorm: "reden|jjjj-mm-dd".

# Regel 1: dit script velt geen oordeel over een verzameling, dus er valt niets te tellen.
vrijstelling_telling() {
  case "$1" in
    controle-gates.sh)        echo "toetst de gates zelf; zijn verzameling is deze lijst|2027-02-13" ;;
    controle.sh)              echo "roept andere controles aan en velt zelf geen oordeel|2027-02-13" ;;
    deploy.sh)                echo "zet iets neer, telt niets|2027-02-13" ;;
    opruimen.sh)              echo "ruimt op, telt niets|2027-02-13" ;;
    opruimen-alles.sh)        echo "ruimt op, telt niets|2027-02-13" ;;
    get-contract.sh)          echo "haalt één bestand op; ontbreken is al een fout|2027-02-13" ;;
    rapport-html.sh)          echo "zet een rapport om; een leeg rapport is geen fout|2027-02-13" ;;
    toon-versies.sh)          echo "toont wat er draait en oordeelt niet|2027-02-13" ;;
    wacht-op-gezond.sh)       echo "wacht op één toestand, geen verzameling|2027-02-13" ;;
    demo.sh)                  echo "vertelt een verhaal; de gates zitten in wat het aanroept|2027-02-13" ;;
    pipeline-acceptatie.sh)   echo "deployt en checkt health; de gates zitten in de aangeroepen scripts|2027-02-13" ;;
    pipeline-contract.sh)     echo "roept publish- en get-contract aan; die gates zitten daar|2027-02-13" ;;
    pipeline-microservice.sh) echo "roept Maven en Docker aan; die melden zelf hun aantallen|2027-02-13" ;;
    pipeline-test.sh)         echo "roept versieconformiteit en smoke aan; de gates zitten daar|2027-02-13" ;;
    pipeline-ci.sh)           echo "roept stub, drift en verificatie aan; de gates zitten daar|2027-02-13" ;;
    pipeline-gebruikersflows.sh) echo "roept gebruikersflow aan; de gate zit daar|2027-02-13" ;;
    pipeline-release.sh)      echo "roept bouw- en publiceer-release aan; de gates zitten daar|2027-02-13" ;;
    *) echo "" ;;
  esac
}

# Regel 3: dit script kan niet draaien zonder dat er deelsystemen staan. controle.sh draait
# bij elke push en heeft geen gebouwde images, geen gedeployde containers en geen omgeving.
# Alles wat hieronder staat wordt dus alleen door een demo gedraaid, en dát gat staat als
# openstaand punt in docs/besluiten.md.
vrijstelling_uitvoering() {
  case "$1" in
    neem-op.sh)               echo "zet de gebeurtenissen van een échte run om; vraagt een gedraaide demo|2027-02-22" ;;
    deploy.sh)                echo "zet een deelsysteem neer; vraagt gebouwde images|2027-02-13" ;;
    drift.sh)                 echo "bevraagt een draaiend deelsysteem|2027-02-13" ;;
    gebruikersflow.sh)        echo "Playwright tegen een draaiende keten|2027-02-13" ;;
    smoke.sh)                 echo "Playwright tegen een draaiend deelsysteem|2027-02-13" ;;
    verify-contract.sh)       echo "toetst een gedeployd deelsysteem tegen de spec|2027-02-13" ;;
    versieconformiteit.sh)    echo "leest info-endpoints van een omgeving|2027-02-13" ;;
    toon-versies.sh)          echo "leest info-endpoints van een omgeving|2027-02-13" ;;
    opruimen.sh)              echo "ruimt een omgeving op die er bij een push niet is|2027-02-13" ;;
    opruimen-alles.sh)        echo "ruimt omgevingen op die er bij een push niet zijn|2027-02-13" ;;
    rapport-html.sh)          echo "zet een rapport om dat bij een demorun hoort|2027-02-13" ;;
    pipeline-acceptatie.sh)   echo "deployt; vraagt gebouwde images|2027-02-13" ;;
    pipeline-ci.sh)           echo "deployt; vraagt gebouwde images|2027-02-13" ;;
    pipeline-test.sh)         echo "deployt; vraagt gebouwde images|2027-02-13" ;;
    pipeline-microservice.sh) echo "bouwt met Maven en Docker; te zwaar voor elke push|2027-02-13" ;;
    pipeline-gebruikersflows.sh) echo "vraagt een complete keten|2027-02-13" ;;
    pipeline-contract.sh)     echo "publiceert vanuit een demo; controle.sh publiceert zelf al|2027-02-13" ;;
    demo.sh)                  echo "draait de hele showcase; zie het openstaande punt in besluiten.md|2027-02-13" ;;
    publiceer-release.sh)     echo "vraagt een bestaande tag en een token; publiceren hoort niet bij elke push|2027-02-13" ;;
    pipeline-release.sh)      echo "draait op een tag, niet op een push; roept publiceer-release aan|2027-02-13" ;;
    *) echo "" ;;
  esac
}

# Splitst "reden|datum" en meldt zodra de datum verstreken is.
toets_vervalmoment() {
  _wat="$1"
  _naam="$2"
  _waarde="$3"
  _datum="${_waarde##*|}"
  case "${_datum}" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) fout "vrijstelling ${_wat} voor ${_naam} heeft geen herzieningsdatum" ;;
  esac
  if [ "${VANDAAG}" \> "${_datum}" ]; then
    VERVALLEN="${VERVALLEN}
    ${_naam} (${_wat}) — te herzien sinds ${_datum}: ${_waarde%|*}"
  fi
}

# Alles wat controle.sh direct of indirect aanroept. Transitief, want get-contract.sh draait
# wel degelijk mee bij elke push — via generate-stub.sh. Alleen naar de directe aanroepen
# kijken zou hem als niet-gedraaid melden en om een vrijstelling vragen die onwaar is.
bereik_van_controle() {
  _bereik="controle.sh"
  _ronde=1
  while [ "${_ronde}" -eq 1 ]; do
    _ronde=0
    for _s in ${SCRIPTS}; do
      _n="$(basename "${_s}")"
      case " ${_bereik} " in *" ${_n} "*) continue ;; esac
      for _b in ${_bereik}; do
        _p="${CBT_ROOT}/ci/${_b}"
        [ -f "${_p}" ] || continue
        if grep -qF "/${_n}" "${_p}"; then
          _bereik="${_bereik} ${_n}"
          _ronde=1
          break
        fi
      done
    done
  done
  echo "${_bereik}"
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
DRAAIT=0
VRIJ_UITVOERING=0
MIST_TELLING=""
MIST_OPLOSSING=""
MIST_UITVOERING=""
MIST_BEREIK=""
VERVALLEN=""

BEREIK="$(bereik_van_controle)"

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
      toets_vervalmoment telling "${KORT}" "${REDEN}"
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

  # --- 3: uitvoering door controle.sh ---
  if echo " ${BEREIK} " | grep -qF " ${NAAM} " && [ "${script}" = "${CBT_ROOT}/ci/${NAAM}" ]; then
    DRAAIT=$((DRAAIT + 1))
  else
    REDEN="$(vrijstelling_uitvoering "${NAAM}")"
    if [ -n "${REDEN}" ]; then
      VRIJ_UITVOERING=$((VRIJ_UITVOERING + 1))
      toets_vervalmoment uitvoering "${KORT}" "${REDEN}"
    else
      MIST_UITVOERING="${MIST_UITVOERING} ${KORT}"
    fi
  fi

  # --- 4: bereikbaarheid ---
  #
  # Een demo en controle.sh zijn aanroeppunten: daar begint iemand, dus die hoeven niet zelf
  # te worden aangeroepen. Al het andere moet ergens vandaan komen.
  #
  # Dit bestand telt niet mee als aanroeper: de namen in de vrijstellingslijsten zijn een
  # declaratie en geen aanroep, en zonder die uitzondering houdt de lijst zichzelf in stand.
  case "${KORT}" in
    ci/controle.sh|*/demo/demo.sh) ;;
    *)
      AANROEPERS=0
      for kandidaat in ${SCRIPTS}; do
        [ "${kandidaat}" = "${script}" ] && continue
        [ "$(basename "${kandidaat}")" = "controle-gates.sh" ] && continue
        grep -qF "/${NAAM}" "${kandidaat}" && AANROEPERS=$((AANROEPERS + 1))
      done
      grep -qF "${NAAM}" "${CBT_ROOT}/ci/lib/tools.sh" && AANROEPERS=$((AANROEPERS + 1))
      # De workflows tellen mee als aanroeper: pipeline-release.sh wordt door niets anders
      # gestart dan een tag, en zonder deze regel leest dat als dood gewicht.
      for wf in "${CBT_ROOT}"/.github/workflows/*.yml; do
        [ -f "${wf}" ] || continue
        grep -qF "${NAAM}" "${wf}" && AANROEPERS=$((AANROEPERS + 1))
      done
      [ "${AANROEPERS}" -eq 0 ] && MIST_BEREIK="${MIST_BEREIK} ${KORT}"
      ;;
  esac
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

if [ -n "${MIST_UITVOERING}" ]; then
  MELD=1
  echo "controle-gates: deze scripts worden door controle.sh niet gedraaid:" >&2
  for n in ${MIST_UITVOERING}; do echo "    ${n}" >&2; done
  echo "  Roep ze aan in ci/controle.sh, of zet ze in vrijstelling_uitvoering met reden." >&2
  echo "  Een gate die nergens draait is een voornemen in een andere vorm." >&2
  echo >&2
fi

if [ -n "${MIST_BEREIK}" ]; then
  MELD=1
  echo "controle-gates: deze scripts worden nergens aangeroepen:" >&2
  for n in ${MIST_BEREIK}; do echo "    ${n}" >&2; done
  echo "  Dood gewicht of een gat. Hier is geen vrijstelling voor." >&2
  echo >&2
fi

if [ -n "${VERVALLEN}" ]; then
  MELD=1
  echo "controle-gates: deze vrijstellingen zijn aan herziening toe:" >&2
  printf '%s\n' "${VERVALLEN}" >&2
  echo "  Beslis opnieuw en zet een nieuwe datum, of hef de vrijstelling op." >&2
  echo >&2
fi

[ "${MELD}" -eq 0 ] || exit 1

echo "controle-gates: ${TOTAAL} scripts"
echo "  telling         ${DECLAREERT} declareren een verwachting, ${VRIJ_TELLING} vrijgesteld met reden"
echo "  oplosbaarheid   elk commandowoord lost op"
echo "  uitvoering      ${DRAAIT} draaien mee in controle.sh, ${VRIJ_UITVOERING} vragen een omgeving"
echo "  bereikbaarheid  elk script wordt aangeroepen"
