#!/usr/bin/env bash
#
# Toetst de stamdata van de scenario's.
#
#   toets-stamdata.sh                      structuur, altijd te draaien
#   toets-stamdata.sh <id> <rapport.md>    plus: komt de stamdata overeen met een echte run
#
# **Waarom dit bestaat.** De stamdata van scenario 01 had zes stappen terwijl zijn rapport er
# 27 telt. Daarmee kon showcase-website het verschil tussen scenario 00 en 01 — acht stappen,
# het hele verhaal van deze showcase — niet tonen, ook niet als 00 zijn eigen stamdata kreeg.
# Zes generieke stappen tonen een dashboard dat werkt, niet een testproces dat iets vangt.
#
# Dat verschil is nu de norm, en een norm zonder gate drift terug zodra iemand een pipeline
# aanpast. Dit script is die gate.
#
# **Twee delen, en dat is geen indeling maar een eerlijkheid.** De structuurcontroles draaien
# altijd: ze hebben alleen de stamdata en de gepubliceerde spec nodig. De vergelijking met een
# rapport kan dat niet — daar is een volledige demo voor nodig, met images, deploys en
# omgevingen. Die wordt daarom aan het eind van een demo aangeroepen, net als
# vergelijk-rapporten.sh, en staat met reden op de vrijstellingslijst in controle-gates.sh.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "toets-stamdata: $*" >&2
  exit 1
}

GROEP="${CBT_STAMDATA_GROEP:-showcase-cbt}"
ARTIFACT="${CBT_STAMDATA_ARTIFACT:-scenario-api}"
VERSIE="${CBT_STAMDATA_VERSIE:-0.12.0}"

STAMDATA="${CBT_ROOT}/stamdata/scenarios"
STAMDATA_REL="stamdata/scenarios"
WERK="${CBT_ROOT}/build/stamdatatoets"
WERK_REL="build/stamdatatoets"
rm -rf "${WERK}"; mkdir -p "${WERK}"

[ -d "${STAMDATA}" ] || fout "geen stamdata op ${STAMDATA_REL}"

BESTANDEN="$(ls "${STAMDATA}"/*.json 2>/dev/null || true)"
[ -n "${BESTANDEN}" ] || fout "geen scenario's in ${STAMDATA_REL}"

# --- 1: elk scenario valideert tegen het Scenario-schema uit de gepubliceerde spec ---------
#
# Uit het register en niet van schijf, zoals overal. Zonder deze controle is stamdata
# handgeschreven materiaal dat toevallig lijkt te passen — en dan is de bundel niet langer
# "er staat niets in wat niet uit het contract komt".

SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}")"
yq -o=json '.' "${SPEC#"${CBT_ROOT}/"}" > "${WERK}/spec.json"

jq '{ "$ref": "#/components/schemas/Scenario", components: { schemas: .components.schemas } }' \
  "${WERK_REL}/spec.json" > "${WERK}/scenario-schema.json"

AANTAL=0
for pad in ${BESTANDEN}; do
  naam="$(basename "${pad}" .json)"
  cp "${pad}" "${WERK}/${naam}.json"

  ajv validate -s "${WERK_REL}/scenario-schema.json" -d "${WERK_REL}/${naam}.json" --strict=false >/dev/null 2>&1 \
    || fout "${STAMDATA_REL}/${naam}.json voldoet niet aan het Scenario-schema van ${ARTIFACT} ${VERSIE}"

  ID="$(jq -r '.id' < "${pad}")"
  [ "${ID}" = "${naam}" ] \
    || fout "${STAMDATA_REL}/${naam}.json draagt id ${ID}; bestandsnaam en id horen hetzelfde te zijn"

  # Nummers uniek en oplopend vanaf 1. De stream verwijst per stapNummer, dus een gat of een
  # dubbele maakt een bericht onplaatsbaar.
  jq -e '[.stappen[].nummer] == [range(1; (.stappen | length) + 1)]' < "${pad}" >/dev/null \
    || fout "${STAMDATA_REL}/${naam}.json heeft stapnummers die niet 1..n zijn"

  # Elke verwijzing wijst naar iets dat in dit scenario staat. Een stap op een omgeving die
  # niet bestaat is op een scherm niet te plaatsen, en het schema kan dat niet zien.
  jq -e '. as $s
         | ([.stappen[] | select(.deelsysteem) | .deelsysteem] - [$s.deelsystemen[].id] | length == 0)
           and ([.stappen[] | select(.omgeving) | .omgeving] - [$s.omgevingen[].id] | length == 0)' \
    < "${pad}" >/dev/null \
    || fout "${STAMDATA_REL}/${naam}.json verwijst naar een deelsysteem of omgeving die er niet in staat"

  echo "  ok    ${naam}: $(jq -r '.stappen | length' < "${pad}") stappen, geldig tegen het schema"
  AANTAL=$((AANTAL + 1))
done

verwacht_minstens "${AANTAL}" 2 "scenario's in de stamdata"

