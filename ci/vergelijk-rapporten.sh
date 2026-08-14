#!/usr/bin/env bash
#
# Toetst de bewering waar scenario 0 en 1 samen op rusten.
#
#   vergelijk-rapporten.sh <rapport-zonder-cbt> <rapport-met-cbt>
#
# Die bewering is: het verschil tussen de twee rapporten ís het werk dat contracttesten
# toevoegt. Dat klopt alleen zolang al het andere gelijk is — dezelfde deelsystemen,
# dezelfde versies, dezelfde volgorde, dezelfde pipelines.
#
# En dat breekt stilletjes. Voegt scenario 6 een deelsysteem toe aan één van beide, of
# hangt iemand een scène om, dan blijven allebei de scenario's gewoon groen en wordt
# alleen de conclusie onwaar. Een bewering die nergens door wordt afgedwongen is precies
# wat deze showcase aanvalt; dit script past dezelfde medicijn op de showcase zelf toe.
#
# Groen betekent: elke stap uit het eerste rapport komt in dezelfde volgorde terug in het
# tweede. Wat er dan in het tweede overblijft, is de toevoeging — geteld door een script en
# niet door de schrijver.
#
# Vergelijken gebeurt op onderdeel en stapnaam. Tijdstip en bijzonderheden verschillen per
# run, en de tekst van een oordeel luidt in scenario 0 anders dan in scenario 1; wat
# vergeleken wordt is de structuur en niet de formulering.
#
# Deze controle staat in geen van beide rapporten. Hij gaat niet over de deelsystemen maar
# over de showcase, en testbewijs van een deelsysteem hoort niet vermengd te raken met een
# controle op de demo.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "vergelijk-rapporten: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fout "gebruik: vergelijk-rapporten.sh <rapport-zonder-cbt> <rapport-met-cbt>"

ZONDER="$1"
MET="$2"

[ -f "${ZONDER}" ] || fout "geen rapport op ${ZONDER}. Draai eerst 00-start/demo/demo.sh"
[ -f "${MET}" ]    || fout "geen rapport op ${MET}. Draai eerst 01-basis/demo/demo.sh"

KA="$(mktemp)"
KB="$(mktemp)"
DELTA="$(mktemp)"
trap 'rm -f "${KA}" "${KB}" "${DELTA}"' EXIT

# Veld 3 is het onderdeel, veld 4 de stap. Beide met spaties eromheen; die blijven staan,
# want ze zijn aan beide kanten gelijk.
sleutels() {
  awk -F'|' '/^\| [0-9]/ { printf "%s|%s\n", $3, $4 }' "$1"
}

sleutels "${ZONDER}" > "${KA}"
sleutels "${MET}"    > "${KB}"

TOTAAL_ZONDER="$(wc -l < "${KA}" | tr -d ' ')"
TOTAAL_MET="$(wc -l < "${KB}" | tr -d ' ')"

verwacht_minstens "${TOTAAL_ZONDER}" 1 "stappen in ${ZONDER}"
verwacht_minstens "${TOTAAL_MET}" 1 "stappen in ${MET}"

echo "vergelijk-rapporten: $(basename "${ZONDER}") tegen $(basename "${MET}")"

# Loop het tweede rapport af en schuif een wijzer door het eerste op. Matcht een regel niet,
# dan is hij toegevoegd. Blijft de wijzer halverwege steken, dan ontbreekt er een stap of
# staat de volgorde anders — en dan is de koppeling gebroken.
i=1
while IFS= read -r kb; do
  ka="$(sed -n "${i}p" "${KA}")"
  if [ "${kb}" = "${ka}" ]; then
    i=$((i + 1))
  else
    printf '%s\n' "${kb}" >> "${DELTA}"
  fi
done < "${KB}"

GEVONDEN=$((i - 1))

if [ "${GEVONDEN}" -lt "${TOTAAL_ZONDER}" ]; then
  ONTBREEKT="$(sed -n "${i}p" "${KA}")"
  echo "  ROOD  ${GEVONDEN} van ${TOTAAL_ZONDER} stappen teruggevonden"
  echo "        vastgelopen op: ${ONTBREEKT}"
  echo
  echo "  De twee scenario's lopen niet meer gelijk. Daarmee is het verschil tussen de"
  echo "  rapporten niet langer alleen contracttesten, en zegt de vergelijking niets meer."
  echo "  Herstel de gelijkenis, of stel de bewering bij."
  exit 1
fi

TOEGEVOEGD="$(wc -l < "${DELTA}" | tr -d ' ')"

echo "  ok    alle ${TOTAAL_ZONDER} stappen komen terug, in dezelfde volgorde"
echo
echo "  ${TOEGEVOEGD} stappen toegevoegd door contracttesten:"
while IFS='|' read -r onderdeel stap; do
  _onderdeel="$(echo ${onderdeel})"
  _stap="$(echo ${stap})"
  # Een oordeelregel heeft geen stapnaam; "—" in een lijst met toevoegingen leest als een
  # ontbrekende waarde in plaats van als wat het is.
  [ "${_stap}" = "—" ] && _stap="(oordeel)"
  # Uitlijnen op tekens en niet op bytes: de pijl in het onderdeel is er drie lang.
  _vul="$(printf '%*s' "$((30 - $(printf '%s' "${_onderdeel}" | wc -m | tr -d ' ')))" '')"
  printf '        %s%s  %s\n' "${_onderdeel}" "${_vul}" "${_stap}"
done < "${DELTA}"
echo
echo "vergelijk-rapporten: ${TOTAAL_ZONDER} gelijk, ${TOEGEVOEGD} toegevoegd"
