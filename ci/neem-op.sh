#!/usr/bin/env bash
#
# Maakt van de gebeurtenissen van een échte run een opname in `run-stream`-vorm.
#
#   neem-op.sh <scenario-id> [gebeurtenissenbestand]
#
# **De opname is de run.** Tot nu werden de verlopen afgeleid uit de stamdata — een
# nabootsing die klopte maar niets bewees. Wat hier binnenkomt is wat er werkelijk gebeurd
# is: dezelfde stappen, dezelfde volgorde, de echte duren. De opgeslagen modus van
# showcase-website is daarmee geen imitatie meer maar een run die je terugspeelt.
#
# **Waarom er een omzetting tussen zit.** `stap()` schrijft kale gebeurtenissen: omschrijving
# en uitkomst, meer niet. Geen `runId`, geen `stapNummer`, geen contractvorm — anders reikt
# een wijziging aan `run-stream` tot in de pipeline. Hier gebeurt de vertaling, op één plek,
# met de stamdata ernaast om de nummers te vinden.
#
# **Het runId is afgeleid en niet toevallig.** Een opname wordt gecommit, en een nummer dat
# bij elke opnieuw-opname verandert maakt van elke heropname een wijziging. `run-0000<id>`
# is stabiel, voldoet aan het patroon uit de spec, en is niet te verwarren met de
# gegenereerde fixtures.
#
# **Bekende grens: twee opnames van hetzelfde scenario dragen hetzelfde nummer.** Vandaag is
# er één opname per scenario, dus het speelt niet. Zodra er een gestopte opname van 00 naast
# de voltooide komt, is dit precies het lek dat squad 2 heeft aangetoond: hun reducer slaat
# het wissen over bij een gelijk `runId` — juist, om een race met de 201 te overleven — en
# dan komen cli-regels van de ene opname onder de stappen van de andere terecht. Gemeten:
# met hetzelfde nummer lekken er twee regels, met eigen nummers nul.
#
# Wie hier een tweede opname per scenario toevoegt, moet dus eerst het nummer uitbreiden —
# bijvoorbeeld met een letter per verloop — en niet pas als het lekt.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "neem-op: $*" >&2
  exit 1
}

[ "$#" -ge 1 ] || fout "gebruik: neem-op.sh <scenario-id> [gebeurtenissenbestand]"

ID="$1"
case "${ID}" in
  [0-9][0-9]) ;;
  *) fout "'${ID}' is geen scenario-id; de spec zegt twee cijfers" ;;
esac

STAMDATA="${CBT_ROOT}/stamdata/scenarios/${ID}.json"
[ -f "${STAMDATA}" ] || fout "geen stamdata op stamdata/scenarios/${ID}.json"

case "${ID}" in
  00) STANDAARD="${CBT_ROOT}/00-start/rapport/gebeurtenissen.jsonl" ;;
  01) STANDAARD="${CBT_ROOT}/01-basis/rapport/gebeurtenissen.jsonl" ;;
  *)  STANDAARD="" ;;
esac
BRON="${2:-${STANDAARD}}"
[ -n "${BRON}" ] && [ -f "${BRON}" ] \
  || fout "geen gebeurtenissen op ${BRON:-<onbekend>}. Draai eerst de demo van scenario ${ID}"

UIT_MAP="${CBT_ROOT}/stamdata/opnames"
mkdir -p "${UIT_MAP}"
WERK="${CBT_ROOT}/build/opname"
WERK_REL="build/opname"
rm -rf "${WERK}"; mkdir -p "${WERK}"

cp "${BRON}" "${WERK}/gebeurtenissen.jsonl"
cp "${STAMDATA}" "${WERK}/scenario.json"

RUN_ID="run-0000${ID}"

# --- de omzetting, in één jq-aanroep -------------------------------------------------------
#
# Eén aanroep en niet één per bericht: jq draait hier in een container, en per regel zou dat
# een seconde kosten. Dezelfde reden als bij de validatie in generate-stream-stub.sh.
#
# De stappen worden op volgorde gelopen en op omschrijving gematcht. Wijkt een omschrijving
# af van wat de stamdata op die plek verwacht, dan draaide de pipeline iets anders dan
# beloofd — en dat hoort te stoppen, niet weggenummerd te worden.

