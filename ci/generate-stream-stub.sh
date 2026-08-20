#!/usr/bin/env bash
#
# Genereert de stub van de run-stream, uit de spec uit het register.
#
#   generate-stream-stub.sh <groep> <stream-artifact> <versie> <scenario-id>
#
# De tegenhanger van generate-stub.sh, voor een grens zonder request-response. Een stream
# heeft geen operaties om te beantwoorden maar een verloop om af te spelen, dus wat hier
# gegenereerd wordt zijn runs: de berichten in de volgorde waarin ze zouden komen.
#
# Twee bronnen:
#   de AsyncAPI-spec   levert de vorm van elk bericht, uit zijn schema — uit het register
#   de stamdata        levert welke stappen er zijn — uit stamdata/scenarios/<id>.json
#
# Dat de volgorde uit de stamdata komt is geen omweg maar de bedoeling: een stub die zelf
# stappen verzint, toont een run die nergens beschreven staat.
#
# **De stappen kwamen tot 2026-08-20 uit het example van de scenario-spec.** Dat is verplaatst
# omdat een example illustratie is en stamdata inhoud: met tien scenario's zou elk nieuw
# scenario een contractwijziging van scenario-api zijn. De scenario-spec is daarmee geen bron
# meer voor dit script — de vorm van een scenario staat er nog steeds in, de inhoud niet.
#
# --- Drie situaties, en waarom precies deze ------------------------------------------
#
# Een stub die alleen een geslaagde run serveert, laat de aanroeper zijn afleidlogica
# bouwen tegen iets wat niet bestaat. Juist wat hij moet afleiden — deelsysteem-status,
# "niet uitgevoerd", de reden waarom een run ophield — hangt aan een run die stópt. Dat was
# ook de kritiek op de simulator aan de andere kant: alles stond op geslaagd, en het
# mislukte pad was nooit gelopen.
#
#   1  voltooid   alle stappen komen aan bod en slagen
#   2  gestopt    een stap mislukt; de stappen erna krijgen geen enkel bericht
#   3  midden     een momentopname midden in een lopende run, voor de late kijker
#
# Ze wisselen elkaar af via een WireMock-scenario: elke nieuwe verbinding krijgt de
# volgende. Dat blijft binnen het contract — hetzelfde endpoint, geen extra parameter die
# nergens beschreven staat — en het lijkt op de werkelijkheid, waar je ook krijgt wat er
# op dat moment gebeurt.
#
# Server-Sent Events over WireMock, met chunkedDribbleDelay zodat de berichten na elkaar
# binnenkomen in plaats van in één klap. Geen extra gereedschap: de stub die de REST-kant
# serveert doet ook deze.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "generate-stream-stub: $*" >&2
  exit 1
}

# --controleer genereert niets weg maar vergelijkt: bedoeld voor een pipeline, zodat de
# vastgelegde runbestanden niet stil uit de pas kunnen lopen met de spec.
CONTROLEER=""
for _arg in "$@"; do
  [ "${_arg}" = "--controleer" ] && CONTROLEER=ja
done
if [ -n "${CONTROLEER}" ]; then
  set -- "$1" "$2" "$3" "$4"
fi

[ "$#" -eq 4 ] || fout "gebruik: generate-stream-stub.sh <groep> <stream-artifact> <versie> <scenario-id> [--controleer]"

GROEP="$1"
STREAM="$2"
STREAM_VERSIE="$3"
SCENARIO_ID="$4"

UIT="${CBT_ROOT}/build/stub"
TMP="${UIT}/tmp"
REL="build/stub"
mkdir -p "${UIT}/mappings" "${TMP}"

# Schrijft alleen zijn eigen mappings bij en ruimt de map niet leeg, anders dan
# generate-stub.sh. Een grens met REST én een stream wordt door één stub bediend: eerst de
# operaties, dan deze erbij.
rm -f "${UIT}"/mappings/run-stream-*.json

# --- stap 1: beide specs ophalen, altijd uit het register -------------------------------

STREAM_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}")"

