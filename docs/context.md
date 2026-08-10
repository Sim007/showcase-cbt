# Context — showcase-CBT

> Versie 2.0.0

Dit document bestaat uit twee delen.

**Deel A — de showcase.**
De fictieve organisatie, het domein en de scenario's. Geen bestaande organisatie, geen klant, geen
bestaande werkwijze — en ook geen verzinsel. Een uitgewerkt voorbeeld, gemaakt om getoond te
worden.

**Deel B — de realisatie.**
Hoe deze showcase gebouwd wordt: welke squads, wie er werkt, en hoe dat werk loopt.

---

# Deel A — De showcase

## Kernidee

**Showen is beter dan ideeën en documenten.**
Deze showcase bestaat om contract-based testing aantoonbaar te maken: één werkend voorbeeld per
grenstype, zodat het mechanisme getóónd wordt in plaats van beschreven. Dat is ook de meetlat —
leidt een document of discussie niet tot iets dat je kunt laten zien, dan is het een omweg.

Dit is showcasecode, geen productiecode.

## Aannames

De showcase-organisatie heeft drie dingen op orde. Niet omdat dat vanzelfsprekend is, maar omdat
contract-based testing zonder die basis niet landt. Ontbreekt er één, dan is de showcase nog steeds
te volgen — maar dan vraagt dát het eerst aandacht.

**Het deelsysteem is de eenheid.**
Eigenaarschap, uitrol en toetsing hangen aan het deelsysteem: één feature squad, één deelsysteem,
één pipeline. Alle software draait in containers op een Kubernetes-platform dat één dedicated
platform squad levert.

**Software wordt continu voortgebracht.**
CI/CD-pipelines zijn de enige weg naar productie. Testen is geen fase aan het eind maar een
doorlopende activiteit — in de pipeline, bij elke wijziging.

**Squadautonomie binnen kaders.**
De tribe stelt de standaarden, de squads zijn daarbinnen autonoom. Standaardisatie is de norm en
afwijken kan, mits onderbouwd: comply or explain.

### Waarom een contract, en geen afspraak

Het gaat om communicatie. **Binnen** een squad regel je afstemming zelf: je deelt context, je
overlegt, en wat je stukmaakt herstel je in dezelfde codebase. **Tussen** squads werkt dat niet —
andere backlog, andere prioriteiten, geen gedeelde context.

Een afspraak is daarvoor te zwak. Hij staat in een document, een thread of iemands hoofd. Hij
verwatert, en als hij gebroken wordt merkt niemand dat op het moment zelf — meestal pas verderop in
de keten, bij iemand anders.

Een contract is machinaal toetsbaar. Breekt het, dan valt de pipeline om: bij de squad die het
brak, vóórdat iemand anders er last van heeft. Een afspraak breekt stil, een contract breekt luid.

Bij drie squads kom je nog een eind met afspraken. Bij tien niet meer.

### Het systeem in productie telt

Wat telt is het systeem in productie, en dat is een triberesultaat. Elke squad levert daaraan een
bijdrage; geen enkele squad levert het geheel. Daar horen kaders bij: een squad kan niet los van de
andere bepalen wat over een grens gaat.

Een gate die een pipeline stopt houdt een squad op, maar voorkomt schade aan het geheel. Dat is
alleen houdbaar als er op triberesultaat wordt gestuurd. Gaat de sturing per squad, dan wordt
comply or explain een ontsnappingsroute en ontstaan er routes om de gate heen. De sturing bepaalt
of de kaders standhouden.

---

## 1. People — de organisatie

### Waarom een showcase-organisatie

Een showcase-organisatie kan aan iedereen getoond worden: geen NDA, geen klantgegevens, geen
herkenbare interne situatie. Dat maakt de showcase bespreekbaar: niet "zo doen wij het", maar "zo
zou het kunnen werken".

### Structuur

Een enterprise met daarbinnen één multidisciplinaire **tribe**:

- **10 à 20 feature squads.** Elke squad is eigenaar van een of meer deelsystemen.
- **Eén dedicated platform squad** — CI/CD en het Kubernetes-platform.

### Deelsystemen en eigenaarschap