jq -c -n --slurpfile stam "${WERK_REL}/scenario.json" \
        --slurpfile ev "${WERK_REL}/gebeurtenissen.jsonl" \
        --arg runid "${RUN_ID}" --arg sid "${ID}" '
  ($stam[0].stappen) as $stappen
  | reduce $ev[] as $g ({ i: 0, huidig: null, uit: [] };
      if $g.soort == "run-gestart" then
        .uit += [ { soort: "momentopname", tijd: $g.tijd, run: null, afgerondeStappen: [] },
                  { soort: "run-gestart", tijd: $g.tijd, runId: $runid, scenarioId: $sid } ]
      elif $g.soort == "stap-gestart" then
        ( [ $stappen[] | select(.omschrijving == $g.omschrijving) ] ) as $kandidaten
        | ( [ range(.i; ($stappen | length)) | select($stappen[.].omschrijving == $g.omschrijving) ] | first ) as $k
        | if $k == null then
            error("stap \"" + $g.omschrijving + "\" staat niet (meer) in de stamdata van scenario " + $sid)
          else
            .huidig = $stappen[$k]
            | .i = ($k + 1)
            | .uit += [ { soort: "stap-gestart", tijd: $g.tijd, runId: $runid, stapNummer: $stappen[$k].nummer },
                        { soort: "cli-uitvoer", tijd: $g.tijd, runId: $runid,
                          stapNummer: $stappen[$k].nummer, regel: ("$ " + $stappen[$k].cli) } ]
          end
      elif $g.soort == "uitvoer" then
        .uit += [ { soort: "cli-uitvoer", tijd: $g.tijd, runId: $runid,
                    stapNummer: .huidig.nummer, regel: $g.regel } ]
      elif $g.soort == "stap-afgerond" then
        .uit += [ { soort: "stap-afgerond", tijd: $g.tijd, runId: $runid,
                    stapNummer: .huidig.nummer, uitkomst: $g.uitkomst } ]
      elif $g.soort == "run-afgerond" then
        .uit += [ ( { soort: "run-afgerond", tijd: $g.tijd, runId: $runid, reden: $g.reden }
                    + (if $g.reden == "gestopt" then { gestoptBijStap: .huidig.nummer } else {} end) ) ]
      else . end)
  | .uit[]' > "${WERK}/opname.jsonl" \
  || fout "de gebeurtenissen zijn niet op de stamdata te leggen"

BERICHTEN="$(wc -l < "${WERK}/opname.jsonl" | tr -d ' ')"
verwacht_minstens "${BERICHTEN}" 3 "berichten in de opname van scenario ${ID}"

# --- elk bericht tegen zijn schema ---------------------------------------------------------
#
# Een opname van een echte run is niet reproduceerbaar: tijden en duren verschillen per keer.
# Daarmee vervalt `--controleer` als waarborg — opnieuw genereren en byte voor byte
# vergelijken kan hier niet. Wat ervoor in de plaats komt is deze validatie plus de
# stapvolgorde hierboven: elk bericht voldoet aan de gepubliceerde spec, en de stappen zijn
# die van de stamdata. Zonder die twee zou een gecommitte opname een bestand zijn waar niets
# meer over te zeggen valt.

VERSIE="${CBT_OPNAME_STREAMVERSIE:-0.11.0}"
SPEC="$("${CBT_ROOT}/ci/get-contract.sh" showcase-cbt run-stream "${VERSIE}")"
yq -o=json '.' "${SPEC#"${CBT_ROOT}/"}" > "${WERK}/stream.json"
jq '{ components: { schemas: .components.schemas } }' "${WERK_REL}/stream.json" > "${WERK}/componenten.json"
jq '.components.messages | to_entries
    | map({ key: .value.name, value: (.value.payload["$ref"] | split("/") | last) })
    | from_entries' "${WERK_REL}/stream.json" > "${WERK}/index.json"

GESPLITST=0
while IFS= read -r bericht; do
  soort="$(printf '%s' "${bericht}" | sed -n 's/.*"soort":"\([^"]*\)".*/\1/p')"
  schema="$(jq -r --arg s "${soort}" '.[$s] // empty' < "${WERK}/index.json")"
  [ -n "${schema}" ] || fout "soort '${soort}' bestaat niet in run-stream ${VERSIE}"
  mkdir -p "${WERK}/per-soort/${schema}"
  printf '%s' "${bericht}" > "${WERK}/per-soort/${schema}/${GESPLITST}.json"
  GESPLITST=$((GESPLITST + 1))
done < "${WERK}/opname.jsonl"

for map in "${WERK}"/per-soort/*/; do
  schema="$(basename "${map}")"
  jq --arg ref "#/components/schemas/${schema}" '. + {"$ref": $ref}' \
    "${WERK_REL}/componenten.json" > "${WERK}/schema-${schema}.json"
  ajv validate --strict=false -c ajv-formats \
    -s "${WERK_REL}/schema-${schema}.json" \
    -d "${WERK_REL}/per-soort/${schema}/*.json" >/dev/null 2>&1 \
    || fout "berichten van soort ${schema} voldoen niet aan run-stream ${VERSIE}"
done

cp "${WERK}/opname.jsonl" "${UIT_MAP}/${ID}.jsonl"

jq -n --arg sid "${ID}" --arg runid "${RUN_ID}" --arg versie "${VERSIE}" \
      --arg opgenomen "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --argjson berichten "${BERICHTEN}" \
  '{ scenarioId: $sid, runId: $runid, berichten: $berichten, opgenomenOp: $opgenomen,
     voldoetAan: { groep: "showcase-cbt", artifact: "run-stream", versie: $versie } }' \
  > "${UIT_MAP}/${ID}.manifest.json"

rm -rf "${WERK}"
echo "neem-op: scenario ${ID} opgenomen — ${BERICHTEN} berichten in stamdata/opnames/${ID}.jsonl, geldig tegen run-stream ${VERSIE}"
