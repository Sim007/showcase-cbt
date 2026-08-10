#!/usr/bin/env bash
#
# Toont aan dat de twee schema's doen wat ze horen te doen, elk in één richting.
#
#   toets-tolerantie.sh <groep> <stream-artifact> <versie>
#
# De regel, in drieën:
#
#   onbekend veld            negeren
#   onbekend berichttype     overslaan
#   onbekende enum-waarde    niet fataal
#
# Streng op wat wij versturen, tolerant op wat er ontvangen wordt. Dat is geen slordigheid
# aan de ontvangende kant maar de voorwaarde waaronder een additieve wijziging niet-brekend
# kan zijn — en scenario 02 van deze showcase noemt zo'n wijziging precies dat.
#
# Zonder deze toets is die regel een zin in een document. Met deze toets is hij een
# eigenschap van twee bestanden die uit dezelfde bron komen.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "toets-tolerantie: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fout "gebruik: toets-tolerantie.sh <groep> <stream-artifact> <versie>"

GROEP="$1"
STREAM="$2"
VERSIE="$3"

WERK="${CBT_ROOT}/build/tolerantie"
REL="build/tolerantie"
rm -rf "${WERK}"; mkdir -p "${WERK}"

SPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${STREAM}" "${VERSIE}")"
yq -o=json '.' "${SPEC#"${CBT_ROOT}/"}" > "${WERK}/stream.json"

# Streng: precies zoals gepubliceerd. Tolerant: dezelfde bron, zonder additionalProperties
# en zonder enums. Allebei afgeleid, dus ze kunnen niet uit elkaar lopen.
jq '{ components: { schemas: .components.schemas } }' "${REL}/stream.json" > "${WERK}/streng.json"
jq '{ components: { schemas: (.components.schemas
      | walk(if type == "object" then del(.additionalProperties, .enum) else . end)) } }' \
  "${REL}/stream.json" > "${WERK}/tolerant.json"

# De drie gevallen, elk met het schema waartegen ze gehouden worden. Het onbekende
# berichttype heeft geen eigen schema — dat is precies het punt — dus daar toetsen we of de
# index hem niet kent en de consumer hem dus kan overslaan.
cat > "${WERK}/geval-veld.json" <<'JSON'
{"soort":"stap-afgerond","tijd":"2026-08-06T09:13:07Z","runId":"run-7c41a9","stapNummer":3,"uitkomst":"geslaagd","herkomst":"toekomstige-versie"}
JSON
cat > "${WERK}/geval-enum.json" <<'JSON'
{"soort":"run-afgerond","tijd":"2026-08-06T09:13:09Z","runId":"run-7c41a9","reden":"gestopt-door-beheerder"}
JSON

keur() {
  _schema="$1"; _ref="$2"; _geval="$3"
  jq --arg r "#/components/schemas/${_ref}" '. + {"$ref": $r}' \
    "${REL}/${_schema}.json" > "${WERK}/s.json"
  ajv validate --strict=false -c ajv-formats \
    -s "${REL}/s.json" -d "${REL}/${_geval}.json" >/dev/null 2>&1 && echo geldig || echo ongeldig
}

GECONTROLEERD=0
mislukt() { echo "  ROOD  $*"; MIS=$((MIS + 1)); }
MIS=0

echo "toets-tolerantie: ${GROEP}/${STREAM} ${VERSIE}"

# --- 1: onbekend veld -------------------------------------------------------------------

[ "$(keur streng StapAfgerondPayload geval-veld)" = "ongeldig" ] \
  && echo "  ok    onbekend veld: geweigerd door het strenge schema" \
  || mislukt "onbekend veld kwam door het strenge schema — dan vangt hij onze eigen typefouten niet"
GECONTROLEERD=$((GECONTROLEERD + 1))

[ "$(keur tolerant StapAfgerondPayload geval-veld)" = "geldig" ] \
  && echo "  ok    onbekend veld: geaccepteerd door het ontvangstschema" \
  || mislukt "onbekend veld werd geweigerd door het ontvangstschema — dan breekt onze eerste additieve wijziging de consumer"
GECONTROLEERD=$((GECONTROLEERD + 1))

# --- 2: onbekende enum-waarde -------------------------------------------------------------

[ "$(keur streng RunAfgerondPayload geval-enum)" = "ongeldig" ] \
  && echo "  ok    onbekende reden: geweigerd door het strenge schema" \
  || mislukt "onbekende enum-waarde kwam door het strenge schema"
GECONTROLEERD=$((GECONTROLEERD + 1))

[ "$(keur tolerant RunAfgerondPayload geval-enum)" = "geldig" ] \
  && echo "  ok    onbekende reden: geaccepteerd door het ontvangstschema" \
  || mislukt "onbekende enum-waarde werd geweigerd door het ontvangstschema"
GECONTROLEERD=$((GECONTROLEERD + 1))

# --- 3: onbekend berichttype ---------------------------------------------------------------
#
# Hier is er niets te valideren, en dat is de hele zaak: een soort die de index niet kent
# hoort overgeslagen te worden en niet tegen een willekeurig schema gehouden.

INDEX="$(jq -r '.components.messages | to_entries | map(.value.name) | join(" ")' "${REL}/stream.json")"
case " ${INDEX} " in
  *" deelsysteem-overgeslagen "*) mislukt "het onbekende berichttype staat wél in de index" ;;
  *) echo "  ok    onbekend berichttype: staat niet in de index, dus over te slaan" ;;
esac
GECONTROLEERD=$((GECONTROLEERD + 1))

verwacht_minstens "${GECONTROLEERD}" 5 "tolerantiecontroles"

[ "${MIS}" -eq 0 ] || fout "${MIS} van de ${GECONTROLEERD} controles is rood"
echo "toets-tolerantie: ${GECONTROLEERD} controles, alle groen"
