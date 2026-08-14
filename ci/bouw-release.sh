#!/usr/bin/env bash
#
# Zet de assets van één release klaar, met hun checksums.
#
#   bouw-release.sh spec <groep> <artifact> <versie>
#   bouw-release.sh bundel <bundelversie>
#
# Gescheiden van publiceren, en dat is geen indeling maar dezelfde regel als overal: een
# gate hoort vóór publicatie. Dit script draait op een laptop, zonder token en zonder iets
# uit te geven, en is daarmee volledig te controleren voordat er iets de deur uit gaat.
#
# De asset komt uit het **werkregister** en niet van schijf. Dat is precies wat de gates
# hebben gezien: publish-contract heeft hem door Spectral en langs de diff-gate gehaald en
# daarna in het register gezet. Een asset die uit contracts/ zou komen, kan afwijken van wat
# er getoetst is — dan is "de release bevat wat de gates gezien hebben" een aanname.
#
# Zie docs/besluiten.md, 2026-08-13: een gate leest uit de werkboom, nooit uit het kanaal.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "bouw-release: $*" >&2
  exit 1
}

[ "$#" -ge 2 ] || fout "gebruik: bouw-release.sh spec <groep> <artifact> <versie> | bouw-release.sh bundel <bundelversie>"

SOORT="$1"

case "${SOORT}" in
  spec)
    [ "$#" -eq 4 ] || fout "gebruik: bouw-release.sh spec <groep> <artifact> <versie>"
    GROEP="$2"; ARTIFACT="$3"; VERSIE="$4"
    TAG="${ARTIFACT}-${VERSIE}"
    ;;
  bundel)
    [ "$#" -eq 2 ] || fout "gebruik: bouw-release.sh bundel <bundelversie>"
    VERSIE="$2"
    TAG="stubbundel-${VERSIE}"
    ;;
  *)
    fout "onbekende soort: ${SOORT} — kies spec of bundel"
    ;;
esac

case "${VERSIE}" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) fout "versie moet de vorm X.Y.Z hebben: ${VERSIE}" ;;
esac

DOELMAP="${CBT_ROOT}/build/release/${TAG}"
DOEL_REL="build/release/${TAG}"
rm -rf "${DOELMAP}"
mkdir -p "${DOELMAP}"

# --- de asset --------------------------------------------------------------------------

if [ "${SOORT}" = "spec" ]; then
  # De bestandsnaam draagt de versie. Een spec die van zijn URL loskomt — doorgestuurd,
  # gekopieerd, in een ticket geplakt — moet nog steeds zeggen wat hij is.
  BRON="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${ARTIFACT}" "${VERSIE}")"
  cp "${BRON}" "${DOELMAP}/${TAG}.yaml"
  echo "bouw-release: ${TAG}.yaml uit het werkregister"
else
  BUNDEL="${CBT_ROOT}/build/stubbundel-${VERSIE}.tgz"
  [ -f "${BUNDEL}" ] || fout "geen bundel op build/stubbundel-${VERSIE}.tgz. Draai eerst ci/bouw-stubbundel.sh"

  # De bundel draagt een manifest met de checksum van elke spec die erin zit. Die worden
  # hier tegen het werkregister gehouden: zonder deze vergelijking is "de bundel hoort bij
  # de specs die de gates gezien hebben" een aanname in plaats van een controle.
  # Binnen build/ en niet in /tmp: het gereedschap draait in containers met alleen de
  # hoofdmap gemount, dus wat daarbuiten ligt bestaat voor jq en sha256som niet.
  UITPAK="${CBT_ROOT}/build/release/uitpak-${TAG}"
  UITPAK_REL="build/release/uitpak-${TAG}"
  rm -rf "${UITPAK}"
  mkdir -p "${UITPAK}"
  tar -xzf "${BUNDEL}" -C "${UITPAK}"
  # Relatief aan de hoofdmap: jq draait in een container waar die op /work staat.
  MANIFEST="${UITPAK_REL}/bundel/manifest.json"
  [ -f "${CBT_ROOT}/${MANIFEST}" ] || fout "de bundel heeft geen manifest.json"

  GROEP="$(jq -r '.groep' "${MANIFEST}")"
  GECONTROLEERD=0
  while IFS=' ' read -r m_artifact m_versie m_bestand m_som; do
    [ -n "${m_artifact}" ] || continue
    REGISTERSPEC="$("${CBT_ROOT}/ci/get-contract.sh" "${GROEP}" "${m_artifact}" "${m_versie}")"
    REGISTERSOM="$(sha256som "$(dirname "${REGISTERSPEC#"${CBT_ROOT}/"}")" "$(basename "${REGISTERSPEC}")" | cut -d' ' -f1)"
    [ "${REGISTERSOM}" = "${m_som}" ] \
      || fout "${m_artifact} ${m_versie} in de bundel wijkt af van het werkregister: ${m_som} tegen ${REGISTERSOM}"
    echo "  ok  ${m_artifact} ${m_versie} (${m_bestand}) komt overeen met het werkregister"
    GECONTROLEERD=$((GECONTROLEERD + 1))
  done <<EOF
$(jq -r '.specs[] | "\(.artifact) \(.versie) \(.bestand) \(.sha256)"' "${MANIFEST}")
EOF
  rm -rf "${UITPAK}"

  verwacht_minstens "${GECONTROLEERD}" 2 "specs uit het manifest tegen het werkregister gehouden"
  cp "${BUNDEL}" "${DOELMAP}/${TAG}.tgz"
  echo "bouw-release: ${TAG}.tgz, manifest klopt met het werkregister"
fi

# --- de checksums ------------------------------------------------------------------------
#
# Naast de assets en zonder pad ervoor: in een release zijn er geen mappen. Te controleren
# met `sha256sum -c` en met `shasum -a 256 -c`.

# Eerst de lijst vastleggen, dan pas schrijven: het doelbestand ontstaat door de
# omleiding, en anders staat SHA256SUMS met de checksum van een leeg bestand in zichzelf.
ASSETS="$( cd "${DOELMAP}" && ls )"
for bestand in ${ASSETS}; do
  sha256som "${DOEL_REL}" "${bestand}"
done > "${DOELMAP}/SHA256SUMS"

# awk en geen `grep -c ''`: die geeft exit 1 op een leeg bestand, en dan beëindigt set -e
# het script vóórdat verwacht_minstens hieronder kan zeggen wat er mis is. Precies nul
# assets is de fout die deze gate moet melden, niet de fout die hem doodt.
AANTAL="$(awk 'END { print NR }' "${DOELMAP}/SHA256SUMS")"
verwacht_minstens "${AANTAL}" 1 "assets met een checksum"

echo "bouw-release: ${TAG} klaar in ${DOEL_REL}/ — ${AANTAL} asset(s) plus SHA256SUMS"
sed 's/^/  /' "${DOELMAP}/SHA256SUMS"
