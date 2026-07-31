# Extern gereedschap draait als container, op een vastgepinde tag, zodat de versie op
# een laptop en op een runner identiek is. Roep deze tools nergens anders rechtstreeks
# aan: dit bestand is het enige punt waar een tagbump nodig is.
#
# Dit bestand wordt gesourced, niet uitgevoerd. Het zet zelf geen shell-opties;
# `set -euo pipefail` hoort in het aanroepende script.

OASDIFF_IMAGE="tufin/oasdiff:v1.11.7"
JQ_IMAGE="ghcr.io/jqlang/jq:1.8.1"
MAVEN_IMAGE="maven:3.9.16-eclipse-temurin-21"

# Alles draait als de aanroepende gebruiker en zonder netwerk: deze tools lezen
# uitsluitend bestanden uit de werkmap.
_tools_run() {
  _image="$1"
  shift
  docker run --rm --interactive \
    --network none \
    --user "$(id -u):$(id -g)" \
    --volume "${CBT_ROOT}:/work:ro" \
    --workdir /work \
    "$_image" "$@"
}

# oasdiff breaking <oude-spec> <nieuwe-spec>
# Paden zijn relatief aan de wortel van de repository.
# Exitcode 1 betekent: er is minstens één breaking wijziging gevonden.
oasdiff() {
  _tools_run "$OASDIFF_IMAGE" "$@"
}

# jq, met dezelfde argumenten als de gewone jq.
jq() {
  _tools_run "$JQ_IMAGE" "$@"
}

# mvn <werkmap-relatief-aan-de-hoofdmap> <argumenten...>
#
# Maven wijkt op twee punten af van de tools hierboven: hij schrijft naar target/ en hij
# haalt dependencies op, dus geen read-only mount en geen --network none.
#
# De dependency-cache staat in build/m2/ en niet in een named volume: dat volume is van
# root, en zodra de container als de aanroepende gebruiker draait, kan Maven er niet in
# schrijven. build/ staat al in .gitignore.
mvn() {
  _werkmap="$1"
  shift
  mkdir -p "${CBT_ROOT}/build/m2"
  docker run --rm --interactive \
    --user "$(id -u):$(id -g)" \
    --volume "${CBT_ROOT}:/work" \
    --workdir "/work/${_werkmap}" \
    --env MAVEN_CONFIG=/m2 \
    --volume "${CBT_ROOT}/build/m2:/m2" \
    "$MAVEN_IMAGE" \
    mvn -Duser.home=/m2 -Dmaven.repo.local=/m2/repository "$@"
}
