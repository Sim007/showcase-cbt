# Stub van showcase-CBT

Uitpakken en starten. Geen Docker, geen JDK, geen `npx`, en na het uitpakken geen netwerk.

```sh
tar -xzf stubbundel-0.11.1.tgz
cd bundel
node stub.js
```

Luistert op **8090**, of op `POORT=9000 node stub.js`.

**Welke specversies hierin zitten, staat in `manifest.json`** — met de checksum van elk van
de twee. Haal je de spec ook los uit de release, dan is dat te vergelijken:

```sh
sha256sum openapi.yaml          # macOS: shasum -a 256 openapi.yaml
cat manifest.json
```

Komen die niet overeen, dan hoort deze bundel bij een andere versie van de spec dan je denkt.
Het bundelnummer zegt dat niet — de twee contracten hebben hun eigen levenscyclus en bewegen
los van elkaar en van de bundel.

---

## Wat erin zit

| | |
|---|---|
| `openapi.yaml` · `asyncapi.yaml` | de twee contracten, zoals gepubliceerd |
| `manifest.json` | welke artifactversies erin zitten, met de checksum van elk |
| `stub.js` | de stub — REST en stream in één proces |
| `stub-data.json` | de routes, gegenereerd uit `openapi.yaml` |
| `runs/*.jsonl` | drie fixtures, plus de opgenomen runs — zie hieronder |
| `scenarios/*.json` | de stamdata per scenario: welke stappen er zijn |
| `schemas/berichten-ontvangst.json` | de payloadschema's, voor **inkomende** berichten |
| `node_modules/` | ajv en ajv-formats, meer niet |

Alles is uit de gepubliceerde specs gegenereerd. Er zit niets in wat niet uit het contract
komt, en niets is met de hand aangeraakt.

---

## Wat hij wél toetst, en wat niet

**REST: elke requestbody gaat langs het schema uit de spec.** Stuur je een veld dat er niet
in staat, dan krijg je een 400 met wat er mis is. Dat is de reden om hiertegen te bouwen in
plaats van tegen een zelfgeschreven mock: die bevestigt wat de schrijver dacht, deze houdt
je aan wat er is afgesproken.

**De stream toetst niets.** De drie fixtures worden afgespeeld zoals ze zijn vastgelegd — er
zit geen validatie tussen. Dat hoeft ook niet: ze zijn bij het maken al tegen hun
payloadschema gehouden. Maar het betekent dat je er niet op moet vertrouwen om je eigen
fouten te vangen.

---

## De verbinding blijft open

Sinds `run-stream 0.11.0`. **Eén verbinding per sessie, niet per run** — en jullie sluiten
hem, niet wij.

```
GET  /v1/runs/stream     verbinden; blijft open
POST /v1/runs            start een run over die verbinding
POST /v1/runs            tijdens die run: 409, met het runId van de run die loopt
```

**Bij verbinden komt eerst een momentopname.** Loopt er niets, dan draagt die `run: null`.
Dat is de normale begintoestand van een sessie en geen randgeval — je krijgt hem elke keer
als je opent voordat je iets start.

**De 201 op `POST /v1/runs` draagt het `runId` van de run die dan begint**, en dat is
hetzelfde nummer als op de berichten die erna over de stream komen. Zie de tabel hieronder
voor welk nummer wanneer.

**Blijft het stil, dan komt er elke 20 seconden een `: hartslag`.** Voor een browserclient
verandert dat niets: `EventSource` levert een commentaarregel nooit af, er komt geen
`onmessage` voor. Lees je de ruwe stream — een eigen parser, een `curl -N`, een test — dan
zie je hem wél en sla je regels die met `:` beginnen over.

**Verbind je midden in een lopende run, dan draagt de momentopname die run** — met de stappen
die tot dat moment zijn afgerond en, als er een stap bezig is, `lopendeStap`. Dat is het
late-kijkersgeval, en je kunt het uitproberen door tijdens een run een tweede keer te
verbinden.

De stub leidt die stand uitsluitend af uit wat hij verstuurd heeft: hij begint bij de
opgenomen openingsmomentopname van de opname en werkt hem bij met elk bericht dat de deur uit
gaat. Hij vermoedt niets. Wat je krijgt is dus een uitspraak over berichten die je ook
gekregen zou hebben als je eerder had verbonden.

> In `stubbundel-0.11.0` klopte dit niet: daar kwam de opgenomen openingsregel, dus `run: null`
> terwijl er een run liep. Gerepareerd in `0.11.1`.

---

## Het ontvangstschema — lees dit voordat je het gebruikt

`schemas/berichten-ontvangst.json` is voor het valideren van berichten die **binnenkomen**.
Het is een afgeleid artefact, net als de stub zelf: gegenereerd uit `asyncapi.yaml`, nooit
met de hand bijgewerkt. **Het is niet het contract** — dat is de spec, en er is er één per
grens.

