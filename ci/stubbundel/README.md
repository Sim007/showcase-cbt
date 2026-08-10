# Stub van showcase-CBT

Uitpakken en starten. Geen Docker, geen JDK, geen `npx`, en na het uitpakken geen netwerk.

```sh
tar -xzf scenario-api-stubbundel-1.0.0.tgz
cd bundel
node stub.js
```

Luistert op **8090**, of op `POORT=9000 node stub.js`.

---

## Wat erin zit

| | |
|---|---|
| `openapi.yaml` · `asyncapi.yaml` | de twee contracten, zoals gepubliceerd |
| `stub.js` | de stub — REST en stream in één proces |
| `stub-data.json` | de routes, gegenereerd uit `openapi.yaml` |
| `runs/*.jsonl` | drie opgenomen runs |
| `schemas/berichten.json` | de payloadschema's uit `asyncapi.yaml` |
| `node_modules/` | ajv en ajv-formats, meer niet |

Alles is uit de gepubliceerde specs gegenereerd. Er zit niets in wat niet uit het contract komt.

---

## Wat hij wél toetst, en wat niet

**REST: elke requestbody gaat langs het schema uit de spec.** Stuur je een veld dat er niet
in staat, dan krijg je een 400 met wat er mis is. Dat is de reden om hiertegen te bouwen in
plaats van tegen een zelfgeschreven mock: die bevestigt wat de schrijver dacht, deze houdt
je aan wat er is afgesproken.

**De stream toetst niets.** De drie runs worden afgespeeld zoals ze zijn opgenomen — er zit
geen validatie tussen. Dat hoeft ook niet: ze zijn bij het maken al tegen hun payloadschema
gehouden. Maar het betekent dat je er niet op moet vertrouwen om je eigen fouten te vangen.

Daarvoor liggen `schemas/berichten.json` erbij. Valideer de binnenkomende berichten in je
eigen testsuite:

```js
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const schemas = require('./schemas/berichten.json');

const ajv = addFormats(new Ajv({ strict: false }));
const keur = ajv.compile({ ...schemas, $ref: '#/components/schemas/StapAfgerondPayload' });
```

---

## De drie runs

De stream geeft bij **elke nieuwe verbinding de volgende run**. Verbind je drie keer, dan
heb je ze alledrie gehad.

| | Wat erin zit |
|---|---|
| `voltooid` | alle stappen komen aan bod en slagen |
| `gestopt` | stap 3 mislukt; **stap 4, 5 en 6 krijgen geen enkel bericht** |
| `midden` | een momentopname midden in een lopende run |

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
