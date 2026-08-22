#!/usr/bin/env bash
#
# Bouwt de stubbundel voor showcase-website: uitpakken, starten, klaar.
#
#   bouw-stubbundel.sh <groep> <scenario-artifact> <scenario-versie> \
#                      <stream-artifact> <stream-versie> <bundelversie>
#
# Drie versies en niet één. De twee specs zijn twee contracten met twee eigen
# levenscycli: één nummer voor allebei betekent dat de eerste wijziging van alleen
# `run-stream` de ander een versie geeft die niets betekent. De bundel heeft daarnaast een
# eigen nummer, want hij is afgeleid van beide en is gereedschap en geen contract.
#
# De consumer heeft Node en verder niets: geen Docker, geen JDK, en geen betrouwbaar pad
# naar de npm-registry — `npx @stoplight/prism-cli` bleef daar hangen. De bundel bevat
# daarom zijn eigen afhankelijkheden. Na het uitpakken is er geen netwerk meer nodig.
#
# Dat is de tweede keer dat een aanname over gereedschap de levering blokkeerde: eerst
# Docker, toen npx. Wat je meelevert is onderdeel van de afspraak, ook als het niet in de
# spec staat.
#
# Alles in de bundel komt uit de gepubliceerde specs. De WireMock-stub voor ons eigen
# gebruik blijft bestaan; deze vervangt hem niet.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "bouw-stubbundel: $*" >&2
  exit 1
}

[ "$#" -eq 6 ] || fout "gebruik: bouw-stubbundel.sh <groep> <scenario-artifact> <scenario-versie> <stream-artifact> <stream-versie> <bundelversie>"

GROEP="$1"
SCENARIO="$2"
SCENARIO_VERSIE="$3"
STREAM="$4"
STREAM_VERSIE="$5"
BUNDELVERSIE="$6"

BUNDEL="${CBT_ROOT}/build/bundel"
REL="build/bundel"
rm -rf "${BUNDEL}"
mkdir -p "${BUNDEL}/runs" "${BUNDEL}/schemas" "${BUNDEL}/tmp"

# --- stap 1: de specs uit het register --------------------------------------------------

SCENARIO_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}")"
STREAM_SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}")"

yq -o=json '.' "${SCENARIO_SPEC#"${CBT_ROOT}/"}" > "${BUNDEL}/tmp/scenario.json"
yq -o=json '.' "${STREAM_SPEC#"${CBT_ROOT}/"}"   > "${BUNDEL}/tmp/stream.json"

cp "${SCENARIO_SPEC}" "${BUNDEL}/openapi.yaml"
cp "${STREAM_SPEC}"   "${BUNDEL}/asyncapi.yaml"

echo "stap 1: ${SCENARIO} ${SCENARIO_VERSIE} en ${STREAM} ${STREAM_VERSIE} opgehaald uit het register"

# --- stap 2: de routes, met hun requestschema -------------------------------------------
#
# Wat de stub serveert komt hier vandaan en nergens anders. De body is de example uit de
# spec; het requestschema is dat van de spec, zodat de stub weigert wat de echte kant ook
# zou weigeren.

STREAMPAD="$(jq -r '.channels | keys | .[0]' "${REL}/tmp/stream.json")"

