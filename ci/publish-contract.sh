#!/usr/bin/env bash
#
# De diff-gate hoort bij de contractwijziging, niet bij een pipeline: het is een
# vergelijking van twee artefacten en geen runtime-gedrag. Daarom staat hij hier en
# niet in de pipeline van Payment of Order.
#
#   publish-contract.sh <groep> <artifact> <versie> <specpad>
#
# Drie stappen: hoogste gepubliceerde versie ophalen, oasdiff ertegen draaien, en
# publiceren met een expliciete versie. Bij een leeg register vervallen de eerste twee.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

REGISTRY_URL="${REGISTRY_URL:-http://localhost:8080}"
API="${REGISTRY_URL}/apis/registry/v3"

fout() {
  echo "publish-contract: $*" >&2
  exit 1
}

[ "$#" -eq 4 ] || fout "gebruik: publish-contract.sh <groep> <artifact> <versie> <specpad>"

GROEP="$1"
ARTIFACT="$2"
VERSIE="$3"
SPECPAD="$4"

command -v curl >/dev/null 2>&1 || fout "curl is niet gevonden op deze machine"
[ -f "${SPECPAD}" ] || fout "spec niet gevonden: ${SPECPAD}"

case "${VERSIE}" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) fout "versie moet de vorm X.Y.Z hebben, geen bereik en geen latest: ${VERSIE}" ;;
esac

ARTEFACT_URL="${API}/groups/${GROEP}/artifacts/${ARTIFACT}"
WERKMAP="${CBT_ROOT}/build/contracts"
mkdir -p "${WERKMAP}"

# Het soort spec volgt uit de inhoud en niet uit een vlag: een spec die zichzelf openapi
# noemt en als ASYNCAPI wordt gepubliceerd, komt er verkeerd weer uit en dat merk je pas
# bij de consumer.
if grep -q '^asyncapi:' "${SPECPAD}"; then
  ARTEFACT_TYPE="ASYNCAPI"
elif grep -q '^openapi:' "${SPECPAD}"; then
  ARTEFACT_TYPE="OPENAPI"
else
  fout "${SPECPAD} begint niet met openapi: of asyncapi: — onbekend soort spec"
fi

major() { echo "${1%%.*}"; }

# Sorteert X.Y.Z numeriek zonder sort -V, dat GNU-specifiek is.
hoogste_versie() {
  awk -F. 'NF==3 {printf "%010d%010d%010d %s\n", $1, $2, $3, $0}' \
    | sort \
    | tail -1 \
    | cut -d' ' -f2
}

curl -fsS "${API}/system/info" >/dev/null 2>&1 \
  || fout "register niet bereikbaar op ${REGISTRY_URL} — staat compose/registry.yml omhoog?"

# --- stap 1: hoogste gepubliceerde versie -----------------------------------------

VERSIES_JSON="$(curl -sS "${ARTEFACT_URL}/versions?limit=500" || true)"
VORIGE="$(printf '%s' "${VERSIES_JSON}" | jq -r '.versions[]?.version // empty' 2>/dev/null | hoogste_versie || true)"

if [ -z "${VORIGE}" ]; then
  echo "register leeg voor ${GROEP}/${ARTIFACT} — eerste publicatie, niets te vergelijken"
else
  echo "hoogste gepubliceerde versie: ${VORIGE}"

  # --- stap 2: diff-gate ----------------------------------------------------------
  #
  # oasdiff leest OpenAPI en niets anders. Voor een AsyncAPI-grens valt deze gate dus weg,
  # en dat wordt hier hardop gezegd in plaats van stil overgeslagen: een gate die je niet
  # ziet ontbreken, denk je te hebben. Het register houdt zijn compatibility rule, maar dat
  # is één net in plaats van twee. Zie O13.
  if [ "${ARTEFACT_TYPE}" != "OPENAPI" ]; then
    # Een waarschuwing scrollt voorbij en stilte mag niet de standaard zijn: publiceren
    # zonder gate kan wel, maar alleen als iemand er expliciet voor tekent. Zie O13.
    [ "${CBT_ZONDER_DIFF_GATE:-}" = "akkoord" ] || fout \
