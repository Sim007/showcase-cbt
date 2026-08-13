# Schrijft het eerste woord van elke commandopositie in een shellscript, één per regel.
#
# Gebruikt door ci/controle-gates.sh voor de oplosbaarheidstoets: elk woord dat hier
# uitkomt, moet straks ergens naar oplossen. Dit bestand doet het lezen, de toets doet het
# oordelen.
#
# Dit is een benadering en geen shell-parser. Wat er niet in zit: commando's binnen $(),
# en commando's waarvan de naam pas bij expansie ontstaat. Die vallen buiten beeld en
# leveren dus geen valse melding op — de toets is smal met opzet, want een gate die ruis
# produceert wordt uitgezet of krijgt een negeerlijst, en dan bewaakt hij niets meer.
#
# Wat er wel in zit, kostte vier rondes:
#
#   1  Een meerregelige echo leest zonder quote-toestand als een rij commando's, en levert
#      tientallen Nederlandse woorden op als "onvindbaar commando".
#   2  Een apostrof in Nederlands commentaar ("scenario's") opent een string die nooit
#      sluit. Daarom gaan volledige commentaarregels eruit vóór de quote-toestand bepaald
#      wordt, en niet erna.
#   3  Een case-patroon (`nee|off)`) staat op een commandopositie en is er geen.
#   4  Een commando dat als gequoot pad wordt aangeroepen — "${CBT_ROOT}/ci/x.sh" arg —
#      verdwijnt bij het weghalen van de string, waarna zijn eerste argument als commando
#      wordt gelezen. Vandaar een marker op de plek van elke string in plaats van een
#      spatie: het eerste woord is dan de marker, en die telt niet mee.

BEGIN { heredoc = ""; instring = ""; casediep = 0; vervolg = "" }

{
  regel = $0

  # --- heredoc-lichaam overslaan -------------------------------------------------------
  if (heredoc != "") {
    kaal = regel
    gsub(/^[ \t]+|[ \t]+$/, "", kaal)
    if (kaal == heredoc) heredoc = ""
    next
  }

  # --- volledige commentaarregel: nooit quote-toestand aan ontlenen ---------------------
  if (instring == "" && vervolg == "" && regel ~ /^[ \t]*#/) next

  # --- doorlopende string afmaken ------------------------------------------------------
  if (instring != "") {
    p = index(regel, instring)
    if (p == 0) next
    regel = substr(regel, p + 1)
    instring = ""
  }

  # --- regelvoortzetting: de staart is geen nieuw commando ------------------------------
  # Eerst onthouden of déze regel doorloopt, daarna pas beslissen of de vorige dat deed.
  loopt_door = (regel ~ /\\[ \t]*$/)
  was_vervolg = (vervolg != "")
  vervolg = loopt_door ? "ja" : ""

  gsub(/\\./, "", regel)
  sub(/\\[ \t]*$/, "", regel)

  if (match(regel, /<<-?[ \t]*['"]?[A-Za-z_][A-Za-z_0-9]*['"]?/)) {
    d = substr(regel, RSTART, RLENGTH)
    sub(/^<<-?[ \t]*/, "", d)
    gsub(/['"]/, "", d)
    heredoc = d
    regel = substr(regel, 1, RSTART - 1)
  }

  # --- gesloten strings vervangen door een marker, een openstaande onthouden ------------
  schoon = ""
  rest = regel
  while (1) {
    e = index(rest, "'")
    d = index(rest, "\"")
    if (e == 0 && d == 0) { schoon = schoon rest; break }
    if (e != 0 && (d == 0 || e < d)) { q = "'"; p = e } else { q = "\""; p = d }
    schoon = schoon substr(rest, 1, p - 1) "\001"
    rest = substr(rest, p + 1)
    sluit = index(rest, q)
    if (sluit == 0) { instring = q; break }
    rest = substr(rest, sluit + 1)
  }
  regel = schoon

  sub(/#.*/, "", regel)
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
