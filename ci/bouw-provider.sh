#!/usr/bin/env bash
#
# Bouwt de image van de provider.
#
#   bouw-provider.sh <groep> <scenario-artifact> <scenario-versie> <stream-artifact> <stream-versie> <providerversie>
#
# De tegenhanger van bouw-stubbundel.sh, voor onze eigen kant van dezelfde twee grenzen. De
# stub blijft bestaan om tegen te bouwen; deze serveert wat er werkelijk draait.
#
# **Wat waar vandaan komt.** De stamdata gaat in de image, want ze is inhoud van de showcase
# en hoort bij een versie. Wat uit het contract komt — de toegestane origin, het foutantwoord
# voor een onbekend scenario — komt uit het register en niet van schijf, zoals overal.
#
# **De versie is die van het gereedschap.** De provider draagt een eigen `0.x.y`, los van de
# contractversies en los van elke deelsysteemversie; welke specs en welke stamdata erin
# zitten staat in het manifest. Zie het versiehoofdstuk in docs/showcase-cbt.md.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "bouw-provider: $*" >&2
  exit 1
}

[ "$#" -eq 6 ] || fout "gebruik: bouw-provider.sh <groep> <scenario-artifact> <scenario-versie> <stream-artifact> <stream-versie> <providerversie>"

GROEP="$1"
SCENARIO="$2"
SCENARIO_VERSIE="$3"
STREAM="$4"
STREAM_VERSIE="$5"
VERSIE="$6"

BOUW="${CBT_ROOT}/build/provider"
REL="build/provider"
rm -rf "${BOUW}"
mkdir -p "${BOUW}/scenarios" "${BOUW}/tmp"

# --- stap 1: de specs uit het register ----------------------------------------------------

SCENARIO_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}")"
STREAM_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}")"

yq -o=json '.' "${SCENARIO_SPEC#"${CBT_ROOT}/"}" > "${BOUW}/tmp/scenario.json"

echo "stap 1: ${SCENARIO} ${SCENARIO_VERSIE} en ${STREAM} ${STREAM_VERSIE} opgehaald"

# --- stap 2: wat uit het contract komt ----------------------------------------------------
#
# De origin en het foutantwoord staan in de spec en niet in de provider. Een stub die
# permissiever is dan wat hij nabootst verbergt fouten; voor de echte kant geldt dat des te
# meer, want daar is niets om achteraf mee te vergelijken.

jq '{
      origin: (.components.headers.AccessControlAllowOrigin.schema.example // "*"),
      fouten: {
        scenarioOnbekend: (.paths."/v1/scenarios/{scenarioId}".get.responses."404".content."application/json".example
                           // error("geen 404-example op haalScenario"))
      }
    }' "${REL}/tmp/scenario.json" > "${BOUW}/provider-data.json"

echo "stap 2: origin $(jq -r '.origin' "${REL}/provider-data.json"), foutantwoord uit de spec"

# --- stap 3: de stamdata mee in de image ---------------------------------------------------

ls "${CBT_ROOT}/stamdata/scenarios"/*.json >/dev/null 2>&1 \
  || fout "geen stamdata in stamdata/scenarios"
cp "${CBT_ROOT}/stamdata/scenarios"/*.json "${BOUW}/scenarios/"

AANTAL="$(ls "${BOUW}/scenarios" | wc -l | tr -d ' ')"
verwacht_minstens "${AANTAL}" 1 "scenario's in de image"
echo "stap 3: ${AANTAL} scenario's: $(ls "${BOUW}/scenarios" | sed 's/\.json$//' | tr '\n' ' ')"

# --- stap 4: het manifest -------------------------------------------------------------------
#
# De versie zegt wat voor gereedschap dit is; het manifest zegt wat erin zit. Zonder dit
# betekent `provider-0.1.0` niet welke specs en welke stamdata er meegingen — dezelfde
# dubbelzinnigheid die één gedeeld versienummer bij de bundel opleverde.

SCENARIO_SOM="$(sha256som "${REL}/tmp" scenario.json | cut -d' ' -f1)"

jq -n --arg versie "${VERSIE}" --arg groep "${GROEP}" \
      --arg scenario "${SCENARIO}" --arg sversie "${SCENARIO_VERSIE}" --arg ssom "${SCENARIO_SOM}" \
      --arg stream "${STREAM}" --arg tversie "${STREAM_VERSIE}" \
      --argjson scenarios "$(ls "${BOUW}/scenarios" | sed 's/\.json$//' | jq -R . | jq -s .)" \
  '{
     providerversie: $versie,
     groep: $groep,
     specs: [
       { artifact: $scenario, versie: $sversie, sha256: $ssom },
       { artifact: $stream,   versie: $tversie }
     ],
     scenarios: $scenarios,
     ontbreekt: ["POST /v1/runs — zie O22"]
   }' > "${BOUW}/manifest.json"

echo "stap 4: manifest met ${SCENARIO} ${SCENARIO_VERSIE} en ${STREAM} ${STREAM_VERSIE}"

# --- stap 5: de image ------------------------------------------------------------------------

cp "${CBT_ROOT}/ci/provider/server.js" "${CBT_ROOT}/ci/provider/Dockerfile" "${BOUW}/"

docker build -q -t "cbt/provider:${VERSIE}" "${BOUW}" >/dev/null \
  || fout "de image bouwt niet"

echo "stap 5: cbt/provider:${VERSIE} gebouwd"
