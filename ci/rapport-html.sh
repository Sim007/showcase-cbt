#!/usr/bin/env bash
#
# Maakt van het rapport een pagina die je kunt laten zien.
#
#   rapport-html.sh [rapport.md]
#
# Leest de markdown-tabel die de pipelines hebben geschreven en zet die om. Geen extra
# gereedschap: pure bash, zodat Docker en bash de enige vereisten blijven. De pagina is
# zelfstandig — alle opmaak zit erin, dus hij werkt ook als je hem doorstuurt.

set -euo pipefail

CBT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fout() {
  echo "rapport-html: $*" >&2
  exit 1
}

BRON="${1:-${CBT_ROOT}/01-basis/rapport/rapport-cbt-01.md}"
[ -f "${BRON}" ] || fout "geen rapport gevonden op ${BRON}. Draai eerst een pipeline"

DOEL="${BRON%.md}.html"
TITEL="$(head -1 "${BRON}" | sed 's/^# //')"
BEGONNEN="$(sed -n '3p' "${BRON}")"

# & moet als eerste, anders verminkt hij de entiteiten die daarna komen.
ontsnap() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Tellen voordat we schrijven, zodat de samenvatting bovenaan kan staan.
GROEN=0
ROOD=0
OORDELEN=0
while IFS='|' read -r _ _tijd _onderdeel _stap uitkomst _rest; do
  case "${uitkomst}" in
    *ROOD*)    ROOD=$((ROOD + 1)) ;;
    *oordeel*) OORDELEN=$((OORDELEN + 1)) ;;
    *groen*)   GROEN=$((GROEN + 1)) ;;
  esac
done < <(grep '^| [0-9]' "${BRON}")

if [ "${ROOD}" -eq 0 ]; then
  STEMPEL='<span class="stempel groen">alles groen</span>'
else
  STEMPEL="<span class=\"stempel rood\">${ROOD} rood</span>"
fi

# Tijdens een run ververst de pagina zichzelf, zodat je het bewijs ziet opbouwen in plaats
# van pas achteraf te lezen. De laatste render gebeurt zonder CBT_LIVE en zet hem stil.
VERVERS=""
BEZIG=""
if [ -n "${CBT_LIVE:-}" ]; then
  VERVERS='<meta http-equiv="refresh" content="2">'
  BEZIG=' &middot; <span class="stempel bezig">bezig<span class="stip"></span></span>'
fi

{
cat <<HTML
<!doctype html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
${VERVERS}
<title>$(ontsnap "${TITEL}")</title>
<style>
  :root {
    --rand:#d9d5cd; --tekst:#232020; --zacht:#6b6560; --vlak:#faf9f7; --pagina:#fff;
    --groen:#2f6f43; --groenvlak:#eaf3ec; --rood:#a12c2c; --roodvlak:#f9ecec;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --rand:#34302b; --tekst:#ece9e4; --zacht:#9a938c; --vlak:#1b1a18; --pagina:#121110;
      --groen:#6fbc86; --groenvlak:#1c2a20; --rood:#e07b7b; --roodvlak:#2c1c1c;
    }
  }
  :root[data-theme="dark"] {
    --rand:#34302b; --tekst:#ece9e4; --zacht:#9a938c; --vlak:#1b1a18; --pagina:#121110;
    --groen:#6fbc86; --groenvlak:#1c2a20; --rood:#e07b7b; --roodvlak:#2c1c1c;
  }
  :root[data-theme="light"] {
    --rand:#d9d5cd; --tekst:#232020; --zacht:#6b6560; --vlak:#faf9f7; --pagina:#fff;
    --groen:#2f6f43; --groenvlak:#eaf3ec; --rood:#a12c2c; --roodvlak:#f9ecec;
  }
  * { box-sizing:border-box; }
  body {
    font:15px/1.55 ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;
    color:var(--tekst); background:var(--pagina); margin:0; padding:2.5rem 1.5rem 4rem;
  }
  main { max-width:64rem; margin:0 auto; }
  h1 { font-size:1.5rem; margin:0 0 .35rem; letter-spacing:-.01em; }
  .meta { color:var(--zacht); margin:0 0 1.75rem; }
  .stempel { display:inline-block; padding:.15rem .6rem; border-radius:999px;
             font-size:.8rem; font-weight:600; letter-spacing:.02em; }
  .stempel.groen { color:var(--groen); background:var(--groenvlak); }
  .stempel.rood  { color:var(--rood);  background:var(--roodvlak); }
  .stempel.bezig { color:var(--zacht); background:var(--vlak); }
  .stip { display:inline-block; width:.4rem; height:.4rem; margin-left:.35rem;
          border-radius:50%; background:currentColor; animation:klop 1s ease-in-out infinite; }
  @keyframes klop { 0%,100% { opacity:.25 } 50% { opacity:1 } }
  tbody tr:last-child { animation:aan .4s ease-out; }
  @keyframes aan { from { background:var(--groenvlak) } }
  .cijfers { display:flex; gap:2.5rem; flex-wrap:wrap; margin:0 0 2rem;
             padding:1rem 1.25rem; background:var(--vlak);
             border:1px solid var(--rand); border-radius:.5rem; }
  .getal { font-size:1.6rem; font-weight:600; font-variant-numeric:tabular-nums; }
  .label { color:var(--zacht); font-size:.78rem; text-transform:uppercase; letter-spacing:.06em; }
  .hoes { overflow-x:auto; border:1px solid var(--rand); border-radius:.5rem; }
  table { border-collapse:collapse; width:100%; min-width:46rem; }
  th,td { text-align:left; padding:.55rem .85rem; border-bottom:1px solid var(--rand); vertical-align:top; }
  th { font-size:.75rem; text-transform:uppercase; letter-spacing:.06em;
       color:var(--zacht); background:var(--vlak); position:sticky; top:0; }
  tr:last-child td { border-bottom:0; }
  td.tijd { font-variant-numeric:tabular-nums; color:var(--zacht); white-space:nowrap; }
  td.onderdeel { white-space:nowrap; }
  td.detail { color:var(--zacht); }
  .vink { color:var(--groen); font-weight:600; }
  .kruis { color:var(--rood); font-weight:600; }
  tr.oordeel { background:var(--vlak); }
  tr.oordeel td { font-weight:500; }
  tr.mislukt { background:var(--roodvlak); }
  footer { color:var(--zacht); font-size:.85rem; margin-top:2rem; }
  code { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:.9em; }
