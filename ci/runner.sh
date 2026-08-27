#!/usr/bin/env bash
#
# Haalt werk op bij de provider en draait het scenario dat gevraagd wordt.
#
#   runner.sh [provider-url]        standaard http://localhost:8090
#
# **Waarom trekken en niet geduwd worden.** De provider draait in een container en het werk
# gebeurt op de host: images bouwen, containers starten, een register omhoog. Zou de provider
# dat starten, dan had hij de Docker-socket nodig — root-equivalent op deze machine — plus een
# mount van de repository, want het demoscript staat hier en niet in de image. Twee prijzen
# voor één functie. Andersom kost het niets: dit script is bash en curl, en die zijn er al.
#
# **Dit is een uitvoerkanaal, en dat is geen bijzin.** Wat de provider vraagt, start deze
# laptop. Het is nauwer dan een socket — alleen de scenario's uit de lijst hieronder, alleen
# hun demoscript — maar het is van dezelfde soort, en de afweging staat in docs/security.md.
#
# **De controle op het scenario staat hier los van die in de provider.** Niet omdat de
# provider onbetrouwbaar is, maar omdat "hij heeft het al gecontroleerd" precies de aanname is
# die een uitvoerkanaal gevaarlijk maakt. Er wordt hier nooit een pad samengesteld uit wat er
# over de lijn komt: de `case` hieronder is de hele verzameling van wat dit script kan
# starten, en iets dat er niet in staat wordt geweigerd en gemeld.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${CBT_ROOT}"

PROVIDER="${1:-${CBT_PROVIDER:-http://localhost:8090}}"
INTERVAL="${RUNNER_INTERVAL:-1}"

echo "runner: luistert bij ${PROVIDER}, elke ${INTERVAL}s"
echo "  kan starten: 00, 01 — en niets anders"

# scenario_script <id>
#
# De expliciete lijst. Geen samenstelling, geen map die wordt opgezocht, geen glob. Komt er
# iets binnen dat hier niet staat, dan is het antwoord niets doen en het melden.
scenario_script() {
  case "$1" in
    00) echo "00-start/demo/demo.sh" ;;
    01) echo "01-basis/demo/demo.sh" ;;
    *)  echo "" ;;
  esac
}

draai() {
  _id="$1"
  _runid="$2"

  # Tweede controle, onafhankelijk van de provider. Eerst de vorm, dan de lijst.
  case "${_id}" in
    [0-9][0-9]) ;;
    *) echo "runner: '${_id}' is geen scenario-id — genegeerd" >&2; return 0 ;;
  esac

  _script="$(scenario_script "${_id}")"
  if [ -z "${_script}" ]; then
    echo "runner: scenario ${_id} staat niet op de lijst van wat dit script mag starten — genegeerd" >&2
    return 0
  fi
  [ -f "${CBT_ROOT}/${_script}" ] || { echo "runner: ${_script} bestaat niet" >&2; return 0; }

  echo "runner: scenario ${_id} (${_runid}) — ${_script}"

  # CBT_LIVE uit: dit is een run die op het scherm van showcase-website wordt gevolgd, en de
  # rapportpagina hoort daar niet ongevraagd overheen te komen.
  CBT_LIVE=0 CBT_PROVIDER="${PROVIDER}" "${CBT_ROOT}/${_script}" >/dev/null 2>&1 \
    && echo "runner: scenario ${_id} klaar" \
    || echo "runner: scenario ${_id} eindigde rood — de stream heeft het gemeld" >&2
}

opruimen() { echo; echo "runner: gestopt"; }
trap opruimen EXIT INT TERM

# **De demo draait op de achtergrond en de lus blijft doorpollen.**
#
# Hij riep `draai` synchroon aan, dus tijdens een run van anderhalve minuut vroeg deze runner
# geen werk op. De provider concludeert uit die stilte dat er niemand luistert, en dat is
# onwaar op precies het moment dat de runner het hardst aan het werk is. Tijdens de run
# maskeert de lopende run dat met een 409, maar in het gat tussen `run-afgerond` en de
# volgende poll krijgt de aanroeper `503 GEEN_RUNNER` — een onwaar antwoord op het moment dat
# iemand opnieuw drukt.
#
# Dubbel starten kan hierdoor niet: de provider geeft geen werk uit zolang er een run loopt,
# en de wacht hieronder is het tweede net voor het geval dat toch gebeurt.
DEMO_PID=""
bezig() { [ -n "${DEMO_PID}" ] && kill -0 "${DEMO_PID}" 2>/dev/null; }

while true; do
  # Elke ophaalpoging laat bij de provider zien dat hier iemand luistert. Blijft dat uit, dan
  # weigert hij een start in plaats van hem stil aan te nemen.
  ANTWOORD="$(curl -fsS --max-time 5 "${PROVIDER}/intern/werk" 2>/dev/null || true)"

  if [ -n "${ANTWOORD}" ]; then
    ID="$(printf '%s' "${ANTWOORD}" | sed -n 's/.*"scenarioId":"\([^"]*\)".*/\1/p')"
    RUNID="$(printf '%s' "${ANTWOORD}" | sed -n 's/.*"runId":"\([^"]*\)".*/\1/p')"
    if [ -n "${ID}" ]; then
      if bezig; then
        echo "runner: werk voor scenario ${ID} genegeerd — er loopt er al een" >&2
      else
        draai "${ID}" "${RUNID}" &
        DEMO_PID=$!
      fi
    fi
  fi

  sleep "${INTERVAL}"
done