De showcase licht twee squads uit:

| Deelsysteem | Eigenaar |
|---|---|
| Payment | Squad A |
| Order | Squad B |
| Notification | Squad B |

De grens ligt bij het **deelsysteem**. Payment heeft een grens, Order heeft er een, Notification
heeft er een — en die grens bestaat los van wie er vandaag aan de andere kant staat. Dat Order en
Notification nu bij dezelfde squad liggen verandert daar niets aan: deze verdeling zou morgen
anders kunnen zijn zonder dat er één contract wijzigt.

Payment laat meteen zien waarom provider en consumer rolwoorden zijn: aan de payments-api-grens is
het provider, aan de notification-grens ook, en aan de grens met de externe betaalprovider is het
consumer. Dezelfde squad, dezelfde dag, drie grenzen, twee rollen.

---

## 2. Product — het domein

### Wat het product doet

- Ondersteunt een aantal **end-to-end businessprocessen**.
- Bedient een **beperkt aantal doelgroepen**.
- Draait volledig in **containers**.

### Testomgevingen

Er zijn drie testomgevingen: **CI**, **Test** en **Acceptatie**.

**CODE is geen omgeving.** Het is wél een kolom op de showcase-website. Unittesten en
integratietesten van een microservice hebben geen omgeving nodig — die draaien op de code zelf.

**Test en Acceptatie zijn volledig geïntegreerde omgevingen**, met deelsystemen die Release
Candidate zijn.

### Testsoorten

Een testsoort is iets anders dan een omgeving. Dezelfde testsoort kan op meerdere omgevingen
draaien.

> Nog aan te vullen: de testsoorten zelf.

### Deelsystemen

Een scenario bestaat uit een of meer deelsystemen. **Elk deelsysteem heeft zijn eigen pipeline.**
Die pipeline stopt zodra een stap mislukt of een gate niet gehaald wordt. Elk deelsysteem heeft één
eigenaar: een feature squad.

**Showcase-website is ook een deelsysteem als elk ander.** Het is niet alleen het venster waardoor
je kijkt, maar ook een van de dingen waar je naar kijkt.

### Stappen

- **Actie** — voert iets uit.
- **Gate** — toetst of er verder gegaan mag worden.

Elke stap heeft een uniek nummer, doorlopend over het hele scenario.

### De grens

Een **grens** is een interface tussen deelsystemen, waar eigenaarschap wisselt. Dat is een
organisatorisch criterium, geen technisch: niet elke koppeling is een grens, en een grens verdwijnt
niet doordat twee deelsystemen dezelfde technologie of runtime delen.

Een contract heeft twee kanten, maar één eigenaar: **het providende deelsysteem bezit het
contract.** Daarom kan de consumerkant wisselen zonder dat het contract verandert, en daarom
bepaalt de provider wat er over de grens gaat. Provider-driven is geen stijlkeuze maar een gevolg
van waar het eigendom ligt.

Het eigendom hangt aan het deelsysteem, niet aan de squad. Een squad is eigenaar van een
deelsysteem, maar dat eigenaarschap kan verhuizen. Elke deelsysteemgrens is daarom een
contractgrens — ook als twee deelsystemen vandaag toevallig bij dezelfde squad liggen.

### Grenstypen

Een **grenstype** is de aard van de koppeling op een grens: waar hij ligt en hoe het verkeer erover
loopt. Het type bepaalt welk soort spec het contract vastlegt en welke toets erop staat.

| Grenstype | Verkeer | Contract |
|---|---|---|
| Binnen één deelsysteem | intern, geen grens | *n.v.t. — wel het mechanisme* |
| Tussen deelsystemen, synchroon | REST | OpenAPI |
| Tussen deelsystemen, asynchroon | queue of topic | AsyncAPI |
| Extern | SOAP | WSDL/XSD, van buiten gegeven |

De showcase belooft **één werkend voorbeeld per grenstype**. Die belofte is na te lopen tegen de
scenariotabel verderop: elk type komt daar precies één keer voor.

### Toetsen en afleiden

