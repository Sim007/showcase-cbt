#!/usr/bin/env bash
#
# Pipeline 1 van 4: bouwen en testen van één microservice.
#
#   pipeline-microservice.sh <deelsysteem> <microservice>
#
# Draait per microservice, niet per deelsysteem. Levert een image met een eigen versie op.
# De contractlaag zit hier níét in: die vraagt een draaiend deelsysteem en hoort daarom in
# pipeline 2.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/tools.sh
. "${CBT_ROOT}/ci/lib/tools.sh"

fout() {
  echo "pipeline-microservice: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fout "gebruik: pipeline-microservice.sh <deelsysteem> <microservice>"

DEELSYSTEEM="$1"
MICROSERVICE="$2"
MODULE="deelsystemen/${DEELSYSTEEM}/${MICROSERVICE}"

[ -d "${CBT_ROOT}/${MODULE}" ] || fout "geen microservice ${MICROSERVICE} in deelsysteem ${DEELSYSTEEM}"

VERSIE="$(yq -p=xml -o=yaml -r '.project.version' "${MODULE}/pom.xml" 2>/dev/null)"
[ -n "${VERSIE}" ] && [ "${VERSIE}" != "null" ] || fout "kon de versie niet uit ${MODULE}/pom.xml lezen"

echo "== ${MICROSERVICE} ${VERSIE} =="
rapport_start

stap "unit" mvn "${MODULE}" test -Dgroups=unit
bijzonderheid "$(grep -oE 'Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+' "${STAP_LOG}" | tail -1)"

stap "integratie" mvn "${MODULE}" test -Dgroups=integratie
bijzonderheid "$(grep -oE 'Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+' "${STAP_LOG}" | tail -1)"

stap "jar bouwen" mvn "${MODULE}" -q package -DskipTests
stap "image bouwen" docker build -q -t "cbt/${MICROSERVICE}:${VERSIE}" "${CBT_ROOT}/${MODULE}"

rapport_klaar "${CBT_ROOT}/build/rapport/microservice-${MICROSERVICE}-${VERSIE}.md" \
  "${MICROSERVICE} ${VERSIE}" \
  "Oordeel: groen. De microservice is gebouwd en getoetst tegen zijn eigen tests."
echo "klaar: cbt/${MICROSERVICE}:${VERSIE}"