```js
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const schemas = require('./schemas/berichten-ontvangst.json');

const ajv = addFormats(new Ajv({ strict: false }));

// De index gaat van de waarde in het bericht naar het schema dat erbij hoort.
const naam = schemas.soortIndex[bericht.soort];
if (!naam) return;                       // onbekend berichttype: overslaan, geen fout
const keur = ajv.compile({ ...schemas, $ref: `#/components/schemas/${naam}` });
```

**Het toetst de vorm en niet de woordenschat.** Verplichte velden aanwezig, types kloppen,
structuur klopt. Wat het níét meer toetst: of `soort`, `uitkomst` en `reden` een bekende
waarde hebben, en of er velden bij staan die niemand kent.

Dat is met opzet, en het heeft een prijs die je moet kennen: **een `soort` met een typefout
komt hier doorheen.** Die wordt gevangen aan onze verzendkant, waar dezelfde schema's wél
streng staan. Wie dit over een half jaar leest moet niet denken dat het meer controleert dan
het doet.

Het strenge schema zit niet in deze bundel. Dat is gereedschap van showcase-CBT voor uitgaand
verkeer; op runtime aan jullie kant heeft het geen legitiem gebruik, en twee schemasets naast
elkaar zou alleen betekenen dat de verkeerde nog steeds te pakken valt.

**Wil je zicht op nieuwe velden** — redelijke wens — dan hoort dat in jullie pipeline als
waarschuwing, niet op runtime als fout. Een onbekend veld dat een build laat opvallen is
nuttig; een onbekend veld dat een gebruiker een lege pagina geeft, niet.

---

## De drie tolerantie-eisen

Een additieve wijziging in 1.1.0 hoort jullie niet te breken. Dat vraagt drie dingen, en ze
zitten alle drie vóór de schemavalidatie:

| | Regel |
|---|---|
| Onbekend **veld** | negeren |
| Onbekend **berichttype** | overslaan — `soortIndex` kent hem niet, dus stil verder |
| Onbekende **enum-waarde** | niet fataal — val terug op een standaard, gooi niets |

**En je kunt het draaien in plaats van beloven:**

```sh
TOLERANTIE=ja node stub.js
```

Dan stuurt de stream alle drie tegelijk: een onbekend veld op elk bericht, een zevende
berichtsoort ertussen, en een onbekende `reden` op de gestopte run. Blijft jullie client
draaien, dan klopt het. Klapt hij eruit, dan zou hij dat bij onze eerste additieve wijziging
ook doen — alleen dan in productie in plaats van nu.

---

## Twee schakelaars, en wat ze niet zijn

| | |
|---|---|
| `TOLERANTIE=ja` | de stream stuurt wat een volgende contractversie zou kunnen sturen |
| `HARTSLAG_MS=1000` | de hartslag komt na een seconde stilte in plaats van na twintig |

**Allebei zijn ze gereedschap om een belofte uit het contract te kúnnen aantonen, en geen
gedrag dat het contract beschrijft.** In de spec staat 20 seconden, en dat is wat de bundel
doet als je niets instelt. Een toets die binnen één run wil vaststellen dát er een hartslag
is, haalt die 20 seconden nooit — dan blijft het een bewering. Zo gebruiken wij hem in
`ci/toets-stubbundel.sh`, en zo is hij hier ook bedoeld.

Lees ze dus niet als contractgedrag. Wat jullie client moet kunnen, staat in de spec; deze
twee zijn er om te controleren dat hij het ook echt kan.

---

## Opgenomen runs — een echte run, geen nabootsing

In `runs/` liggen sinds `0.13.0` twee soorten materiaal, en het verschil is de **herkomst**:

| | Wat het is |
|---|---|
| `voltooid.jsonl` · `gestopt.jsonl` · `midden.jsonl` | **afgeleid** uit de stamdata van scenario 01 |
| `<id>-voltooid.jsonl` | **opgenomen** terwijl de pipeline werkelijk draaide |

De naam met het scenarionummer ervoor is de opname. De drie zonder nummer zijn van scenario
01 en zijn gegenereerd; dat ze geen nummer dragen is geschiedenis en geen betekenis.

**`manifest.json` heeft een `opnames`-blok** dat per opname zegt welk scenario, welk `runId`,
hoeveel stappen, hoeveel berichten, tegen welke `run-stream`-versie hij is opgenomen, en de
`sha256` van het bestand. Dat laatste is te controleren zonder ons:

```sh
shasum -a 256 runs/00-voltooid.jsonl
jq '.opnames' manifest.json
```

**Waarom de stamdata in dezelfde release zit.** De stream draagt alleen `stapNummer` en
`uitkomst`; wát een stap is staat in `scenarios/<id>.json`. Een opname van 19 stappen zonder
die stamdata toont niets, en een stapnummer dat er niet in staat verdwijnt zonder melding.
Los uitgeven zou betekenen dat de twee helften uit de pas kunnen lopen zonder dat iemand het
merkt — vandaar één release en één checksum.

**Eén bekende grens.** Het `runId` van een opname is afgeleid van het scenario: `run-0000<id>`.
Dat houdt opnames van verschillende scenario's uit elkaar, maar twee opnames van hetzélfde
scenario zouden hetzelfde nummer dragen. Vandaag is er één per scenario. Komt er een tweede —
een gestopte naast een voltooide — dan wordt het nummer eerst uitgebreid, want een gelijk
`runId` is precies het geval waarbij regels van de ene run onder de stappen van de andere
belanden.

---

## De drie runs

**Elke `POST /v1/runs` start de volgende opname.** Start drie keer over dezelfde verbinding,
dan heb je ze alledrie gehad. (Tot 0.10.0 ging dat per nieuwe verbinding; die verbinding
sluit nu niet meer, dus de start is het signaal geworden.)

| | `runId` | Wat erin zit |
|---|---|---|
| `voltooid` | `run-7c41a9` | alle stappen komen aan bod en slagen |
| `gestopt` | `run-3b8e02` | stap 3 mislukt; **stap 4, 5 en 6 krijgen geen enkel bericht** |
| `midden` | `run-9d15f4` | begint bij stap 3 — zie hieronder |

**Elke opname heeft zijn eigen `runId`.** Ze droegen er eerst alle drie hetzelfde, en dat was
verkeerd oefenmateriaal: drie verschillende verlopen die beweren dezelfde run te zijn. Wie op
`runId` bijhoudt welke run hij volgt, kon daar niets zinnigs mee. De nummers liggen vast en
zijn reproduceerbaar — ze komen uit de generator en niet uit een toevalsgenerator.

**`gestopt` is degene waar het om gaat.** Stap 4 en 5 zijn van Order, en Order krijgt in die
run niets — niet omdat Order iets fout deed, maar omdat Payment eerder in de lijst faalde.
Dat is het geval waar je afleidregel op moet passen:

> Zodra `run-afgerond` binnenkomt met reden `gestopt` of `afgebroken`, geldt voor **elk**
> deelsysteem met stappen die geen afronding hebben gekregen — inclusief een deelsysteem dat
> nooit begonnen is — dat er niets meer komt.

`run-afgerond` draagt bij `gestopt` ook `gestoptBijStap`, zodat je niet hoeft af te leiden
welke stap de run stopte.

**`midden` speelt af als een run die bij stap 3 begint.** Die opname was er voor de late
kijker, en dat geval hoort sinds 0.11.0 bij het verbinden en niet bij het starten. Start je
hem met een `POST`, dan zie je dus een run zonder `run-gestart` die bij stap 3 instapt. De
plaat is wel meteen correct — `afgerondeStappen` en `lopendeStap` staan in de
openingsmomentopname.

**Het late-kijkersgeval oefen je nu langs de andere kant:** start een run en verbind er een
tweede keer bij terwijl hij loopt. Dan bouwt de stub de momentopname uit wat hij verstuurd
heeft. Dat is dichter bij de werkelijkheid dan een opname met een vastgelegd beginpunt, want
je kunt zelf kiezen op welk moment je aansluit.

**`midden` heeft een leeg CLI-paneel.** De uitvoer van al afgeronde stappen komt niet
opnieuw; die draagt geen betekenis en zou je eerst een inhaalslag laten afwachten.

---

## CORS

De stub stuurt `Access-Control-Allow-Origin: http://localhost:5173` en beantwoordt de
preflight op de twee POST-paden. Draait jouw client op een andere poort, dan weigert de
browser het antwoord — net als bij de echte kant. Dat is met opzet: een stub die
permissiever is dan wat hij nabootst, verbergt precies dit soort fouten.