# --- 2: 01 is 00 plus de acht ---------------------------------------------------------------
#
# De gecontroleerde vergelijking, nu op de stamdata in plaats van alleen op de rapporten.
# Scenario 00 en 01 draaien dezelfde deelsystemen in dezelfde volgorde met dezelfde versies;
# het enige verschil is contracttesten. Klopt die insluiting niet meer, dan is de aftrekking
# niets meer waard — en dat is het argument van de hele showcase.

sleutels() {
  jq -r '.stappen[] | "\(.deelsysteem // "keten")\t\(.omschrijving)"' < "$1"
}

[ -f "${STAMDATA}/00.json" ] && [ -f "${STAMDATA}/01.json" ] || {
  echo "toets-stamdata: ${AANTAL} scenario's gecontroleerd; 00 en 01 nog niet allebei aanwezig"
  exit 0
}

sleutels "${STAMDATA}/00.json" > "${WERK}/00.sleutels"
sleutels "${STAMDATA}/01.json" > "${WERK}/01.sleutels"

# De acht die contracttesten toevoegt, met naam. Ze staan hier uitgeschreven en niet geteld:
# een aantal zegt niet welke, en juist de namen dragen het verhaal.
cat > "${WERK}/verwachte-toevoeging" <<'EOF'
payment	diff-gate en publiceren
payment	ophalen ter controle
payment	drift
payment	contractverificatie, provider
payment	versieconformiteit
order	stub uit payment payment-api 1.0.0
order	contractverificatie, consumer
order	versieconformiteit
EOF

# Wat er in 01 staat en niet in 00, in de volgorde van 01.
awk 'NR==FNR { nul[$0]++; next } { if (nul[$0]) { nul[$0]--; next } print }' \
  "${WERK}/00.sleutels" "${WERK}/01.sleutels" > "${WERK}/toevoeging"

diff "${WERK}/verwachte-toevoeging" "${WERK}/toevoeging" >/dev/null 2>&1 || {
  echo "toets-stamdata: wat scenario 01 toevoegt aan 00 is niet meer wat het was:" >&2
  diff "${WERK}/verwachte-toevoeging" "${WERK}/toevoeging" | sed 's/^/    /' >&2
  fout "de gecontroleerde vergelijking klopt niet meer"
}

# En andersom: elke stap van 00 komt in 01 terug, in dezelfde volgorde.
awk 'NR==FNR { toe[$0]++; next } { if (toe[$0]) { toe[$0]--; next } print }' \
  "${WERK}/toevoeging" "${WERK}/01.sleutels" > "${WERK}/01-zonder-toevoeging"

diff "${WERK}/00.sleutels" "${WERK}/01-zonder-toevoeging" >/dev/null 2>&1 \
  || fout "scenario 01 bevat de stappen van 00 niet meer in dezelfde volgorde"

TOEGEVOEGD="$(wc -l < "${WERK}/toevoeging" | tr -d ' ')"
verwacht_minstens "${TOEGEVOEGD}" 8 "stappen die 01 toevoegt aan 00"
echo "  ok    01 is 00 plus ${TOEGEVOEGD} stappen, met naam en in volgorde"

# --- 3: tegen een echt rapport, als er een is -----------------------------------------------
#
# Alleen zinvol na een demo. De staprijen van het rapport zijn wat er werkelijk gedraaid heeft;
# de stamdata is wat wij beloofd hebben dat er zou draaien. Lopen die uiteen, dan toont de
# website iets anders dan de pipeline doet — precies het gat waar dit script voor bestaat.

if [ "$#" -eq 2 ]; then
  ID="$1"; RAPPORT="$2"
  [ -f "${STAMDATA}/${ID}.json" ] || fout "geen stamdata voor scenario ${ID}"
  [ -f "${RAPPORT}" ] || fout "geen rapport op ${RAPPORT}"

  # De oordeelregels horen bij de run en niet bij de structuur: een oordeel is een uitkomst,
  # en uitkomsten staan bewust niet in de stamdata.
  awk -F'|' '/^\| [0-9]/ { gsub(/^ +| +$/, "", $4); if ($4 != "—") print $4 }' "${RAPPORT}" \
    > "${WERK}/rapport.stappen"

  jq -r '.stappen[].omschrijving' < "${STAMDATA}/${ID}.json" > "${WERK}/stamdata.stappen"

  diff "${WERK}/stamdata.stappen" "${WERK}/rapport.stappen" >/dev/null 2>&1 || {
    echo "toets-stamdata: de stamdata van scenario ${ID} en zijn rapport lopen uiteen:" >&2
    echo "    < stamdata, > rapport" >&2
    diff "${WERK}/stamdata.stappen" "${WERK}/rapport.stappen" | sed 's/^/    /' >&2
    fout "de website zou iets anders tonen dan de pipeline doet"
  }

  GEZIEN="$(wc -l < "${WERK}/rapport.stappen" | tr -d ' ')"
  verwacht_minstens "${GEZIEN}" 19 "staprijen in het rapport van scenario ${ID}"
  echo "  ok    scenario ${ID}: ${GEZIEN} staprijen, gelijk aan de stamdata"
fi

rm -rf "${WERK}"
echo "toets-stamdata: ${AANTAL} scenario's, geldig tegen het schema en onderling consistent"