jq --arg streampad "${STREAMPAD}" '
  . as $doc
  | {
      streampad: $streampad,
      origin: ($doc.components.headers.AccessControlAllowOrigin.schema.example // "*"),
      componenten: { components: $doc.components },
      routes: [
        .paths | to_entries[] as $pad
        | $pad.value | to_entries[] as $methode
        | select($methode.key | IN("get","post","put","patch","delete","options"))
        | ($methode.value.responses | to_entries
            | map(select(.key | test("^2"))) | sort_by(.key) | first) as $ok
        | {
            methode: ($methode.key | ascii_upcase),
            patroon: ("^" + ($pad.key | gsub("\\{[^}]+\\}"; "[^/]+")) + "$"),
            status: ($ok.key | tonumber),
            # De operationId, zodat de stub een route kan herkennen zonder een pad hard te
            # hebben staan. `startRun` is het enige verzoek dat bij hem iets in beweging
            # zet — de stream roteert erop — en die naam komt uit de spec.
            operationId: $methode.value.operationId,
            # De foutantwoorden met hun example. Nodig sinds de stub toestand heeft: hij kan
            # een tweede start weigeren zoals de spec voorschrijft, en dan moet het antwoord
            # uit de spec komen en niet uit de stub.
            fouten: (($methode.value.responses // {}) | to_entries
              | map(select((.key | test("^2")) | not))
              | map(select(.value.content."application/json".example != null))
              | map({ key: .key, value: .value.content."application/json".example })
              | from_entries),
            kopteksten: (
              (if $ok.value.content then { "Content-Type": "application/json" } else {} end)
              + (($ok.value.headers // {}) | to_entries | map({
                  key: .key,
                  value: ((if .value["$ref"]
                           then $doc.components.headers[.value["$ref"] | sub("^#/components/headers/"; "")]
                           else .value end)
                          | (.schema.example // (.schema.enum // [])[0] // ""))
                }) | from_entries)
            ),
            body: ($ok.value.content."application/json".example // null),
            verzoekSchema: ($methode.value.requestBody.content."application/json".schema // null)
          }
      ]
    }' "${REL}/tmp/scenario.json" > "${BUNDEL}/stub-data.json"

# --- stap 2b: de scenario's uit de stamdata ------------------------------------------------
#
# De twee scenario-routes kregen hun body uit het example van de spec, en één example is één
# body: de stub antwoordde met scenario 01 op elke scenarioId. showcase-website toonde daardoor
# de stappen van 01 onder de kop van 00 — en juist het verschil tussen die twee is wat deze
# showcase te vertellen heeft.
#
# Een example is illustratie en stamdata is inhoud. De spec houdt zijn example; wat de stub
# serveert komt hiervandaan. Dat het geen verzonnen materiaal is, bewaakt ci/toets-stamdata.sh:
# elk scenario wordt tegen het Scenario-schema uit het register gehouden.

STAMDATA_REL="stamdata/scenarios"
ls "${CBT_ROOT}/${STAMDATA_REL}"/*.json >/dev/null 2>&1 \
  || fout "geen stamdata in ${STAMDATA_REL}. Zonder scenario's valt er niets te serveren"

jq -s 'map({id, titel, ondertitel})' "${STAMDATA_REL}"/*.json > "${BUNDEL}/tmp/lijst.json"
jq -s 'map({key: .id, value: .}) | from_entries' "${STAMDATA_REL}"/*.json > "${BUNDEL}/tmp/per-id.json"

jq -s '
  .[0] as $stub | .[1] as $lijst | .[2] as $perId
  | $stub
  | .routes = [
      .routes[]
      | if .operationId == "lijstScenarios" then .body = $lijst
        elif .operationId == "haalScenario" then (.bodyPerId = $perId | .body = null)
        else . end
    ]' "${REL}/stub-data.json" "${REL}/tmp/lijst.json" "${REL}/tmp/per-id.json" \
  > "${BUNDEL}/tmp/stub-data.json"
mv "${BUNDEL}/tmp/stub-data.json" "${BUNDEL}/stub-data.json"

SCENARIOS="$(jq -r '.routes[] | select(.operationId == "haalScenario") | .bodyPerId | keys | join(", ")' "${REL}/stub-data.json")"
[ -n "${SCENARIOS}" ] || fout "de scenario-route kreeg geen enkele body uit de stamdata"
echo "stap 2b: scenario's uit de stamdata: ${SCENARIOS}"

ROUTES="$(jq -r '.routes | length' "${REL}/stub-data.json")"
[ "${ROUTES}" -gt 0 ] || fout "geen routes uit de spec gehaald"
echo "stap 2: ${ROUTES} routes, waarvan $(jq -r '[.routes[] | select(.verzoekSchema)] | length' "${REL}/stub-data.json") met een requestschema"

# --- stap 3: de fixtures ----------------------------------------------------------

RUNS="${CBT_ROOT}/stamdata/runs"
[ -d "${RUNS}" ] || fout "geen runs in ${RUNS}. Draai eerst ci/generate-stream-stub.sh"

# De opnames zijn afgeleid van de stamdata en moeten voldoen aan een specversie; ze horen er
# niet aan toe. Waar ze aan moeten voldoen staat in hun manifest, en dat hoort te kloppen met
# de versie die in deze bundel gaat — anders levert de bundel materiaal van een andere spec
# dan het contract dat ernaast zit.
MANIFEST_VERSIE="$(jq -r '.gegenereerdTegen.versie' < "${RUNS}/manifest.json")"
[ "${MANIFEST_VERSIE}" = "${STREAM_VERSIE}" ] \
  || fout "de opnames zijn gegenereerd tegen ${STREAM} ${MANIFEST_VERSIE}, deze bundel draagt ${STREAM_VERSIE}"
cp "${RUNS}"/*.jsonl "${BUNDEL}/runs/"
echo "stap 3: $(ls "${BUNDEL}/runs" | wc -l | tr -d ' ') fixtures"

# --- stap 3b: de opgenomen runs en de stamdata --------------------------------------------
#
# Twee soorten materiaal in dezelfde map, en het verschil is de herkomst. `voltooid.jsonl`,
# `gestopt.jsonl` en `midden.jsonl` zijn afgeleid uit de stamdata van scenario 01 — een
# nabootsing die klopt. `<id>-voltooid.jsonl` is een échte run: opgenomen terwijl de pipeline
# draaide, met de duren die het werkelijk kostte.
#
# **De stamdata gaat mee in dezelfde release, en dat is geen gemak maar een voorwaarde.** De
# stream draagt alleen `stapNummer` en `uitkomst`; wat een stap ís staat in de stamdata. Een
# opname van 19 stappen zonder de stamdata van 00 toont niets, en een stapnummer dat er niet
# in staat verdwijnt zonder melding. Los uitgeven zou betekenen dat de twee helften uit de
# pas kunnen lopen zonder dat iemand het merkt.

OPNAMES="${CBT_ROOT}/stamdata/opnames"
mkdir -p "${BUNDEL}/scenarios"
cp "${CBT_ROOT}/stamdata/scenarios"/*.json "${BUNDEL}/scenarios/"

# In een variabele en niet in tmp/: die map wordt in stap 5 opgeruimd, en het manifest wordt
# daarna pas geschreven.
OPNAMES_JSON='[]'
AANTAL_OPNAMES=0
if [ -d "${OPNAMES}" ]; then
  for opname in "${OPNAMES}"/*.jsonl; do
    [ -f "${opname}" ] || continue
    id="$(basename "${opname}" .jsonl)"
    bron="${OPNAMES}/${id}.manifest.json"
    # Relatief, want jq draait in een container met de repo op /work en kent dit hostpad niet.
    bron_rel="stamdata/opnames/${id}.manifest.json"
    [ -f "${bron}" ] || fout "opname ${id} heeft geen manifest; draai ci/neem-op.sh opnieuw"

    tegen="$(jq -r '.voldoetAan.versie' < "${bron}")"
    [ "${tegen}" = "${STREAM_VERSIE}" ] \
      || fout "opname ${id} is opgenomen tegen ${STREAM} ${tegen}, deze bundel draagt ${STREAM_VERSIE}"

    bestand="${id}-voltooid.jsonl"
    cp "${opname}" "${BUNDEL}/runs/${bestand}"
    som="$(sha256som "${REL}/runs" "${bestand}" | cut -d' ' -f1)"

    OPNAMES_JSON="$(jq -c -n \
       --argjson huidig "${OPNAMES_JSON}" \
       --arg bestand "runs/${bestand}" --arg som "${som}" --arg tegen "${tegen}" \
       --argjson stappen "$(jq '.stappen | length' < "${CBT_ROOT}/stamdata/scenarios/${id}.json")" \
       --slurpfile m "${bron_rel}" \
      '$huidig + [ { scenarioId: $m[0].scenarioId, runId: $m[0].runId, stappen: $stappen,
                     berichten: $m[0].berichten, opgenomenTegen: $tegen,
                     bestand: $bestand, sha256: $som } ]')"
    AANTAL_OPNAMES=$((AANTAL_OPNAMES + 1))
  done
fi

echo "stap 3b: $(ls "${BUNDEL}/scenarios" | wc -l | tr -d ' ') scenario's en ${AANTAL_OPNAMES} opgenomen run(s)"

# --- stap 4: het ontvangstschema ---------------------------------------------------------
#
# De replayer toetst niets. Dit schema is er zodat de consumer de berichten in zijn eigen
# testsuite wél kan valideren — met ajv, die toch al in de bundel zit.
#
# Nadrukkelijk niet de gepubliceerde schema's zelf. Die staan streng: additionalProperties
# op false en enums met vaste waarden. Dat is een ware uitspraak over wat wij versturen en
# een nuttige controle aan ónze kant, maar aan de ontvangende kant maakt hij elke additieve
# wijziging brekend — en dat is precies wat scenario 02 niet-brekend noemt.
#
# Er gaat er dus maar één mee, en dat is deze. Twee schemasets naast elkaar zou betekenen
# dat er nog steeds een verkeerde te pakken valt; dan is de val verplaatst en niet weg.
#
# Wat eruit gaat en waarom, in de volgorde van de drie tolerantie-eisen:
#   additionalProperties  een onbekend veld mag geen fout zijn
#   enum op Soort         een onbekend berichttype mag geen fout zijn
#   enum op de rest       een onbekende waarde in een bekend veld mag geen fout zijn
#
# Wat overblijft toetst de vorm en niet de woordenschat. Zie de README van de bundel.

jq '{ components: { schemas: (.components.schemas
       | walk(if type == "object" then del(.additionalProperties, .enum) else . end)) } }' \
  "${REL}/tmp/stream.json" > "${BUNDEL}/tmp/ontvangst.json"

# De index: van de waarde die in het bericht staat naar het schema dat erbij hoort. Zonder
# dit moet de consumer zelf een switch bijhouden, en die vergeet hij bij te werken zodra er
# een berichtsoort bij komt — terwijl "onbekend type overslaan" juist een opzoeking hoort te
# zijn die vanzelf goed gaat.
jq '.components.messages
    | to_entries
    | map({ key: .value.name, value: (.value.payload["$ref"] | split("/") | last) })
    | from_entries' "${REL}/tmp/stream.json" > "${BUNDEL}/tmp/index.json"

jq --slurpfile idx "${REL}/tmp/index.json" '. + { soortIndex: $idx[0] }' \
  "${REL}/tmp/ontvangst.json" > "${BUNDEL}/schemas/berichten-ontvangst.json"

AANTAL_SCHEMAS="$(jq -r '.components.schemas | keys | length' "${REL}/schemas/berichten-ontvangst.json")"
verwacht_minstens "${AANTAL_SCHEMAS}" 6 "berichtschema's in het ontvangstschema"
echo "stap 4: ${AANTAL_SCHEMAS} berichtschema's als ontvangstvariant, met een index op soort"

# --- stap 5: de afhankelijkheden mee ------------------------------------------------------

docker run --rm --user "$(id -u):$(id -g)" \
  --volume "${BUNDEL}:/b" --workdir /b --env HOME=/b \
  "$NODE_IMAGE" npm install --no-fund --no-audit --omit=dev --silent \
  "ajv@${AJV_VERSIE_BUNDEL}" "ajv-formats@${AJV_FORMATS_VERSIE}" 2>&1 | tail -2

cp "${CBT_ROOT}/ci/stubbundel/stub.js" "${BUNDEL}/stub.js"
cp "${CBT_ROOT}/ci/stubbundel/README.md" "${BUNDEL}/README.md"
rm -rf "${BUNDEL}/tmp" "${BUNDEL}/.npm"

echo "stap 5: afhankelijkheden meegepakt ($(du -sh "${BUNDEL}/node_modules" | cut -f1))"

# --- stap 6: het manifest ------------------------------------------------------------------
#
# De bundel is afgeleid van twee specs die vanaf nu los bewegen. Zonder manifest zegt
# `stubbundel-0.10.0` niet wélke versies erin zitten — precies de dubbelzinnigheid die één
# gedeeld versienummer opleverde, één niveau lager terug.
#
# De checksums zijn er niet voor ons maar voor de consumer: daarmee stelt hij vast dat deze
# bundel hoort bij de spec die hij zelf uit de release heeft gehaald. Dat is een gate aan
# zijn kant, zonder dat hij ons gereedschap krijgt.
#
# Als laatste vóór het inpakken, zodat hij de bundel beschrijft zoals die de deur uit gaat.

SCENARIO_SOM="$(sha256som "${REL}" openapi.yaml | cut -d' ' -f1)"
STREAM_SOM="$(sha256som "${REL}" asyncapi.yaml | cut -d' ' -f1)"

jq -n \
  --arg bundelversie "${BUNDELVERSIE}" \
  --arg groep "${GROEP}" \
  --arg scenario "${SCENARIO}" --arg scenarioversie "${SCENARIO_VERSIE}" --arg scenariosom "${SCENARIO_SOM}" \
  --arg stream "${STREAM}" --arg streamversie "${STREAM_VERSIE}" --arg streamsom "${STREAM_SOM}" \
  --argjson opnames "${OPNAMES_JSON}" \
  '{
     bundelversie: $bundelversie,
     groep: $groep,
     specs: [
       { artifact: $scenario, versie: $scenarioversie, bestand: "openapi.yaml",  sha256: $scenariosom },
       { artifact: $stream,   versie: $streamversie,   bestand: "asyncapi.yaml", sha256: $streamsom }
     ],
     opnames: $opnames
   }' > "${BUNDEL}/manifest.json"

verwacht_minstens "$(jq -r '.specs | length' "${REL}/manifest.json")" 2 "specs in het manifest"
echo "stap 6: manifest met ${SCENARIO} ${SCENARIO_VERSIE} en ${STREAM} ${STREAM_VERSIE}"

# --- stap 7: inpakken ---------------------------------------------------------------------

UIT="${CBT_ROOT}/build/stubbundel-${BUNDELVERSIE}.tgz"
tar -czf "${UIT}" -C "${CBT_ROOT}/build" bundel
echo "stap 7: ${UIT#"${CBT_ROOT}/"} ($(du -h "${UIT}" | cut -f1))"