"de diff-gate kan deze wijziging niet toetsen: oasdiff leest geen ${ARTEFACT_TYPE}.

  ${GROEP}/${ARTIFACT} gaat van ${VORIGE} naar ${VERSIE} zonder dat iets heeft
  vastgesteld of dat een breuk is. Alleen de compatibility rule van het register
  staat er dan tussen — één net in plaats van twee.

  Publiceren mag, maar niet stilzwijgend. Bevestig het:

      CBT_ZONDER_DIFF_GATE=akkoord ci/publish-contract.sh ${GROEP} ${ARTIFACT} ${VERSIE} ${SPECPAD}

  Zie O13 in docs/showcase-cbt.md."

    echo "diff-gate NIET UITGEVOERD: oasdiff leest geen ${ARTEFACT_TYPE}, en dat is bevestigd."
    echo "  Deze wijziging is niet op breuken getoetst. Zie O13 in docs/showcase-cbt.md."
  else
    VORIGE_SPEC="${WERKMAP}/${ARTIFACT}-${VORIGE}.vorige.yaml"
    curl -fsS -o "${VORIGE_SPEC}" "${ARTEFACT_URL}/versions/${VORIGE}/content" \
      || fout "kon versie ${VORIGE} niet ophalen uit het register"

    # oasdiff draait in een container met de wortel op /work; paden dus relatief.
    OUD_REL="${VORIGE_SPEC#"${CBT_ROOT}/"}"
    NIEUW_REL="${SPECPAD#"${CBT_ROOT}/"}"

    # oasdiff onderscheidt in zijn exitcode een gevonden breuk (1) van een tool die zijn
    # werk niet kon doen (alles daarboven, bijvoorbeeld 102 bij een onleesbare spec). Dat
    # verschil moet blijven staan: een gate die "breaking wijziging" meldt terwijl hij in
    # werkelijkheid niets heeft kunnen vergelijken, blokkeert bij toeval en laat bij toeval
    # door.
    BREKEND=0
    oasdiff breaking "${OUD_REL}" "${NIEUW_REL}" --fail-on ERR || BREKEND=$?

    if [ "${BREKEND}" -gt 1 ]; then
      fout "oasdiff kon de vergelijking niet uitvoeren (exitcode ${BREKEND}). Er is niets getoetst"
    fi

    if [ "${BREKEND}" -eq 1 ]; then
      if [ "$(major "${VERSIE}")" = "$(major "${VORIGE}")" ]; then
        fout "breaking wijziging zonder major-bump: ${VORIGE} -> ${VERSIE}. Publiceer als $(( $(major "${VORIGE}") + 1 )).0.0"
      fi
      echo "breaking wijziging, maar de major gaat van $(major "${VORIGE}") naar $(major "${VERSIE}") — toegestaan"
    else
      echo "geen breaking wijziging gevonden"
    fi
  fi
fi

# Een spec zonder operaties of kanalen is geldig YAML en beschrijft niets. Zonder deze
# regel publiceert de gate hem net zo vrolijk, en dan staat er een lege belofte in het
# register waar een consumer op kan pinnen.
if [ "${ARTEFACT_TYPE}" = "OPENAPI" ]; then
  INHOUD="$(yq -o=json '.' "${SPECPAD#"${CBT_ROOT}/"}" | jq -r '[.paths // {} | keys[]] | length')"
  verwacht_minstens "${INHOUD}" 1 "paden in ${SPECPAD}"
else
  INHOUD="$(yq -o=json '.' "${SPECPAD#"${CBT_ROOT}/"}" | jq -r '[.channels // {} | keys[]] | length')"
  verwacht_minstens "${INHOUD}" 1 "kanalen in ${SPECPAD}"
fi

# --- stap 3: publiceren -------------------------------------------------------------

PAYLOAD="${WERKMAP}/${ARTIFACT}-${VERSIE}.payload.json"

if [ -z "${VORIGE}" ]; then
  jq -Rs --arg artifact "${ARTIFACT}" --arg versie "${VERSIE}" --arg type "${ARTEFACT_TYPE}" \
    '{artifactId: $artifact, artifactType: $type,
      firstVersion: {version: $versie,
                     content: {content: ., contentType: "application/x-yaml"}}}' \
    < "${SPECPAD}" > "${PAYLOAD}"

  curl -fsS -X POST -H "Content-Type: application/json" --data-binary "@${PAYLOAD}" \
    "${API}/groups/${GROEP}/artifacts?ifExists=FAIL" >/dev/null \
    || fout "publicatie van ${VERSIE} mislukt — bestaat het artifact al?"

  # Het register vormt een tweede net als de gate wordt overgeslagen. Voor artifact
  # type OPENAPI is die controle in Apicurio 3.x beperkt; de gate hierboven blijft
  # de maatregel die het werk doet.
  curl -fsS -X POST -H "Content-Type: application/json" \
    -d '{"ruleType":"COMPATIBILITY","config":"BACKWARD"}' \
    "${ARTEFACT_URL}/rules" >/dev/null \
    || fout "kon de compatibility rule niet op BACKWARD zetten"

  echo "artifact ${GROEP}/${ARTIFACT} aangemaakt op ${VERSIE}, compatibility rule BACKWARD"
else
  jq -Rs --arg versie "${VERSIE}" \
    '{version: $versie, content: {content: ., contentType: "application/x-yaml"}}' \
    < "${SPECPAD}" > "${PAYLOAD}"

  curl -fsS -X POST -H "Content-Type: application/json" --data-binary "@${PAYLOAD}" \
    "${ARTEFACT_URL}/versions" >/dev/null \
    || fout "publicatie van ${VERSIE} mislukt — bestaat die versie al, of weigert het register hem?"

  echo "${GROEP}/${ARTIFACT} ${VERSIE} gepubliceerd"
fi
