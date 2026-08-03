# De site — wat er vaststaat voordat er ontworpen wordt

Dit is de brief voor het ontwerp van de site. Het beschrijft niet hoe hij eruitziet: het
legt vast wat er hoe dan ook geldt, welke gegevens er werkelijk zijn, en wat er terug moet
komen uit een ontwerpsessie om bruikbaar te zijn.

`docs/showcase-cbt.md` blijft de bron voor de showcase zelf. Dit document gaat alleen over
de site en verwijst waar het kan.

---

## 1. Waarom de site er is

Twee aanleidingen, en de tweede staat los van testen.

**Waarnemen werkt alleen als de waarneming zichtbaar is.** De opzet vervangt vooraf
voorspellen door achteraf vaststellen. Een rood vlak dat niemand ziet, is dan geen signaal
maar een gemiste meting.

**"Welke interfaces biedt jouw deelsysteem?" is nu onbeantwoordbaar.** Niet uit onwil, en
niet omdat squads geen overzicht hebben: er is geen plek waar het staat. Eén register maakt
er een opzoekvraag van. Pas dan is een tribe-breed beeld mogelijk zonder dat iemand het bij
elkaar hoeft te bellen. Autonomie zonder dat beeld is onzichtbaarheid.

Daaruit volgt de belangrijkste eis: **de site is een venster, geen presentatie.** Hij toont
wat er is, ook als dat rood, leeg of tegenstrijdig is.

---

## 2. De regel die niet onderhandelbaar is

> Elk gegeven op de site komt uit echte toestand. Nooit uit een demoscript.

| Gegeven | Bron |
|---|---|
| welke versies draaien waar | de info-endpoints van de draaiende services |
| welke grenzen bestaan, wie serveert en wie pint | het register |
| welke gates gepasseerd zijn, wanneer, met welke uitkomst | het rapport dat de pipelines schrijven |

Zodra een script een uitkomst *vertelt* in plaats van dat de site hem *afleest*, toont de
site wat iemand bedoelde in plaats van wat er is. Dat is dezelfde fout als een stub die
niet uit de spec komt, en hij is net zo moeilijk te zien.

Gevolg: een lege of onbereikbare bron levert een lege of onbereikbare cel — geen aanname,
geen laatst bekende waarde, geen streepje dat op "goed" lijkt.

---

## 3. Harde randvoorwaarden

Deze komen uit `CLAUDE.md` en gelden voor de hele repository. Een ontwerp dat er niet in
past, kan hier niet landen.

| | |
|---|---|
| Vereisten | Docker en bash, meer niet. Linux, macOS, Windows via WSL2 |
| Zelfstandig | geen CDN, geen externe fonts, scripts of stylesheets — alles inline, zodat doorsturen werkt |
| Gegenereerd | door een script in `ci/`, aangeroepen vanuit een pipeline. Geen logica in yaml |
| Dependencies | zo min mogelijk; een library alleen met één regel in de commit waarom hij nodig is |
| Gereedschap | extern gereedschap draait als container via `ci/lib/tools.sh`, op een vastgepinde tag |
| Niet committen | de gegenereerde pagina is uitvoer van een run en hoort in `.gitignore` |
| Geen secrets | niet in code, yaml of compose |
| Scripts | `set -euo pipefail`, POSIX-compatibel, geen GNU-specifieke vlaggen |

De bestaande pagina (`ci/rapport-html.sh`) voldoet hieraan en is pure bash. Dat is het
bewijs dat het kan, en meteen de lat.

---

## 4. Welke gegevens er werkelijk zijn

Een ontwerp dat velden veronderstelt die er niet zijn, kost een verbouwing. Dit is wat er
vandaag uit te halen valt.

**Info-endpoint** — `GET /actuator/info` per service, echt antwoord:

```json
{"deelsysteem":{"naam":"order","versie":"1.0.0"},
 "contract":{"groep":"order-payment","artifact":"payment-api","pin":"1.0.0"},
 "build":{"artifact":"order-api","version":"1.0.0","time":"2026-08-02T09:17:42.878Z","group":"cbt"}}
```