# Het gereedschap draait in een container die de hoofdmap als /work ziet, dus krijgt het
# relatieve paden. De shell zelf werkt met absolute — zelfde afspraak als in generate-stub.
yq -o=json '.' "${STREAM_SPEC#"${CBT_ROOT}/"}" > "${TMP}/stream.json"

echo "stap 1: ${GROEP}/${STREAM} ${STREAM_VERSIE} opgehaald uit het register"

# --- stap 2: de stappen uit de stamdata ---------------------------------------------------

STAMDATA="${CBT_ROOT}/stamdata/scenarios/${SCENARIO_ID}.json"
[ -f "${STAMDATA}" ] || fout "geen stamdata op stamdata/scenarios/${SCENARIO_ID}.json"
cp "${STAMDATA}" "${TMP}/scenario-example.json"

STAPPEN="$(jq -r '.stappen | length' "${REL}/tmp/scenario-example.json")"
[ "${STAPPEN}" -ge 3 ] || fout "scenario ${SCENARIO_ID} heeft ${STAPPEN} stappen; er zijn er minstens drie nodig om een run te laten stoppen met stappen erna"

# Waar het misgaat in situatie 2. Bij voorkeur een gate — dat is de stap die bedoeld is om
# tegen te houden — en nooit de laatste, want dan blijft er niets over om stil te laten.
FAALT="$(jq -r --argjson laatste "$((STAPPEN - 1))" \
  '[.stappen | to_entries[] | select(.key < $laatste) | select(.value.type == "gate") | .value.nummer] | first // empty' \
  "${REL}/tmp/scenario-example.json")"
[ -n "${FAALT}" ] || FAALT="$(jq -r --argjson i "$((STAPPEN - 2))" '.stappen[$i].nummer' "${REL}/tmp/scenario-example.json")"

echo "stap 2: ${STAPPEN} stappen in het example van scenario ${SCENARIO_ID}; stap ${FAALT} mislukt in de gestopte run"

# --- stap 3: de drie verlopen samenstellen ----------------------------------------------

tijdstip() {
  awk -v n="$1" 'BEGIN {
    s = 9*3600 + 12*60 + 44 + n
    printf "2026-08-06T%02d:%02d:%02dZ", int(s/3600), int(s%3600/60), s%60
  }'
}

stap_veld() {
  jq -r --argjson i "$1" ".stappen[\$i].$2" "${REL}/tmp/scenario-example.json"
}

# regel <bestand> <schema> <json>
regel() {
  printf '%s\t%s\n' "$2" "$3" >> "$1"
}

# stapberichten <bestand> <index> <uitkomst>
stapberichten() {
  _b="$1"; _i="$2"; _u="$3"
  _nr="$(stap_veld "${_i}" nummer)"
  _cli="$(stap_veld "${_i}" cli)"

  regel "${_b}" StapGestartPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" --argjson nr "${_nr}" \
    '{soort:"stap-gestart", tijd:$t, runId:$rid, stapNummer:$nr}')"
  N=$((N + 1))

  regel "${_b}" CliUitvoerPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" --argjson nr "${_nr}" --arg r "$ ${_cli}" \
    '{soort:"cli-uitvoer", tijd:$t, runId:$rid, stapNummer:$nr, regel:$r}')"
  N=$((N + 1))

  regel "${_b}" StapAfgerondPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" --argjson nr "${_nr}" --arg u "${_u}" \
    '{soort:"stap-afgerond", tijd:$t, runId:$rid, stapNummer:$nr, uitkomst:$u}')"
  N=$((N + 1))
}

# --- drie opnames, drie runId's -----------------------------------------------------------
#
# Ze droegen alle drie `run-7c41a9`. Dat is niet alleen onoefenbaar maar verkeerd oefenbaar:
# drie verschillende verlopen die beweren dezelfde run te zijn. Een consumer die op `runId`
# bijhoudt welke run hij volgt — en dat is precies wat hij moet doen zodra de stream open
# blijft tussen runs door — kan daar niets zinnigs mee.
#
# Vast en niet willekeurig: de fixtures zijn uitgerekend en bit-voor-bit reproduceerbaar, en
# dat blijft de voorwaarde waaronder ze gecommit mogen staan. `voltooid` houdt het bestaande
# nummer, zodat de examples in de spec en de documentatie blijven kloppen.
RUN_ID_VOLTOOID=run-7c41a9
RUN_ID_GESTOPT=run-3b8e02
RUN_ID_MIDDEN=run-9d15f4