**Toetsen ligt bij showcase-CBT, afleiden bij showcase-website.** Showcase-CBT draait de stappen,
toetst de gates en meldt de uitkomsten via de stream. De website toetst niets. Dat is geen
werkverdeling maar een principe: de gate hoort in de pipeline, bij de squad die de wijziging maakt.
Ligt de toets in het venster waardoor je kijkt, dan demonstreert de showcase iets anders dan hij
beweert.

**De rapportlogica ligt bij showcase-website.** Showcase-CBT levert stamdata (scenario, omgevingen,
deelsystemen, stappen) plus een live-stream met gebeurtenissen. De website leidt daaruit zelf de
deelsysteem-status en het rapport af, per scenario en per deelsysteem.

| | Wie |
|---|---|
| Toetsen — is deze gate gehaald? | showcase-CBT |
| Afleiden — wat betekent dat voor het deelsysteem en het rapport? | showcase-website |

### Het proces dat de showcase belicht

Er is **één proces**: hoe een feature in productie komt. Showcase-CBT belicht daarbinnen het
**testproces** — hoe testen eruitziet mét contract-based testing. Het vertrekpunt is de situatie
zónder: dat is scenario 00. Elk volgend scenario laat zien wat CBT daaraan verandert.

### Scenario's

Drie soorten scenario's staan door elkaar in één reeks: die over een **grenstype**, die over de
**levenscyclus** van één contract, en die over de **weg naar productie** als geheel.

| Nr | Titel | Onderwerp | Grenstype | payments-api |
|---|---|---|---|---|
| 00 | Startsituatie | De weg naar productie zónder contracttesten | — | — |
| 01 | Basis (API) | Order → Payment, REST, schema-first | synchroon | 1.0.0 |
| 02 | Wijziging zonder breuk | Additieve wijziging naast de bestaande versie | — | 1.1.0 |
| 03 | Breaking wijziging | Twee majors naast elkaar in dezelfde runtime | — | 2.0.0 |
| 04 | Acceptatie | De gebruikersflow over de volledige keten | — | |
| 05 | Sunset | Een oude major netjes uit de runtime halen | — | |
| 06 | Async | Payment → Notification, via AsyncAPI | asynchroon | |
| 07 | SOAP | Een externe betaalprovider, WSDL/XSD | extern | |
| 08 | FE | Frontend binnen één deelsysteem: geen deelsysteemgrens, wél het mechanisme | binnen deelsysteem | |
| 09 | Shell | *nog aan te vullen* | *nog aan te vullen* | |

**Elk scenario is herhaalbaar.** payments-api 1.0.0 moet op elk moment terug te zetten zijn; de
versies in de tabel liggen vast als inhoud van de showcase.

---

# Deel B — De realisatie

Eén grens uit Deel A bestaat hier ook echt. Showcase-website is in de showcase een deelsysteem als
elk ander, met een deelsysteemgrens als elke andere. In de realisatie is het een aparte repo met
een eigen squad — dezelfde grens, maar met eigenaarschap dat werkelijk wisselt. In Deel A tonen we
die grens; hier leven we hem.

## De squads

Er zijn twee squads, elk met een eigen repo en een eigen deelsysteem.

**Squad 1 — showcase-CBT.** `Sim007/showcase-cbt`, MIT. Bevat de showcase en alle documentatie in
`docs/`. Deelsystemen staan in `deelsystemen/` op de hoofdmap; genummerde scenariomappen bevatten
alleen tests, compose, demoscript en README. Gedeeld en dus één keer aanwezig: `ci/`, `contracts/`,
`playwright/`, `deelsystemen/`.

**Squad 2 — showcase-website.** `Sim007/showcase-website`. Coördinatie over een grens waar het
eigenaarschap echt wisselt is niet na te bootsen aan één kant van de tafel.

Eén PO voor beide squads. Elke squad is een eigen Claude Code-omgeving: geen gedeelde context, geen
gedeelde codebase, alleen het contract op de grens ertussen.

## Wat die grens oplevert

Wat hier gebeurt is niet herhaalbaar en dus geen scenario. De opbrengst landt in `besluiten.md §
Geleerd`: wat coördinatie over een echte grens kost — afstemming, blokkades, aannames die pas aan
de andere kant sneuvelen. De scenario's tonen dát het mechanisme werkt; die notities tonen wat het
kost om het over een echte grens te doen.

