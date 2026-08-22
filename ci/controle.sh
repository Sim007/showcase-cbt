#!/usr/bin/env bash
#
# De controles die bij elke push horen te draaien.
#
#   controle.sh
#
# Dit script bestaat omdat een uitzondering op krediet stond. De drie fixtures in
# contracts/showcase-cbt/run-stream/<versie>/runs/ zijn gegenereerd én gecommit, en dat mocht
# alleen onder de voorwaarde dat er een controle bestaat die ze opnieuw genereert en
# vergelijkt. Die controle bestond, maar draaide nergens automatisch — en een voorwaarde die
# van een handmatige aanroep afhangt, is dezelfde zwakke afspraak die deze showcase over
# grenzen bestrijdt.
#
# Wat deze controle wél aantoont: dat de generator niet is gedrift, dus dat de vastgelegde
# bestanden nog zijn wat de spec oplevert. Wat hij níét aantoont: dat de inhoud klopt. Dat
# is de spec zijn werk, en de schemavalidatie binnen de generator.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "controle: $*" >&2
  exit 1
}

GROEP=showcase-cbt
SCENARIO=scenario-api
STREAM=run-stream

# Twee contracten, twee levenscycli. Ze stonden op één nummer zolang ze toevallig gelijk
# liepen; sinds scenario-api 0.12.0 (het cli-veld geherformuleerd) lopen ze uiteen, en dan is
# één VERSIE geen versimpeling meer maar een onwaarheid.
SCENARIO_VERSIE=0.12.0
STREAM_VERSIE=0.11.0

# De bundel heeft een eigen nummer, en dat is niet netjes maar noodzakelijk: hij is afgeleid
# van twee specs en is gereedschap, geen contract. Een reparatie in de stub die geen enkele
# spec raakt is een patch van de bundel en van niets anders. Stond hier VERSIE, dan zou elke
# stubwijziging om een contractversie vragen — precies wat "drie versies, elk hun eigen
# levenscyclus" ontkent.
BUNDELVERSIE=0.12.0

# De provider heeft een eigen reeks, om dezelfde reden als de bundel: hij is gereedschap en
# geen contract. Wat erin zit staat in zijn manifest.
PROVIDERVERSIE=0.1.0

echo "== controle =="

# --- 1: elke gate declareert wat hij verwachtte ------------------------------------------

"${CBT_ROOT}/ci/controle-gates.sh"

# --- 2: het register omhoog en de specs erin ----------------------------------------------
#
# Zonder register valt er niets te regenereren: de generator leest de spec daar en nooit van
# schijf. Dat is dezelfde regel als in de rest van de opzet.

# Eerst omlaag: op een runner is het register vanzelf leeg, op een laptop niet. Zonder dit
# faalt de publicatie met een 409 op een versie die er al staat, en dat is een fout in de
# controle en niet in wat hij controleert.
docker compose -f "${CBT_ROOT}/compose/registry.yml" down >/dev/null 2>&1 || true
docker compose -f "${CBT_ROOT}/compose/registry.yml" up -d >/dev/null 2>&1
"${CBT_ROOT}/ci/wacht-op-gezond.sh" registry "${CBT_ROOT}/compose/registry.yml" >/dev/null 2>&1 || sleep 12

"${CBT_ROOT}/ci/publish-contract.sh" "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}" \
  "contracts/${GROEP}/${SCENARIO}/${SCENARIO_VERSIE}/openapi.yaml" >/dev/null
"${CBT_ROOT}/ci/publish-contract.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}" \
  "contracts/${GROEP}/${STREAM}/${STREAM_VERSIE}/asyncapi.yaml" >/dev/null

echo "  specs gepubliceerd"

# --- 2b: de ontvangstvariant van run-stream, en het net eronder ----------------------------
#
# Op payloadniveau heeft de AsyncAPI zelf geen compatibiliteitsnet — gemeten, zie
# docs/besluiten.md. De afleiding hieronder registreert de payloads als JSON-artifacts, waar
# de regel wél werkt, en toetst met vier kanaries dat de transformatie niet te gul is.
#
# Bij elke push levert dit één ding op dat altijd waar is: de afleiding klopt nog. Het net
# zelf vuurt pas bij een tweede versie, en die is er in deze run niet.