# --- situatie 1: voltooid ---------------------------------------------------------------

RUN_ID="${RUN_ID_VOLTOOID}"
V1="${TMP}/verloop-voltooid.jsonl"; : > "${V1}"; N=0

regel "${V1}" MomentopnamePayload "$(jq -cn --arg t "$(tijdstip $N)" \
  '{soort:"momentopname", tijd:$t, run:null, afgerondeStappen:[]}')"
N=$((N + 1))
regel "${V1}" RunGestartPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" --arg s "${SCENARIO_ID}" \
  '{soort:"run-gestart", tijd:$t, runId:$rid, scenarioId:$s}')"
N=$((N + 1))

I=0
while [ "${I}" -lt "${STAPPEN}" ]; do
  stapberichten "${V1}" "${I}" geslaagd
  I=$((I + 1))
done

regel "${V1}" RunAfgerondPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" \
  '{soort:"run-afgerond", tijd:$t, runId:$rid, reden:"voltooid"}')"

# --- situatie 2: gestopt op een mislukte stap -------------------------------------------
#
# De stappen ná de mislukte krijgen geen enkel bericht. Dat is geen omissie in de stub maar
# de afspraak: "niet uitgevoerd" volgt uit het uitblijven van berichten.

RUN_ID="${RUN_ID_GESTOPT}"
V2="${TMP}/verloop-gestopt.jsonl"; : > "${V2}"; N=0

regel "${V2}" MomentopnamePayload "$(jq -cn --arg t "$(tijdstip $N)" \
  '{soort:"momentopname", tijd:$t, run:null, afgerondeStappen:[]}')"
N=$((N + 1))
regel "${V2}" RunGestartPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" --arg s "${SCENARIO_ID}" \
  '{soort:"run-gestart", tijd:$t, runId:$rid, scenarioId:$s}')"
N=$((N + 1))

I=0
STIL=0
while [ "${I}" -lt "${STAPPEN}" ]; do
  NR="$(stap_veld "${I}" nummer)"
  if [ "${NR}" -lt "${FAALT}" ]; then
    stapberichten "${V2}" "${I}" geslaagd
  elif [ "${NR}" -eq "${FAALT}" ]; then
    stapberichten "${V2}" "${I}" mislukt
  else
    STIL=$((STIL + 1))
  fi
  I=$((I + 1))
done

regel "${V2}" RunAfgerondPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" --argjson bij "${FAALT}" \
  '{soort:"run-afgerond", tijd:$t, runId:$rid, reden:"gestopt", gestoptBijStap:$bij}')"

# --- situatie 3: midden in een lopende run ----------------------------------------------
#
# Geen run-gestart: die is al voorbij. De momentopname draagt wat er al af is, en verder
# geen cli-uitvoer — die is voor deze kijker weg, en dat is bewust.

RUN_ID="${RUN_ID_MIDDEN}"
RUN_JSON="$(jq -cn --arg rid "${RUN_ID}" --arg s "${SCENARIO_ID}" --arg t "$(tijdstip 0)" '{runId:$rid, scenarioId:$s, gestartOp:$t}')"
V3="${TMP}/verloop-midden.jsonl"; : > "${V3}"; N=6

# In één aanroep en niet in een lus met een pipe. Een container in een pijp die een andere
# container voedt, eet de invoer van die tweede op — dezelfde val als bij de validatielus,
# in een andere vorm. Zie docs/besluiten.md.
AL_AF="$(jq -c '[.stappen[0:2][] | {stapNummer: .nummer, uitkomst: "geslaagd"}]' \
  "${REL}/tmp/scenario-example.json")"
