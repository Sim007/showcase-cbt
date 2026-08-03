# De site — wat er vaststaat voordat er ontworpen wordt

Dit is de brief voor het ontwerp van de site. Het beschrijft niet hoe hij eruitziet: het
legt vast wat er hoe dan ook geldt, welke gegevens er werkelijk zijn, en wat er uit een
ontwerpsessie terug moet komen om bruikbaar te zijn.

`docs/showcase-cbt.md` blijft de bron voor de showcase zelf. Hoofdstuk 1 hieronder vat
samen wat nodig is om dit document buiten de repository te kunnen lezen; bij verschil wint
`showcase-cbt.md`.

---

## 1. Waar dit over gaat

Een showcase van contract-based testing: één werkend voorbeeld per grenstype, draaiend op
één laptop. Het systeem is fictief.

**Twee deelsystemen, één grens.** Order (consumer) roept Payment (provider) aan over REST.
Later komen Notification en Portal erbij, en daarmee async, SOAP en front-ends.

| Term | Betekenis |
|---|---|
| grens | interface waar eigenaarschap wisselt tussen deelsystemen |
| contract | de gepubliceerde specificatie van een grens |
| deelsysteem | wat één team bezit en zelfstandig naar productie brengt |
| service | één bouwbaar en deploybaar onderdeel: een microservice of een micro-frontend |
| contractverificatie | toetsing van een implementatie aan de gepubliceerde spec |

**Drie omgevingen.** Een efemere CI-omgeving per deelsysteem, waar de buren als stub uit de
spec staan; Test, waar alle deelsystemen echt draaien maar de buitenwereld niet; Acceptatie,
met de koppelingen naar buiten erbij.

**Drie versieniveaus, en ze bewegen los.** De contractversie hoort bij de grens en staat in
het register. De microserviceversie komt uit de pom en zit in de image. De deelsysteemversie
pint welke microserviceversies samen naar een omgeving gaan. Alle drie staan op het
info-endpoint.

**Wat contracttesten toevoegt.** Een register waarin de spec per versie gepubliceerd staat,
een diff-gate bij publicatie, een stub die uit de spec wordt gegenereerd, contractverificatie
aan beide kanten van de grens, en een drift-check. Wat het wegneemt: e2e-tests die alleen de
structuur van een grens aantoonden, afstemming over deployvolgorde, en handgeschreven mocks
van de buur.

**Waar het naartoe werkt:** een squad kan releasen op testbewijs, zonder met iemand een
deployvolgorde af te spreken.

---

## 2. Waarom de site er is

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

## 3. Harde eisen

Deze negen staan niet ter discussie in een ontwerpsessie. Een ontwerp dat er niet in past,
kan hier niet landen. Elke eis is te controleren, en daarom staat erbij hoe je ziet dat hij
geschonden is.

| # | Eis | Geschonden zodra |
|---|---|---|
| 1 | Elk gegeven komt uit echte toestand | een script een uitkomst aan de pagina doorgeeft in plaats van dat de pagina hem afleest |
| 2 | Ontbrekend blijft ontbrekend | een onbereikbare bron een cel oplevert die op "goed" lijkt, of een laatst bekende waarde |
| 3 | De site bewaart niets | de pagina iets toont dat nergens anders meer te vinden is |
| 4 | Openen veroorzaakt geen netwerkverkeer | er een externe `script`, `link`, `@font-face` of `fetch` in staat |
| 5 | Eén script in `ci/` maakt hem, ook zonder demo | je de demo moet draaien om de pagina te krijgen |
| 6 | Docker en bash zijn genoeg | er een buildstap, een runtime of een `npm install` voor de pagina zelf bij komt |
| 7 | De pagina voert niets uit | er een knop op staat die deployt, publiceert of test |
| 8 | Geen credentials en geen interne paden in de uitvoer | er een token of een pad als `/Users/...` in de HTML belandt |
| 9 | Hij wordt niet gecommit | `git status` hem toont |

**Waarom 1 en 2 zwaarder wegen dan de rest.** Zodra de pagina toont wat iemand bedoelde in
plaats van wat er is, laat hij precies het probleem zien dat deze showcase bestrijdt — en
hij doet het onzichtbaar. Dat is dezelfde fout als een stub die niet uit de spec komt, en
hij is net zo moeilijk te betrappen. Eis 3 hoort daarbij: wat je niet bewaart, kan niet
stilletjes verouderen.

