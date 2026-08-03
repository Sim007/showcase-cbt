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
#
# Elke stap komt ook in het rapport terecht, met het tijdstip erbij.
stap() {
  _omschrijving="$1"
  shift
  STAP_LOG="$(mktemp)"
  printf '  %-44s' "${_omschrijving}"
  if "$@" >"${STAP_LOG}" 2>&1; then
    echo " ok"
    _rapport_regel "${_omschrijving}" "groen"
    return 0
  else
    echo " MISLUKT"
    _rapport_regel "${_omschrijving}" "**ROOD**"
    sed 's/^/    /' "${STAP_LOG}" >&2
    return 1
  fi
}

# rapport_start <onderdeel> / bijzonderheid <tekst> / rapport_oordeel <tekst>
#
# Eén rapport per hoofdstuk, chronologisch, met een tijdstip per stap. Dat is waar
# "releasen op testbewijs" op neerkomt: niet dát het groen was, maar wat er wanneer is
# aangetoond en tegen welke contractversie.
#
# Het rapport staat bij het hoofdstuk waar het over gaat, in <hoofdstuk>/rapport/. Die map
# staat in .gitignore: een testbewijs hoort bij een run en niet bij de broncode.
#
# De standaard wijst naar hoofdstuk 1. Een ander hoofdstuk gebruikt dezelfde pipelines en
# zet CBT_RAPPORT naar zijn eigen bestand.
rapport_start() {
  RAPPORT_ONDERDEEL="$1"
  RAPPORT_BESTAND="${CBT_RAPPORT:-${CBT_ROOT}/01-basis/rapport/rapport-cbt-01.md}"
  export RAPPORT_ONDERDEEL RAPPORT_BESTAND
  mkdir -p "$(dirname "${RAPPORT_BESTAND}")"
  [ -f "${RAPPORT_BESTAND}" ] && return 0
  {
    _nr="$(basename "${RAPPORT_BESTAND}" .md | sed 's/.*-//')"
    echo "# Rapport CBT — hoofdstuk ${_nr#0}"
    echo
    echo "Begonnen op $(date -u '+%Y-%m-%d %H:%M:%S') UTC. Alle tijden zijn UTC."
    echo
    echo "| Tijd | Onderdeel | Stap | Uitkomst | Bijzonderheden |"
    echo "|---|---|---|---|---|"
  } > "${RAPPORT_BESTAND}"
}

_rapport_regel() {
  [ -n "${RAPPORT_BESTAND:-}" ] || return 0
  printf '| %s | %s | %s | %s | |\n' \
    "$(date -u '+%H:%M:%S')" "${RAPPORT_ONDERDEEL}" "$1" "$2" >> "${RAPPORT_BESTAND}"
  _live
}

# Met CBT_LIVE=1 ververst de pagina na elke stap, zodat je tijdens een demo ziet wat er
# gebeurt in plaats van het achteraf te lezen. Zonder die vlag verandert er niets — een
# pipeline op een runner heeft geen browser.
_live() {
  [ -n "${CBT_LIVE:-}" ] || return 0
  "${CBT_ROOT}/ci/rapport-html.sh" "${RAPPORT_BESTAND}" >/dev/null 2>&1 || true
}

# Hangt een detail aan de vorige regel: hoeveel tests, welke uitkomst.
bijzonderheid() {
  [ -n "$1" ] || return 0
  echo "    $1"
  [ -n "${RAPPORT_BESTAND:-}" ] || return 0
  _regel="$(tail -1 "${RAPPORT_BESTAND}")"
  sed '$ d' "${RAPPORT_BESTAND}" > "${RAPPORT_BESTAND}.tmp"
  printf '%s\n' "${_regel% |} $1 |" >> "${RAPPORT_BESTAND}.tmp"
  mv "${RAPPORT_BESTAND}.tmp" "${RAPPORT_BESTAND}"
  _live
}

rapport_oordeel() {
  [ -n "${RAPPORT_BESTAND:-}" ] || return 0
  printf '| %s | %s | — | **oordeel** | %s |\n' \
    "$(date -u '+%H:%M:%S')" "${RAPPORT_ONDERDEEL}" "$1" >> "${RAPPORT_BESTAND}"
  _live
  [ -n "${CBT_LIVE:-}" ] || echo "rapport: ${RAPPORT_BESTAND#"${CBT_ROOT}/"}"
}

# info_endpoints <omgeving>
#
# Schrijft per draaiende service op die omgeving één regel JSON: de inhoud van zijn
# info-endpoint. Welke containers erbij horen komt uit het compose-project
# (<omgeving>-<deelsysteem>) en de poort uit de portmapping — zo hoeft de aanroeper niet
# te weten welke deelsystemen er bestaan, en ziet hij alleen wat er werkelijk staat.
#
# Dat laatste is geen detail. Een lijst met verwachte deelsystemen zou verouderen zodra
# een squad releaset, en zou een ontbrekend deelsysteem stil verzwijgen in plaats van
# zichtbaar maken.
info_endpoints() {
  _omgeving="$1"
  for _container in $(docker ps --format '{{.Names}}'); do
    _project="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' \
                "${_container}" 2>/dev/null || true)"
    case "${_project}" in
      "${_omgeving}-"*) ;;
      *) continue ;;
    esac
    _poort="$(docker port "${_container}" 2>/dev/null | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p' | head -1)"
    [ -n "${_poort}" ] || continue
    _info="$(curl -fsS "http://localhost:${_poort}/actuator/info" 2>/dev/null || true)"
    [ -n "${_info}" ] || continue
    printf '%s\n' "${_info}"
  done
}
