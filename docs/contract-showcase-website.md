# De grens naar showcase-website — gemaakte keuzes

Twee contracten, allebei 1.0.0 in het register onder groep `showcase-cbt`:

| Artifact | Type | Wat het beschrijft |
|---|---|---|
| `scenario-api` | OpenAPI 3.0.3 | de structuur van een scenario, en de besturing van een run |
| `run-stream` | AsyncAPI 2.6.0 | wat er tijdens een run gebeurt |

Er is nog geen implementatie. Er is een stub die beide serveert, gegenereerd uit die
specs, zodat de andere kant kan bouwen voordat showcase-CBT iets uitvoert. Dat is precies
het argument dat de showcase maakt, nu op zichzelf toegepast.

---

## 1. De scheiding die het contract afdwingt

**Stamdata bevat geen uitkomst.** Wat de structuur vóór de run beschrijft staat in
`scenario-api`; wat tijdens de run ontstaat komt uitsluitend uit `run-stream`. In de
`Stap` staat daarom geen `uitkomst`, geen `bijzonderheden` en geen status.

Dat is niet netheid maar de kern. Zolang de uitkomst in de stamdata staat, is een scenario
een vastgelegd script en niet een run waarvan de afloop onbekend is. Het rode pad kan dan
niet bestaan — en dat is precies wat aan de andere kant is opgemerkt: alle stappen stonden
op groen omdat het bronbestand dat zei.

## 2. Besturing gaat over REST, niet over de stream

`POST /v1/runs` en `POST /v1/runs/{runId}/afbreken`.

**Omdat een commando een antwoord nodig heeft.** Over een stroom stuur je iets en hoor je
niets; dat leverde aan de andere kant al een klacht op — een tweede start tijdens een
lopende run werd stil genegeerd. Nu is dat een `409` met het `runId` van de run die nog
loopt, zodat de aanroeper hem alsnog kan volgen of afbreken.

Daarmee gaat er niets meer omhoog over de stream. Wat overblijft is eenrichtingsverkeer,
en dan is **SSE** het eenvoudiger gereedschap dan een WebSocket: geen handshake, geen eigen
herverbindingsprotocol, en `EventSource` hervat zichzelf. De melding daarover staat in
[melding-showcase-website-sse.md](melding-showcase-website-sse.md).

**Reset staat niet in het contract.** Dat is beeldschermgedrag: schonen is lokaal, opnieuw
starten is het startcommando.

## 3. Twee velden zijn optioneel, en dat is de modellering

| Ontbreekt | Betekent |
|---|---|
| `omgeving` | de stap draait op de code en niet op een omgeving |
| `deelsysteem` | de stap is van geen enkel deelsysteem en spant over de keten |

Aan de andere kant werden `code` en `keten` als vierde en vijfde kolom behandeld, naast de
drie omgevingen. Dat klopt visueel maar niet in het model: er zijn drie omgevingen, unit-
en integratietests draaien op de code, en de gebruikersflows spannen over de keten. Een
ontbrekende verwijzing zegt dat exact, en een enumwaarde `code` zou een omgeving suggereren
die niet bestaat.

## 4. Testsoort is een vrije tekst en geen enum

De tribe houdt een eigen terminologielijst bij en die is leidend; hij is er nog niet. Een
vaste lijst in het contract zou bij elke aanvulling een contractwijziging vragen — en
daarmee zou de spec de terminologie gaan bepalen in plaats van volgen.

Wat er vandaag voorkomt: `unit`, `integratie`, `contract`, `e2e`, `artefactcontrole`,
`geen`. Dat staat in de beschrijving, niet in een `enum`.

## 5. Deelsysteem draagt een naam

`{ id: "payment", naam: "Payment" }` en niet alleen het id. Aan de andere kant stonden de
labels hardgecodeerd, met als gevolg dat een nieuw deelsysteem daar geen naam had tot
iemand het handmatig toevoegde. De naam is een feit van showcase-CBT; de kleur blijft van
de website.

## 6. Wat er niet in zit

**Geen deelsysteem-status.** Een rode `stap-afgerond` gevolgd door geen stappen meer voor
dat deelsysteem is hetzelfde feit. Showcase-CBT meldt feiten en leidt niets af; zou die
status meekomen, dan verhuist een stukje redenering naar de kant die volgens `context.md`
juist niet redeneert.

**Geen bericht voor een stap die nooit gestart is.** Dat hij ontbreekt is wat "niet
uitgevoerd" betekent.

**Geen samenvatting en geen eindoordeel.** `run-afgerond` draagt een reden — `voltooid`,
`gestopt`, `afgebroken` — en geen oordeel.

**Geen `grens`.** Of dat een eigen entiteit is of een eigenschap van een stap, is nog niet
beslist. Het contract is zonder dat besluit dichtgekomen; er is nergens een plek waar het
knelde.

## 7. De momentopname

Bij verbinden komt eerst een `momentopname`, zodat een late kijker niet blind begint. Hij
bevat de lopende run, de al afgeronde stappen en welke stap loopt — en **geen cli-uitvoer**.
Die draagt geen betekenis, en zou een late kijker op een inhaalslag laten wachten voordat
hij iets ziet.

Loopt er geen run, dan staat er `run: null`. Zwijgen zou dubbelzinnig zijn.

## 8. Naamgeving

Domeinbegrippen in het Nederlands, techniek in het Engels, `lowerCamelCase` overal:
`scenarioId`, `runId`, `stapNummer`, `deelsysteem`, `omgeving`, `testsoort`, `gereedschap`,
`cli`, `uitkomst`, `bijzonderheden`, `reden`, `tijd`.

Berichtsoorten op de stream met streepjes: `run-gestart`, `stap-afgerond`, `cli-uitvoer`.
Het veld `soort` onderscheidt ze binnen één stroom.

## 9. Wat er nog niet klopt

**De diff-gate werkt niet op AsyncAPI** (O13). oasdiff leest OpenAPI en niets anders, dus
`run-stream` komt bij een wijziging niet langs de gate. Bij 1.0.0 valt er niets te
vergelijken en merk je het niet; bij 1.1.0 wel. `publish-contract.sh` zegt dat nu hardop in
plaats van het stil over te slaan. Tot dat is opgelost leunt die grens op de compatibility
rule van het register alleen — één net in plaats van twee.

**De contractpaden volgen twee conventies.** Deze grens staat onder
`contracts/showcase-cbt/<artifact>/<versie>/`, met het artifact expliciet in het pad. De
oudere grens staat onder `contracts/order-payment/v<versie>/`, waar het artifact nergens
in het pad voorkomt. De nieuwe indeling is de betere; `order-payment` verhuist mee zodra
daar toch aan gewerkt wordt.

---

## Draaien

```sh
docker compose -f compose/registry.yml up -d

ci/pipeline-contract.sh showcase-cbt scenario-api 1.0.0 \
  contracts/showcase-cbt/scenario-api/1.0.0/openapi.yaml
ci/pipeline-contract.sh showcase-cbt run-stream 1.0.0 \
  contracts/showcase-cbt/run-stream/1.0.0/asyncapi.yaml

ci/generate-stub.sh        showcase-cbt scenario-api 1.0.0
ci/generate-stream-stub.sh showcase-cbt run-stream 1.0.0 scenario-api 1.0.0
```

De stub draait op WireMock met `build/stub/mappings` eronder. Beide generatoren schrijven
daarheen: eerst de operaties, dan de stream erbij.
