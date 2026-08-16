# Stub van showcase-CBT

Uitpakken en starten. Geen Docker, geen JDK, geen `npx`, en na het uitpakken geen netwerk.

```sh
tar -xzf stubbundel-0.10.0.tgz
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
| `runs/*.jsonl` | drie fixtures |
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

## De drie runs

De stream geeft bij **elke nieuwe verbinding de volgende run**. Verbind je drie keer, dan
heb je ze alledrie gehad.

| | `runId` | Wat erin zit |
|---|---|---|
| `voltooid` | `run-7c41a9` | alle stappen komen aan bod en slagen |
| `gestopt` | `run-3b8e02` | stap 3 mislukt; **stap 4, 5 en 6 krijgen geen enkel bericht** |
| `midden` | `run-9d15f4` | een momentopname midden in een lopende run |

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

**`midden` heeft een leeg CLI-paneel.** De uitvoer van al afgeronde stappen komt niet
opnieuw; die draagt geen betekenis en zou je eerst een inhaalslag laten afwachten. Wat je
wél krijgt is `afgerondeStappen` en `lopendeStap`, dus de plaat is meteen correct.

---

## CORS

De stub stuurt `Access-Control-Allow-Origin: http://localhost:5173` en beantwoordt de
preflight op de twee POST-paden. Draait jouw client op een andere poort, dan weigert de
browser het antwoord — net als bij de echte kant. Dat is met opzet: een stub die
permissiever is dan wat hij nabootst, verbergt precies dit soort fouten.

Zeg het als 5173 niet klopt; dan wordt het een contractwijziging en geen stubinstelling.

---

## Uitproberen

```sh
curl localhost:8090/v1/scenarios
curl -X POST -H 'Content-Type: application/json' -d '{"scenarioId":"01"}' localhost:8090/v1/runs
curl -X POST -H 'Content-Type: application/json' -d '{"scenarioId":"01","onzin":true}' localhost:8090/v1/runs
curl -N localhost:8090/v1/runs/stream
```

De derde hoort een 400 te geven. Doet hij dat niet, dan klopt er iets niet en horen we het graag.
