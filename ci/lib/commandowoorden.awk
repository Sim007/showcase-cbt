# Schrijft het eerste woord van elke commandopositie in een shellscript, één per regel.
#
# Gebruikt door ci/controle-gates.sh voor de oplosbaarheidstoets: elk woord dat hier
# uitkomt, moet straks ergens naar oplossen. Dit bestand doet het lezen, de toets doet het
# oordelen.
#
# Dit is een benadering en geen volledige shell-parser. Wat er niet in zit: commando's
# bínnen $(), en commando's waarvan de naam pas bij expansie ontstaat. Die vallen buiten
# beeld en leveren dus geen valse melding op — de toets is smal met opzet, want een gate die
# ruis produceert wordt uitgezet of krijgt een negeerlijst, en dan bewaakt hij niets meer.
#
# Wat er wel in zit, kostte vijf rondes:
#
#   1  Een meerregelige echo leest zonder quote-toestand als een rij commando's, en levert
#      tientallen Nederlandse woorden op als "onvindbaar commando".
#   2  Een apostrof in Nederlands commentaar ("scenario's") opent een string die nooit
#      sluit. Daarom gaan volledige commentaarregels eruit vóór de toestand bepaald wordt.
#   3  Een case-patroon (`nee|off)`) staat op een commandopositie en is er geen.
#   4  Een commando dat als gequoot pad wordt aangeroepen — "${CBT_ROOT}/ci/x.sh" arg —
#      verdwijnt bij het weghalen van de string, waarna zijn eerste argument als commando
#      wordt gelezen. Vandaar een marker op de plek van elke string in plaats van een spatie.
#   5  Aanhalingstekens nesten. In
#
#          HUIDIGE="$(printf '%s' "${x}" | sed -n 's/.*"t":"\([^"]*\)".*/\1/p')"
#
#      staan negen dubbele quotes, waarvan vijf binnen enkele quotes staan en dus geen
#      quote zijn. Tellen of paren zoeken werkt daar niet: de toestand raakt ontregeld en
#      alles ná die regel wordt verkeerd gelezen. Die regel stond er al en kwam er per
#      toeval mee weg — tot er een regel bijkwam die de scheefstand zichtbaar maakte.
#
# Daarom loopt de scanner teken voor teken met een contextstapel: normaal, "", '' en $().
# Binnen '' is niets bijzonder, binnen "" tellen \ en $( wel, en binnen $() begint het
# quoten opnieuw. Die stapel blijft tussen regels staan, en daarmee vallen meerregelige
# strings vanzelf goed uit — ze zijn niet langer een apart geval.

BEGIN { heredoc = ""; top = 0; ctx[0] = "normaal"; casediep = 0; vervolg = "" }

# Vervangt elke string, elke $()-expansie en elk escape door een marker, en laat de rest
# staan. De stapel is globaal: aan het eind van een regel blijft staan wat nog open is.
function schoon(regel,    uit, i, L, c, n) {
  uit = ""
  i = 1
  L = length(regel)
  while (i <= L) {
    c = substr(regel, i, 1)
    n = substr(regel, i + 1, 1)

    if (ctx[top] == "sq") {
      if (c == "'") top--
      i++
      continue
    }
    if (ctx[top] == "dq") {
      if (c == "\\") { i += 2; continue }
      if (c == "$" && n == "(") { top++; ctx[top] = "cmd"; i += 2; continue }
      if (c == "\"") top--
      i++
      continue
    }
    if (ctx[top] == "cmd") {
      if (c == "\\") { i += 2; continue }
      if (c == "'")  { top++; ctx[top] = "sq";  i++; continue }
      if (c == "\"") { top++; ctx[top] = "dq";  i++; continue }
      if (c == "(")  { top++; ctx[top] = "cmd"; i++; continue }
      if (c == ")") top--
      i++
      continue
    }

    # normaal
    if (c == "\\") { uit = uit " "; i += 2; continue }
    if (c == "'")  { top++; ctx[top] = "sq";  uit = uit "\001"; i++; continue }
    if (c == "\"") { top++; ctx[top] = "dq";  uit = uit "\001"; i++; continue }
    if (c == "$" && n == "(") { top++; ctx[top] = "cmd"; uit = uit "\001"; i += 2; continue }
    uit = uit c
    i++
  }
  return uit
}

{
  regel = $0

  # --- heredoc-lichaam overslaan -------------------------------------------------------
  if (heredoc != "") {
    kaal = regel
    gsub(/^[ \t]+|[ \t]+$/, "", kaal)
    if (kaal == heredoc) heredoc = ""
    next
  }

  # --- volledige commentaarregel: nooit toestand aan ontlenen --------------------------
  if (top == 0 && vervolg == "" && regel ~ /^[ \t]*#/) next

  # --- regelvoortzetting: de staart is geen nieuw commando ------------------------------
  loopt_door = (regel ~ /\\[ \t]*$/)
  was_vervolg = (vervolg != "")
  was_string = (top > 0)
  vervolg = loopt_door ? "ja" : ""

  if (top == 0 && match(regel, /<<-?[ \t]*['"]?[A-Za-z_][A-Za-z_0-9]*['"]?/)) {
    d = substr(regel, RSTART, RLENGTH)
    sub(/^<<-?[ \t]*/, "", d)
    gsub(/['"]/, "", d)
    heredoc = d
    regel = substr(regel, 1, RSTART - 1)
  }

  regel = schoon(regel)

  # Stond deze regel nog middenin een string, dan begint hij niet op een commandopositie.
  if (was_string) next

  sub(/#.*/, "", regel)
  sub(/[ \t]*$/, "", regel)
  if (regel ~ /^[ \t]*$/) next

  # --- case: patronen zijn geen commando's ---------------------------------------------
  if (regel ~ /(^|[ \t;])case([ \t]|$)/) casediep++
  if (regel ~ /(^|[ \t;])esac([ \t;]|$)/) { casediep--; if (casediep < 0) casediep = 0 }
  if (casediep > 0 && regel ~ /\)/) {
    sub(/^.*\)/, "", regel)
    if (regel ~ /^[ \t]*$/) next
  }

  gsub(/&&|\|\||[;|&]/, "\n", regel)

  n = split(regel, delen, "\n")
  for (i = 1; i <= n; i++) {
    # Alleen het eerste deel van een vervolgregel hoort bij het commando hierboven; wat
    # ná een scheider staat begint wél een nieuw commando.
    if (i == 1 && was_vervolg) continue
    deel = delen[i]
    gsub(/^[ \t]+|[ \t]+$/, "", deel)
    if (deel == "") continue
    split(deel, woorden, /[ \t]+/)
    w = woorden[1]
    if (w ~ /^[a-zA-Z_][a-zA-Z_0-9-]*$/) print w
  }
}
