#!/usr/bin/env bash
#
# Publiceert een klaargezette release naar GitHub Releases.
#
#   publiceer-release.sh <tag>
#
# Verwacht dat build/release/<tag>/ er staat, gemaakt door bouw-release.sh. Die scheiding is
# de gate-regel: bouwen en controleren kan zonder token en zonder netwerk, publiceren is de
# stap daarna en nooit ervoor.
#
# GitHub Releases is het **distributiekanaal** en niet het werkregister. Squad 2 leest hier,
# ná de gates; onze eigen pipeline leest Apicurio, vóór de gates. Zie docs/besluiten.md,
# 2026-08-13.
#
# Onveranderlijkheid is hier discipline en geen eigenschap. Een tag is te verwijderen en
# opnieuw te zetten, en geen enkele controle van ons ziet dat. Dit script weigert daarom te
# publiceren op een release die al bestaat — dat is het maximale wat wij kunnen afdwingen.
# Wat er tegenover staat is de checksum: wordt een asset toch vervangen, dan valt dat op bij
# squad 2 en niet bij ons. Daarom draagt elke asset een eigen .sha256 en staat in de
# contractdocumentatie dat verifiëren geen formaliteit is.
#
# Het token komt uit de omgeving en staat nooit op de commandoregel.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "publiceer-release: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fout "gebruik: publiceer-release.sh <tag>"

TAG="$1"
REPO="${CBT_REPO:-Sim007/showcase-cbt}"
API="https://api.github.com/repos/${REPO}"
UPLOADS="https://uploads.github.com/repos/${REPO}"

MAP="${CBT_ROOT}/build/release/${TAG}"
MAP_REL="build/release/${TAG}"
[ -d "${MAP}" ] || fout "geen assets op ${MAP_REL}. Draai eerst ci/bouw-release.sh"
ls "${MAP}"/*.sha256 >/dev/null 2>&1 || fout "geen .sha256-bestanden in ${MAP_REL}"

[ -n "${GITHUB_TOKEN:-}" ] || fout "GITHUB_TOKEN staat niet in de omgeving"

kop_auth() { printf 'Authorization: Bearer %s' "${GITHUB_TOKEN}"; }

# --- 1: de tag moet bestaan, de release nog niet -----------------------------------------
#
# De tag wordt door git gezet en niet door dit script: een release hoort te wijzen naar een
# commit die iemand bewust heeft gemarkeerd, niet naar wat er toevallig op de branch stond.

TAGSTATUS="$(curl -sS -o /dev/null -w '%{http_code}' -H "$(kop_auth)" \
  -H "Accept: application/vnd.github+json" "${API}/git/ref/tags/${TAG}")"
[ "${TAGSTATUS}" = "200" ] || fout "tag ${TAG} bestaat niet op ${REPO} (HTTP ${TAGSTATUS}). Zet en push hem eerst."

RELSTATUS="$(curl -sS -o /dev/null -w '%{http_code}' -H "$(kop_auth)" \
  -H "Accept: application/vnd.github+json" "${API}/releases/tags/${TAG}")"
if [ "${RELSTATUS}" = "200" ]; then
  fout "release ${TAG} bestaat al. Een uitgegeven versie wordt niet overschreven; maak een nieuwe versie."
fi

# --- 2: de release aanmaken ---------------------------------------------------------------

ANTWOORD="${CBT_ROOT}/build/release/${TAG}-antwoord.json"
curl -sS -X POST -H "$(kop_auth)" -H "Accept: application/vnd.github+json" \
  -d "$(jq -n --arg tag "${TAG}" '{tag_name: $tag, name: $tag, draft: false, prerelease: true}')" \
  "${API}/releases" > "${ANTWOORD}"

RELEASE_ID="$(jq -r '.id // empty' "build/release/${TAG}-antwoord.json")"
[ -n "${RELEASE_ID}" ] || { sed 's/^/    /' "${ANTWOORD}" >&2; fout "aanmaken van de release mislukte"; }

# prerelease: true zolang de versie 0.x.y is. Dat is geen sier maar dezelfde uitspraak als
# het versienummer zelf — hier mag nog gebroken worden.

echo "publiceer-release: release ${TAG} aangemaakt (id ${RELEASE_ID})"

# --- 3: de assets erheen -------------------------------------------------------------------

GEUPLOAD=0
for pad in "${MAP}"/*; do
  bestand="$(basename "${pad}")"
  case "${bestand}" in *-antwoord.json) continue ;; esac
  curl -sS -X POST -H "$(kop_auth)" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@${pad}" \
    "${UPLOADS}/releases/${RELEASE_ID}/assets?name=${bestand}" > /dev/null \
    || fout "uploaden van ${bestand} mislukte"
  echo "  omhoog  ${bestand}"
  GEUPLOAD=$((GEUPLOAD + 1))
done

verwacht_minstens "${GEUPLOAD}" 2 "assets geüpload (minstens de asset zelf en zijn .sha256)"

# --- 4: terughalen en vergelijken -----------------------------------------------------------
#
# Zonder deze stap is "de release bevat wat de gates gezien hebben" een aanname. Wat er nu
# in het kanaal staat wordt opgehaald langs precies de URL die squad 2 krijgt, en tegen de
# checksums gehouden die hier zijn uitgerekend.

CONTROLE="${CBT_ROOT}/build/release/${TAG}-terug"
CONTROLE_REL="build/release/${TAG}-terug"
rm -rf "${CONTROLE}"; mkdir -p "${CONTROLE}"

TERUG=0
for sompad in "${MAP}"/*.sha256; do
  read -r som bestand < "${sompad}"
  curl -fsSL -o "${CONTROLE}/${bestand}" \
    "https://github.com/${REPO}/releases/download/${TAG}/${bestand}" \
    || fout "${bestand} is niet op te halen langs de URL die squad 2 krijgt"
  TERUGSOM="$(sha256som "${CONTROLE_REL}" "${bestand}" | cut -d' ' -f1)"
  [ "${TERUGSOM}" = "${som}" ] \
    || fout "${bestand} in de release wijkt af van wat er is gebouwd: ${TERUGSOM} tegen ${som}"
  echo "  ok      ${bestand} komt terug zoals hij is gebouwd"
  TERUG=$((TERUG + 1))
done

verwacht_minstens "${TERUG}" 1 "assets teruggehaald en vergeleken"
rm -rf "${CONTROLE}" "${ANTWOORD}"

echo "publiceer-release: ${TAG} staat, ${TERUG} asset(s) geverifieerd langs de publieke URL"