"${CBT_ROOT}/ci/ontvangstschemas.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}" | sed 's/^/  /'

# --- 3: de fixtures lopen niet uit de pas -------------------------------------------------

"${CBT_ROOT}/ci/generate-stub.sh" "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}" >/dev/null
"${CBT_ROOT}/ci/generate-stream-stub.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}" 01 --controleer >/dev/null

echo "  fixtures komen overeen met de spec"

# --- 4: de tijd loopt binnen elke fixture vooruit ------------------------------------------
#
# De vergelijking hierboven toont aan dat de generator niet is veranderd, niet dat wat hij
# maakt klopt. Volgorde is een eigenschap waar de consumer op steunt — hij bouwt er zijn
# tijdlijn mee op — dus die wordt apart getoetst en niet weggenormaliseerd.

RUNS="${CBT_ROOT}/stamdata/runs"
GECONTROLEERD=0
for fixture in "${RUNS}"/*.jsonl; do
  VORIGE=""
  REGEL=0
  while IFS= read -r bericht; do
    REGEL=$((REGEL + 1))
    HUIDIGE="$(printf '%s' "${bericht}" | sed -n 's/.*"tijd":"\([^"]*\)".*/\1/p')"
    [ -n "${HUIDIGE}" ] || fout "$(basename "${fixture}") regel ${REGEL} heeft geen tijd"
    if [ -n "${VORIGE}" ] && [ "${HUIDIGE}" \< "${VORIGE}" ]; then
      fout "$(basename "${fixture}") regel ${REGEL}: ${HUIDIGE} ligt vóór ${VORIGE}"
    fi
    VORIGE="${HUIDIGE}"
  done < "${fixture}"
  GECONTROLEERD=$((GECONTROLEERD + REGEL))
done

verwacht_minstens "${GECONTROLEERD}" 40 "berichten op oplopende tijd gecontroleerd"
echo "  ${GECONTROLEERD} berichten, tijd loopt overal vooruit"

# --- 5: streng weigert en tolerant accepteert ---------------------------------------------

"${CBT_ROOT}/ci/toets-tolerantie.sh" "${GROEP}" "${STREAM}" "${STREAM_VERSIE}" | sed 's/^/  /'

# --- 5b: de stamdata van de scenario's ------------------------------------------------------
#
# De structuurkant, die altijd kan draaien: elk scenario geldig tegen het Scenario-schema uit
# het register, en scenario 01 is scenario 00 plus de acht stappen die contracttesten
# toevoegen. Die insluiting is de gecontroleerde vergelijking waar de hele showcase op rust;
# staat er geen gate op, dan drift hij terug zodra iemand een pipeline aanpast.
#
# De vergelijking met een écht rapport kan hier niet — daar is een volledige demo voor nodig.
# Die aanroep staat aan het eind van beide demoscripts.

CBT_STAMDATA_VERSIE="${SCENARIO_VERSIE}" "${CBT_ROOT}/ci/toets-stamdata.sh" | sed 's/^/  /'

# --- 6: de stubbundel bouwt nog -----------------------------------------------------------
#
# De bundel is de levering aan de andere squad, en hij is al twee keer gestrand op een
# aanname over gereedschap dat aan de andere kant niet bleek te staan. Dat hij hier op een
# schone runner nog bouwt, vangt precies die soort drift — en dit is de enige plek waar dat
# automatisch gebeurt.

"${CBT_ROOT}/ci/bouw-stubbundel.sh" "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}" "${STREAM}" "${STREAM_VERSIE}" "${BUNDELVERSIE}" \
  >/dev/null || fout "de stubbundel bouwt niet meer"

echo "  stubbundel gebouwd"

# Bouwen is niet hetzelfde als werken. Deze toets start hem en leest zijn stream, begrensd op
# een aantal berichten en op tijd — want een toets die hangt meldt niets, ook geen rood.
"${CBT_ROOT}/ci/toets-stubbundel.sh" "${BUNDELVERSIE}" | sed 's/^/  /'