Komt showcase-website bij squad 1, dan blijft de grens bestaan, maar wordt hij geleverd en beheerd
door squad 1.

## Rollen

| Rol | Wie | Doet |
|---|---|---|
| **PO** | de consultant | Beslist. Bepaalt wat er gebouwd wordt en in welke volgorde, voor beide squads. |
| **Hulplijn** | Claude (chat) | Spart met de PO, zoekt hiaten en tegenstrijdigheden, en schrijft de prompt. Beslist niet, en ziet de codebase bewust niet. |
| **Squad** | Claude Code | Bouwt. Autonoom in het *hoe*, en praat terug voordat er gebouwd wordt. |

De hulplijn ziet de code niet en de squad ziet het gesprek niet. Dat is geen beperking maar de
opzet: de squad kan niet meebewegen met wat er in de chat is bedacht, en de hulplijn kan niet
redeneren vanuit code die hij zelf heeft gezien. Wat tussen de twee moet oversteken, moet
opgeschreven worden — en juist dáár sneuvelen aannames.

## Flow

Deze flow is zelf een voorbeeld: zo kun je met AI bouwen zonder de regie kwijt te raken.

1. **De PO bepaalt wat en wanneer.** Wat er gebouwd wordt en in welke volgorde, voor beide squads.
   Dit is de enige stap waar besloten wordt.
2. **De PO spart met de hulplijn en laat de prompt schrijven.** Eerst het gesprek — hiaten,
   tegenstrijdigheden, wat er nog niet klopt. Pas daarna de prompt.

   Heeft een vraag technisch gewicht, dan gaat er eerst een **verkenning** naar de squad: alleen
   lezen, niet bouwen, en een samenvatting terug die PO en hulplijn kunnen lezen zonder de code te
   zien. Op die samenvatting wordt gerefined, en pas daarna volgt de bouwprompt.
3. **De squad reageert vóórdat hij bouwt.** Een opdracht die technisch onhandig of onhaalbaar is,
   wordt ter discussie gesteld. Dat is geen beleefdheid maar een verplichting: een squad die alles
   uitvoert wat gevraagd wordt, is geen squad maar een tekstverwerker.
4. **De PO legt die reactie terug bij de hulplijn.** Wat de squad terugmeldt is invoer voor een
   nieuwe ronde sparren — waarna de PO beslist of de opdracht wijzigt.

Vervolgens bouwt de squad en levert een technische samenvatting terug: wat gebouwd, welke bestanden
geraakt, welke keuzes gemaakt. Zonder die samenvatting werken PO en hulplijn op een verbeelde
codebase.

Wat de flow bij elkaar houdt: de AI schrijft, bouwt en spart — maar beslist nergens. Elke ronde
komt terug bij de consultant.

Voor de consultant is dit een way of working met AI voor deze showcase.

## Documenten

Zodra een document in de repo staat is dát de bron: wijzigingen landen in de repo, niet in een
chat.

- `context.md` — dit document.
- `besluiten.md` — waar besluiten landen, met datum. Bevat ook het hoofdstuk Geleerd. Bij twijfel
  gaat dit document voor op wat in een chat is gezegd.
- `usecases-showcase-website.md` — usecases, benodigde data, NFR's, MVP-indeling.

## Open punten

- **Testsoorten** — de terminologielijst van de tribe waarvoor deze showcase gemaakt wordt is
  leidend, en wordt in Deel A overgenomen zodra hij beschikbaar is.
- **Versiebereik** van het contract op de grens tussen de twee squads, zolang er nog gebroken mag
  worden.
- **payments-api-versies** bij scenario 04 en 05.
- **Scenario 09 (Shell)** — onderwerp en grenstype.
- **Verwijzing van stap naar grens** — draagt een stap een verwijzing naar de grens die bij een
  gate bewaakt wordt? Zonder die verwijzing kan er alleen per deelsysteem gerapporteerd worden,
  niet per grens. Zit in `scenario-api`.