</style>
</head>
<body>
<main>
<h1>$(ontsnap "${TITEL}")</h1>
<p class="meta">$(ontsnap "${BEGONNEN}") &middot; ${STEMPEL}${BEZIG}</p>

<div class="cijfers">
  <div><div class="getal">${GROEN}</div><div class="label">stappen groen</div></div>
  <div><div class="getal">${ROOD}</div><div class="label">rood</div></div>
  <div><div class="getal">${OORDELEN}</div><div class="label">oordelen</div></div>
</div>

<div class="hoes">
<table>
<thead><tr><th>Tijd</th><th>Onderdeel</th><th>Stap</th><th>Uitkomst</th><th>Bijzonderheden</th></tr></thead>
<tbody>
HTML

while IFS='|' read -r _ tijd onderdeel stapnaam uitkomst detail _; do
  case "${uitkomst}" in
    *ROOD*)    merk='<span class="kruis">rood</span>'; rij=' class="mislukt"' ;;
    *oordeel*) merk='oordeel'; rij=' class="oordeel"' ;;
    *)         merk='<span class="vink">groen</span>'; rij='' ;;
  esac
  printf '<tr%s><td class="tijd">%s</td><td class="onderdeel">%s</td><td>%s</td><td>%s</td><td class="detail">%s</td></tr>\n' \
    "${rij}" \
    "$(ontsnap "$(echo ${tijd})")" \
    "$(ontsnap "$(echo ${onderdeel})")" \
    "$(ontsnap "$(echo ${stapnaam})")" \
    "${merk}" \
    "$(ontsnap "$(echo ${detail})")"
done < <(grep '^| [0-9]' "${BRON}")

cat <<HTML
</tbody>
</table>
</div>

<footer>
Gemaakt uit <code>$(ontsnap "$(basename "${BRON}")")</code> door <code>ci/rapport-html.sh</code>.
Dit is het testbewijs van één run en hoort daarom niet in de repository.
</footer>
</main>
</body>
</html>
HTML
# Schrijven en hernoemen, niet rechtstreeks naar het doel. `> "${DOEL}"` kapt het bestand
# eerst af en vult het daarna: wie er tussendoor leest, krijgt een halve pagina. Tijdens een
# demo ververst de browser elke twee seconden en wordt deze pagina na elke stap opnieuw
# geschreven — bemeten op een run van hoofdstuk 0 zag een bemonstering de tabel van 22 rijen
# terugvallen naar 2 en daarna doorgaan naar 27. Dat is precies de flits die je op een groot
# scherm niet wilt.
#
# `mv` binnen dezelfde map is atomair: een lezer ziet de oude pagina of de nieuwe, nooit een
# halve. Het tijdelijke bestand staat daarom naast het doel en niet in /tmp — over een
# mapgrens heen is het een kopie en geldt die garantie niet.
} > "${DOEL}.tmp"
mv "${DOEL}.tmp" "${DOEL}"

# Beide paden, en één keer. Zonder CBT_LIVE is de terminal het enige wat je hebt, en dan wil
# je weten waar het testbewijs staat — maar dit script draait aan het eind van een demo en
# niet na elke pipeline, dus het blijft bij één regel per stuk.
[ -n "${CBT_LIVE:-}" ] || {
  echo "rapport: ${BRON#"${CBT_ROOT}/"}"
  echo "rapport: ${DOEL#"${CBT_ROOT}/"}"
}