# --- 6c: de provider bouwt nog --------------------------------------------------------------
#
# Dezelfde reden als bij de bundel: bouwen is de goedkoopste manier om te merken dat er iets
# is weggedreven. De image draagt de stamdata, dus dit vangt ook een scenario dat niet meer
# in de image past.

"${CBT_ROOT}/ci/bouw-provider.sh" "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}" \
  "${STREAM}" "${STREAM_VERSIE}" "${PROVIDERVERSIE}" >/dev/null \
  || fout "de provider bouwt niet meer"

echo "  provider gebouwd"

# --- 6b: de release-assets zijn te bouwen -------------------------------------------------
#
# Publiceren kan hier niet — dat vraagt een tag en een token. Bouwen wél, want de asset komt
# uit het werkregister en dat staat op dit moment omhoog. Daarmee is bij elke push aangetoond
# dat de weg naar een release begaanbaar is, inclusief de controle dat het manifest van de
# bundel klopt met wat de gates hebben gezien.

"${CBT_ROOT}/ci/bouw-release.sh" spec "${GROEP}" "${SCENARIO}" "${SCENARIO_VERSIE}" >/dev/null
"${CBT_ROOT}/ci/bouw-release.sh" spec "${GROEP}" "${STREAM}" "${STREAM_VERSIE}" >/dev/null
"${CBT_ROOT}/ci/bouw-release.sh" bundel "${BUNDELVERSIE}" >/dev/null

echo "  release-assets gebouwd en tegen het werkregister gehouden"

docker compose -f "${CBT_ROOT}/compose/registry.yml" down >/dev/null 2>&1 || true

# --- 7: de aftrekking van scenario 0 en 1 ------------------------------------------------
#
# vergelijk-rapporten.sh draagt de bewering waar scenario 0 en 1 samen op rusten, en werd
# tot nu toe alleen door de demo van scenario 1 aangeroepen. Die draait niet in CI, en
# daardoor bleef een exitcode 127 in dat script maanden onzichtbaar.
#
# De invoer zijn twee fixtures en geen echte rapporten: die staan in <scenario>/rapport/,
# horen bij een run, en zijn er op een runner dus niet. Zie docs/besluiten.md.

"${CBT_ROOT}/ci/vergelijk-rapporten.sh" \
  "${CBT_ROOT}/ci/fixtures/rapport-zonder-cbt.md" \
  "${CBT_ROOT}/ci/fixtures/rapport-met-cbt.md" | sed 's/^/  /'

# Waaraan te zien is dat de fixtures verouderd zijn: ze zijn met de hand uitgerekend, dus
# een wijziging in het rapportformaat laat ze stil achter. Daarom schrijft tools.sh hier één
# vers rapport en wordt de kop ernaast gelegd. Wijkt die af, dan lijken de fixtures niet meer
# op wat een pipeline oplevert, en toont de vergelijking niets meer over de echte rapporten.
KOP='^| Tijd | Onderdeel | Stap | Uitkomst | Bijzonderheden |$'
VERSMAP="$(mktemp -d)"
CBT_RAPPORT="${VERSMAP}/rapport-cbt-99.md" rapport_start "controle"
grep -q "${KOP}" "${VERSMAP}/rapport-cbt-99.md" \
  || fout "tools.sh schrijft een andere rapportkop dan deze controle verwacht"
rm -rf "${VERSMAP}"

ACTUEEL=0
for fixture in "${CBT_ROOT}"/ci/fixtures/rapport-*.md; do
  grep -q "${KOP}" "${fixture}" \
    || fout "$(basename "${fixture}") heeft niet meer de kop die tools.sh schrijft; de fixture is verouderd"
  ACTUEEL=$((ACTUEEL + 1))
done
verwacht_minstens "${ACTUEEL}" 2 "fixtures met een actuele rapportkop"

echo "  fixtures hebben nog de kop die tools.sh schrijft"

echo "== controle: groen =="
