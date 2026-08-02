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

VERSIE="$(yq -p=xml -r '.project.version' "${MODULE}/pom.xml")"
[ -n "${VERSIE}" ] && [ "${VERSIE}" != "null" ] || fout "kon de versie niet uit ${MODULE}/pom.xml lezen"

echo "== ${MICROSERVICE} ${VERSIE} =="

echo "-- unit"
mvn "${MODULE}" test -Dgroups=unit

echo "-- integratie"
mvn "${MODULE}" test -Dgroups=integratie

echo "-- image"
mvn "${MODULE}" -q package -DskipTests
docker build -q -t "cbt/${MICROSERVICE}:${VERSIE}" "${CBT_ROOT}/${MODULE}" >/dev/null

echo "klaar: cbt/${MICROSERVICE}:${VERSIE}"