Eis 4 tot en met 9 komen uit `CLAUDE.md` en gelden voor de hele repository. De bestaande
pagina (`ci/rapport-html.sh`) voldoet eraan en is pure bash — dat is het bewijs dat het kan,
en meteen de lat.

---

## 4. Site of systeem

De site **leidt af en bewaart niet**. Zolang dat zo is, kan hij niet verouderen en niet
liegen: weggooien mag altijd, regenereren kost een run. Dat is een keuze en geen tussenstap.

| | Site | Systeem |
|---|---|---|
| Kennis | leidt alles af uit drie bronnen | bewaart zelf iets |
| Weggooien | mag, altijd | nee, er zit iets in dat nergens anders staat |
| Eigenaar | het script | een squad, met een pipeline en een levenscyclus |
| Fout | zichtbaar leeg | stil verouderd |

**Drie dingen maken er een systeem van, en alle drie zijn redelijk:**

1. *"Was het gisteren ook groen?"* — historie over runs heen vraagt opslag; het rapport gaat
   over één run.
2. *"Ik wil om tien uur kijken zonder iets te draaien."* — een gegenereerde pagina bestaat
   pas ná een run; altijd bereikbaar zijn vraagt iets dat draait en periodiek ververst.
3. *Meerdere omgevingen tegelijk in beeld* — dan heeft de generator netwerktoegang tot elke
   omgeving, en daarmee een plek om te staan en credentials om te beheren.

Voor deze showcase raakt geen van drieën ons: alles draait op één laptop en een run duurt
minuten. Een ontwerpsessie mag deze kant verkennen, maar niet ongemerkt kiezen.

**Wordt hij het wél, dan is hij een deelsysteem als elk ander** — en dat is geen probleem
maar een aardigheid. Hij wordt dan consumer van het register: hij pint een contractversie op
de registry-API, krijgt een `grenzen.env`, en zijn eigen pipeline verifieert hem tegen die
spec. Het dashboard ondergaat dan het mechanisme dat het toont. Dat is een sterkere
demonstratie dan wat hier nu staat, en een reden om die stap ooit te zetten — maar niet in
hoofdstuk 1.

---

## 5. Welke gegevens er werkelijk zijn

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
van een omgeving (open punt O2), monitoring op productie (O8), en historie over runs heen.

---

## 6. Wie er kijkt

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

## 7. Wat het niet moet worden

| Niet | Waarom |
|---|---|
| een besturingspaneel met knoppen die pipelines starten | de site kijkt; hij grijpt niet in. Anders wordt zijn eigen uitvoer zijn invoer |
| monitoring | dat is F4 en vraagt een productielaag; de info-endpoints zijn hier een surrogaat (O8) |
| iets dat geïnstalleerd of gebouwd moet worden | Docker en bash zijn de vereisten en dat blijft zo |
| een pagina die groen toont als een bron ontbreekt | eis 2 |
| een tweede plek waar de waarheid staat | eis 3: de site leidt af, hij bewaart niet |

---

## 8. Het groeipad

**Nu: één pagina.** Boven wat er op dit moment draait, eronder wat er in deze run is
gebeurd. Eén link, één venster, ververst zichzelf tijdens een run — dat werkt al.

**Later: een site.** Een pagina per deelsysteem, een pagina per grens. De testsoorten als
kolommen, zodat een UI-test er later bij komt als een kolom en niet als een verbouwing. Dat
is de reden om nu al datagedreven te bouwen in plaats van de blokken vast te metselen.

De volgorde: eerst de versiematrix, dan de gate-keten, dan de fase-indicator, dan de
testsoorten. Elk stuk is los bruikbaar; niets ervan wacht op het volgende.

---

## 9. Wat een ontwerpsessie moet opleveren

Bruikbaar:

- de vragen uit §6, aangevuld en aangescherpt, met wie ze stelt en hoe vaak
- welke pagina's er zijn en wat er op elke pagina het eerst opvalt
- wat iemand doet nadat hij het antwoord heeft gezien — dat bepaalt wat er naast moet staan
- waar een lege of rode toestand terechtkomt, en hoe je ziet dat het leeg is en niet goed

Niet bruikbaar, want het botst met §3 of het doe ik hier:

- een keuze voor een framework, buildstap of componentbibliotheek
- een ontwerp dat een API of database veronderstelt
- kleuren, typografie en opmaak in detail