LOPEND="$(stap_veld 2 nummer)"

regel "${V3}" MomentopnamePayload "$(jq -cn --arg t "$(tijdstip $N)" --argjson run "${RUN_JSON}" \
  --argjson af "${AL_AF}" --argjson lopend "${LOPEND}" \
  '{soort:"momentopname", tijd:$t, run:$run, afgerondeStappen:$af, lopendeStap:$lopend}')"
N=$((N + 1))

I=2
while [ "${I}" -lt "${STAPPEN}" ]; do
  stapberichten "${V3}" "${I}" geslaagd
  I=$((I + 1))
done

regel "${V3}" RunAfgerondPayload "$(jq -cn --arg rid "${RUN_ID}" --arg t "$(tijdstip $N)" \
  '{soort:"run-afgerond", tijd:$t, runId:$rid, reden:"voltooid"}')"

echo "stap 3: $(wc -l < "${V1}" | tr -d ' ') / $(wc -l < "${V2}" | tr -d ' ') / $(wc -l < "${V3}" | tr -d ' ') berichten (voltooid / gestopt / midden), ${STIL} stappen zonder bericht"

# --- stap 4: elk bericht tegen zijn eigen schema -----------------------------------------
#
# Dezelfde artefactcontrole als stap 7 van generate-stub.sh, en om dezelfde reden: een stub
# die iets stuurt wat niet aan de spec voldoet, leert de aanroeper iets aan wat straks
# nergens op slaat.

jq '{ components: { schemas: .components.schemas } }' "${REL}/tmp/stream.json" > "${TMP}/stream-componenten.json"

# De lus leest van fd 3 en niet van stdin: elk gereedschap hierbinnen draait in een
# interactieve container en zou anders de rest van het bestand opslokken. Dan stopt de lus
# na één bericht en meldt de controle groen over berichten die niemand bekeek — hoe dat
# ontdekt is, staat in docs/besluiten.md.
GEVALIDEERD=0
for verloop in "${V1}" "${V2}" "${V3}"; do
  while IFS="$(printf '\t')" read -r schema bericht <&3; do
    jq --arg ref "#/components/schemas/${schema}" '. + {"$ref": $ref}' \
      "${REL}/tmp/stream-componenten.json" > "${TMP}/s-${GEVALIDEERD}.json"
    printf '%s' "${bericht}" > "${TMP}/b-${GEVALIDEERD}.json"

    ajv validate --strict=false -c ajv-formats \
      -s "${REL}/tmp/s-${GEVALIDEERD}.json" \
      -d "${REL}/tmp/b-${GEVALIDEERD}.json" >/dev/null 2>&1 \
      || fout "$(basename "${verloop}"), bericht ${GEVALIDEERD} voldoet niet aan ${schema}: ${bericht}"

    GEVALIDEERD=$((GEVALIDEERD + 1))
  done 3< "${verloop}"
done

verwacht_minstens "${GEVALIDEERD}" 1 "berichten gevalideerd"
echo "stap 4: ${GEVALIDEERD} berichten voldoen aan hun payloadschema"

# --- stap 5: de mappings wegschrijven ----------------------------------------------------

PAD="$(jq -r '.channels | keys | .[0]' "${REL}/tmp/stream.json")"

# mapping <bestand> <verloop> <huidige-staat> <volgende-staat>
mapping() {
  _n="$(wc -l < "$2" | tr -d ' ')"
  cut -f2 "$2" | awk '{ printf "data: %s\n\n", $0 }' > "${TMP}/body.txt"

  jq -n --arg pad "${PAD}" --rawfile body "${REL}/tmp/body.txt" --argjson n "${_n}" \
    --arg nu "$3" --arg straks "$4" \
    '{
       scenarioName: "run-stream",
       requiredScenarioState: $nu,
       newScenarioState: $straks,
       request: { method: "GET", urlPath: $pad },
       response: {
         status: 200,
         headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-cache" },
         body: $body,
         chunkedDribbleDelay: { numberOfChunks: $n, totalDuration: ($n * 400) }
       }
     }' > "$1"
}