Een provider heeft `contract.serveert` in plaats van `contract.pin`. Beide zijn
komma-gescheiden strings, want een provider serveert vanaf hoofdstuk 3 twee majors naast
elkaar. Alleen `health` en `info` staan open — er is geen ander endpoint om uit te lezen.

**Register** — Apicurio v3 op `/apis/registry/v3`, zonder authenticatie (bewuste
vereenvoudiging voor de demo). Beschikbaar: groepen, artefacten, versies per artefact, de
inhoud van een versie, en de compatibiliteitsregel. Wie een contract *pint* staat er niet
in — dat komt van de kant van de consumer, uit zijn info-endpoint.

**Rapport** — `<hoofdstuk>/rapport/rapport-cbt-<nr>.md`, een markdowntabel met per regel:
tijd (UTC), onderdeel, stap, uitkomst (`groen` / `**ROOD**` / `**oordeel**`),
bijzonderheden.

**Wat er niet is, en niet stilzwijgend verzonnen mag worden:** de verwachte samenstelling
van een omgeving (open punt O2), monitoring op productie (O8), en historie over runs heen —
het rapport gaat over één run.

---

## 5. Wie er kijkt

Dit is wat een ontwerpsessie moet aanscherpen: de vragen en wie ze stelt. De opmaak volgt
daaruit, niet andersom.

| Wie | Vraag | Beantwoordbaar met wat er is? |
|---|---|---|
| squadlid | klopt mijn kant van elke grens, en mag ik dus releasen? | ja — rapport |
| squadlid | welke versie serveert mijn buur nu, en op welke hang ik? | ja — info-endpoints |
| squadlid van de provider | wie hangt er aan de versie die ik wil opruimen? | ja — register plus de pins van alle consumers |
| architect / tribe | welke grenzen zijn er, en wie staat waar? | ja — register |
| wie het niet kent | wat gebeurt hier eigenlijk, en waar zijn we? | ja — rapport plus fase |
| release manager | draait op Test de samenstelling die er hoort te draaien? | **nee** — O2 staat open |

Die laatste regel hoort zichtbaar te blijven als een lege plek, niet weggelaten te worden.
Een ontbrekende controle die je ziet is beter dan een die niemand mist.

---

## 6. Wat het niet moet worden

| Niet | Waarom |
|---|---|
| een besturingspaneel met knoppen die pipelines starten | de site kijkt; hij grijpt niet in. Anders wordt zijn eigen uitvoer zijn invoer |
| monitoring | dat is F4 en vraagt een productielaag; de info-endpoints zijn hier een surrogaat (O8) |
| iets dat geïnstalleerd of gebouwd moet worden | Docker en bash zijn de vereisten en dat blijft zo |
| een pagina die groen toont als een bron ontbreekt | zie de regel in §2 |
| een tweede plek waar de waarheid staat | de site leidt af, hij bewaart niet |

---

## 7. Het groeipad

**Nu: één pagina.** Boven wat er op dit moment draait, eronder wat er in deze run is
gebeurd. Eén link, één venster, ververst zichzelf tijdens een run — dat werkt al.

**Later: een site.** Een pagina per deelsysteem, een pagina per grens. De testsoorten als
kolommen, zodat een UI-test er later bij komt als een kolom en niet als een verbouwing.
Dat is de reden om nu al datagedreven te bouwen in plaats van de drie blokken vast te
metselen.

De volgorde: eerst de versiematrix, dan de gate-keten, dan de fase-indicator, dan de
testsoorten. Elk stuk is los bruikbaar; niets ervan wacht op het volgende.

---

## 8. Wat een ontwerpsessie moet opleveren

Bruikbaar:

- de vragen uit §5, aangevuld en aangescherpt, met wie ze stelt en hoe vaak
- welke pagina's er zijn en wat er op elke pagina het eerst opvalt
- wat iemand doet nadat hij het antwoord heeft gezien — dat bepaalt wat er naast moet staan
- waar een lege of rode toestand terecht komt, en hoe je ziet dat het leeg is en niet goed

Niet bruikbaar, want het botst met §3 of het doe ik hier:

- een keuze voor een framework, buildstap of componentbibliotheek
- een ontwerp dat een API of database veronderstelt
- kleuren, typografie en opmaak in detail
