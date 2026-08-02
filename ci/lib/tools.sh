# Extern gereedschap draait als container, op een vastgepinde tag, zodat de versie op
# een laptop en op een runner identiek is. Roep deze tools nergens anders rechtstreeks
# aan: dit bestand is het enige punt waar een tagbump nodig is.
#
# Dit bestand wordt gesourced, niet uitgevoerd. Het zet zelf geen shell-opties;
# `set -euo pipefail` hoort in het aanroepende script.

OASDIFF_IMAGE="tufin/oasdiff:v1.11.7"
JQ_IMAGE="ghcr.io/jqlang/jq:1.8.1"
MAVEN_IMAGE="maven:3.9.16-eclipse-temurin-21"
YQ_IMAGE="mikefarah/yq:4.53.3"
NODE_IMAGE="node:22.23.2-alpine"
AJV_VERSIE="5.0.0"
PLAYWRIGHT_VERSIE="1.62.1"

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

# yq, met dezelfde argumenten als de gewone yq.
#
# Nodig omdat de spec YAML is en een WireMock-mapping JSON: er moet iets omzetten, en jq
# kan alleen JSON lezen. yq doet verder niets in deze opzet.
yq() {
  _tools_run "$YQ_IMAGE" "$@"
}

# ajv <argumenten...>
#
# JSON Schema-validator voor stap 7 van de stubgeneratie: elke responsebody tegen zijn
# schema. Een eigen validator schrijven is de verkeerde soort werk — je krijgt hem net
# niet compleet en dat merk je pas als hij iets doorlaat.
#
# Zelfde patroon als Maven: de installatie staat in build/node/ zodat hij niet elke run
# opnieuw wordt opgehaald, en die map staat al in .gitignore.
ajv() {
  mkdir -p "${CBT_ROOT}/build/node"
  if [ ! -d "${CBT_ROOT}/build/node/node_modules/ajv-cli" ]; then
    # HOME wijst naar de gemounte map: npm wil een schrijfbare cache, en /root is dat niet
    # zodra de container als de aanroepende gebruiker draait.
    docker run --rm --user "$(id -u):$(id -g)" \
      --volume "${CBT_ROOT}/build/node:/n" --workdir /n --env HOME=/n \
      "$NODE_IMAGE" npm install --no-fund --no-audit \
      "ajv-cli@${AJV_VERSIE}" ajv-formats
  fi
  docker run --rm --interactive \
    --network none \
    --user "$(id -u):$(id -g)" \
    --volume "${CBT_ROOT}:/work" \
    --volume "${CBT_ROOT}/build/node:/n" \
    --workdir /work \
    "$NODE_IMAGE" node /n/node_modules/ajv-cli/dist/index.js "$@"
}

# playwright <netwerk> <base-url> <argumenten...>
#
# Draait de gedeelde smoke uit playwright/. Geen browserimage: de smoke praat HTTP, en de
# officiële Playwright-image is ruim twee gigabyte. Laptopbudget is een ontwerpeis.
# Hoofdstuk 8 heeft browsers wel nodig; dan komt daar een eigen image bij.
#
# node_modules hangt op de hoofdmap en niet in playwright/: de specs staan bij de
# deelsystemen, en Node zoekt zijn afhankelijkheden omhoog vanaf het bestand. Vanuit
# deelsystemen/order/smoke/ komt hij dan bij de wortel uit en nergens anders.
#
# Zelfde patroon als ajv: installatie in build/node/, HOME naar een schrijfbare map.
playwright() {
  _netwerk="$1"
  _base_url="$2"
  shift 2
  mkdir -p "${CBT_ROOT}/build/node"
  if [ ! -d "${CBT_ROOT}/build/node/node_modules/@playwright/test" ]; then
    docker run --rm --user "$(id -u):$(id -g)" \
      --volume "${CBT_ROOT}/build/node:/n" --workdir /n --env HOME=/n \
      --env PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
      "$NODE_IMAGE" npm install --no-fund --no-audit "@playwright/test@${PLAYWRIGHT_VERSIE}"
  fi
  docker run --rm --interactive \
    --network "${_netwerk}" \
    --user "$(id -u):$(id -g)" \
    --volume "${CBT_ROOT}:/work" \
    --volume "${CBT_ROOT}/build/node/node_modules:/work/node_modules" \
    --workdir /work/playwright \
    --env HOME=/tmp \
    --env CI=1 \
    --env SMOKE_BASE_URL="${_base_url}" \
    "$NODE_IMAGE" npx playwright test "$@"
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
  # De contracttests praten met een gedeployd deelsysteem; met CBT_NETWERK gezet hangt
  # Maven aan datzelfde compose-netwerk en bereikt hij de buur op zijn servicenaam.
  _netwerk=""
  [ -n "${CBT_NETWERK:-}" ] && _netwerk="--network=${CBT_NETWERK}"
  docker run --rm --interactive \
    ${_netwerk} \
    --user "$(id -u):$(id -g)" \
    --volume "${CBT_ROOT}:/work" \
    --workdir "/work/${_werkmap}" \
    --env MAVEN_CONFIG=/m2 \
    --volume "${CBT_ROOT}/build/m2:/m2" \
    "$MAVEN_IMAGE" \
    mvn -Duser.home=/m2 -Dmaven.repo.local=/m2/repository "$@"
}

# stap <omschrijving> <commando...>
#
# Draait een commando stil en meldt alleen of het lukte. Faalt het, dan komt de uitvoer
# alsnog volledig naar buiten. Een pipeline waarin de uitvoer verdrinkt toont niets, en
# een demo waarin je Spring ziet opstarten toont het verkeerde.
#
# Het logbestand blijft na afloop staan in ${STAP_LOG}, zodat de aanroeper er nog een
# samenvatting uit kan halen — het aantal tests bijvoorbeeld.
stap() {
  _omschrijving="$1"
  shift
  STAP_LOG="$(mktemp)"
  printf '  %-44s' "${_omschrijving}"
  if "$@" >"${STAP_LOG}" 2>&1; then
    echo " ok"
  else
    echo " MISLUKT"
    sed 's/^/    /' "${STAP_LOG}" >&2
    return 1
  fi
}