mapping "${UIT}/mappings/run-stream-1-voltooid.json" "${V1}" Started gestopt
mapping "${UIT}/mappings/run-stream-2-gestopt.json"  "${V2}" gestopt midden
mapping "${UIT}/mappings/run-stream-3-midden.json"   "${V3}" midden Started

echo "stap 5: drie mappings in ${REL}/mappings/ — elke verbinding krijgt de volgende situatie"

# --- stap 6: de runs als bestand bij de stamdata ------------------------------------------
#
# Deze drie worden gegenereerd én gecommit, en dat is een uitzondering op "nooit committen
# wat gegenereerd is". De reden staat in docs/besluiten.md; de voorwaarde staat hier.
#
# Zonder deze stap moest de consumer de runs reconstrueren uit dit script, want als bestand
# bestonden ze niet. Er was dus niets om naar te verwijzen en niets om tegen te valideren.
#
# De voorwaarde is `--controleer`: opnieuw genereren en vergelijken, en falen bij verschil.
# Zonder die controle vervalt de uitzondering, want dan is dit gewoon een gekopieerd
# bestand dat stil veroudert.
#
# **Ze stonden tot 2026-08-20 onder contracts/<artifact>/<versie>/runs/.** Dat verwarde
# locatie met eigenaarschap: een fixture moet aan een specversie *voldoen*, hij hoort er niet
# aan toe. Hij is afgeleid van de stamdata, en die beweegt op zijn eigen tempo — met de oude
# plek vroeg elke inhoudswijziging om een contractversie die niets zou betekenen.
#
# Waar hij wél aan moet voldoen, staat daarom in het manifest hiernaast, als gegeven en niet
# als aantekening: ci/toets-stamdata.sh leest die versie, haalt het schema erbij en valideert
# elk bericht. Zonder dat zou een fixture ooit onder een spec schuiven waar hij niet meer aan
# voldoet, en dat zou niemand merken.

RUNS="${CBT_ROOT}/stamdata/runs"
mkdir -p "${RUNS}"

jq -n --arg groep "${GROEP}" --arg artifact "${STREAM}" --arg versie "${STREAM_VERSIE}" \
      --arg scenario "${SCENARIO_ID}" \
  '{
     scenarioId: $scenario,
     gegenereerdTegen: { groep: $groep, artifact: $artifact, versie: $versie }
   }' > "${TMP}/manifest.json"

leg_vast() {
  cut -f2 "$2" > "${TMP}/nieuw.jsonl"
  if [ "${CONTROLEER:-}" = "ja" ]; then
    cmp -s "${TMP}/nieuw.jsonl" "$1" \
      || fout "$(basename "$1") loopt uit de pas met wat de spec nu oplevert.
  Draai ci/generate-stream-stub.sh zonder --controleer en commit het verschil."
  else
    cp "${TMP}/nieuw.jsonl" "$1"
  fi
}

leg_vast "${RUNS}/voltooid.jsonl" "${V1}"
leg_vast "${RUNS}/gestopt.jsonl"  "${V2}"
leg_vast "${RUNS}/midden.jsonl"   "${V3}"

# Het manifest valt onder dezelfde controle. Zou hij er buiten vallen, dan kon de versie
# waartegen gegenereerd is stil verschuiven terwijl de bestanden gelijk bleven — en dan
# valideert de gate straks tegen een spec die er niets mee te maken heeft.
if [ "${CONTROLEER:-}" = "ja" ]; then
  cmp -s "${TMP}/manifest.json" "${RUNS}/manifest.json" \
    || fout "stamdata/runs/manifest.json loopt uit de pas: gegenereerd tegen een andere versie dan wat er staat.
  Draai ci/generate-stream-stub.sh zonder --controleer en commit het verschil."
  echo "stap 6: de drie runbestanden en het manifest komen overeen met wat de spec nu oplevert"
else
  cp "${TMP}/manifest.json" "${RUNS}/manifest.json"
  echo "stap 6: drie runbestanden en een manifest in stamdata/runs/"
fi