Zeg het als 5173 niet klopt; dan wordt het een contractwijziging en geen stubinstelling.

---

## Uitproberen

Eerst verbinden, in een eigen venster. **Deze stopt niet vanzelf** — de verbinding blijft
open, en dat is de bedoeling. Sluit hem met Ctrl-C:

```sh
curl -N localhost:8090/v1/runs/stream
```

Dan, in een tweede venster:

```sh
curl localhost:8090/v1/scenarios
curl -X POST -H 'Content-Type: application/json' -d '{"scenarioId":"01"}' localhost:8090/v1/runs
curl -X POST -H 'Content-Type: application/json' -d '{"scenarioId":"01"}' localhost:8090/v1/runs
curl -X POST -H 'Content-Type: application/json' -d '{"scenarioId":"01","onzin":true}' localhost:8090/v1/runs
```

Wat je in het eerste venster hoort te zien: meteen een momentopname met `run: null`, na de
eerste POST de run `run-7c41a9` tot en met `run-afgerond`, en daarna elke 20 seconden een
`: hartslag`.

De tweede POST komt binnen terwijl die run nog loopt en hoort een **409** te geven met
`run-7c41a9` erin. De derde hoort een **400** te geven. Doet een van beide dat niet, dan
klopt er iets niet en horen we het graag.
