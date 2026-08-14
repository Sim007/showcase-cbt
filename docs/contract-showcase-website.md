# De grens naar showcase-website — gemaakte keuzes

Twee contracten onder groep `showcase-cbt`, allebei met het nummer 1.0.0 en allebei nog een
**voorstel**: ze staan in het lokale register en nog nergens daarbuiten. Vastgezet worden ze
zodra showcase-website erop gaat bouwen.

| Artifact | Type | Wat het beschrijft |
|---|---|---|
| `scenario-api` | OpenAPI 3.0.3 | de structuur van een scenario, en de besturing van een run |
| `run-stream` | AsyncAPI 2.6.0 | wat er tijdens een run gebeurt |

Er is nog geen implementatie. Er is een stub die beide serveert, gegenereerd uit die
specs, zodat showcase-website kan bouwen voordat showcase-CBT iets uitvoert. Dat is precies
het argument dat de showcase maakt, nu op zichzelf toegepast.

**De rollen, met de grens erbij.** Showcase-CBT is **provider van `scenario-api` en van
`run-stream`**; showcase-website is daar de consumer. Die woorden horen bij een grens en
niet bij een product: showcase-website is geen consument van showcase-CBT als geheel, alleen
van deze twee interfaces. Schrijf dus nooit "de provider" zonder erbij te zetten waarvan —
zeker niet in een showcase waar provider en consumer binnen elk scenario ook al rollen zijn.

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

**Geen deelsysteem-status.** Showcase-CBT meldt feiten en leidt niets af; zou die status
meekomen, dan verhuist een stukje redenering naar de kant die volgens `context.md` juist
niet redeneert.

De afleidregel die daarbij hoort, staat hier omdat hij nergens anders staat:

> Zodra `run-afgerond` binnenkomt met reden `gestopt` of `afgebroken`, geldt voor **elk**
> deelsysteem met stappen die geen afronding hebben gekregen — inclusief een deelsysteem dat
> nooit begonnen is — dat er niets meer komt.

**Niet** "een mislukte stap gevolgd door stilte". Dat stond hier eerst en het is te weinig:
stappen staan in één doorlopende lijst over het hele scenario, dus een mislukking bij
Payment laat ook Order zonder berichten achter zonder dat Order iets fout deed. Die regel
liet zo'n deelsysteem als "nog niet gestart" staan, wat na `run-afgerond` misleidend is.

Gevonden door showcase-website bij het lezen van de spec, niet door ons bij het schrijven
ervan.

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

**Gevolg, bekend en bedoeld: wie halverwege binnenkomt, heeft een leeg CLI-paneel.** De
stappen die al af zijn hebben hun uitvoer al gehad, en die komt niet opnieuw. Wat hij wél
ziet is welke stappen geslaagd zijn en welke stap loopt — genoeg om de plaat te tekenen —
en vanaf dat moment loopt de uitvoer gewoon mee.

Dat staat hier zodat het niet later als bevinding terugkomt. Wie het anders wil, vraagt om
het bufferen en herhalen van uitvoer die per definitie geen betekenis draagt, en betaalt dat
met een kijker die eerst een inhaalslag moet afwachten.

## 7a. `uitkomst` draagt geen kleur

`geslaagd` en `mislukt`, niet `groen` en `rood`. Kleur is presentatie, en presentatie is een
afleiding — dus van de andere kant. Zou showcase-CBT "groen" sturen, dan besliste hij mee
over het beeld.

Het onderscheid lijkt klein en is dat niet: het rapport van hoofdstuk 0 en 1 gebruikt intern
wél groen en rood, en juist daarom moet de grens die woorden niet doorgeven. Wat binnen één
deelsysteem een prima weergave is, wordt op een grens een aanname over hoe de ander het
toont.

## 8. Naamgeving

Domeinbegrippen in het Nederlands, techniek in het Engels, `lowerCamelCase` overal:
`scenarioId`, `runId`, `stapNummer`, `deelsysteem`, `omgeving`, `testsoort`, `gereedschap`,
`cli`, `uitkomst`, `bijzonderheden`, `reden`, `tijd`.

Berichtsoorten op de stream met streepjes: `run-gestart`, `stap-afgerond`, `cli-uitvoer`.
Het veld `soort` onderscheidt ze binnen één stroom.

## 9. Wat er nog niet klopt

**De diff-gate werkt niet op AsyncAPI** (O13). oasdiff leest OpenAPI en niets anders, dus
`run-stream` komt bij een wijziging niet langs de gate. Bij 0.9.0 valt er niets te
vergelijken en merk je het niet; bij 1.1.0 wel.

`publish-contract.sh` **faalt** daarop, en waarschuwt niet: een waarschuwing scrollt voorbij
en stilte mag niet de standaard zijn. Publiceren kan alleen met een expliciete bevestiging:

```sh
CBT_ZONDER_DIFF_GATE=akkoord ci/publish-contract.sh showcase-cbt run-stream 1.1.0 <spec>
```

Tot O13 opgelost is leunt die grens op de compatibility rule van het register alleen — één
net in plaats van twee, en dat moet iemand elke keer bewust accepteren.

**De contractpaden volgen één conventie:** `contracts/<groep>/<artifact>/<versie>/`, met het
artifact expliciet in het pad en zonder `v`-prefix. Dat geldt sinds 2026-08-13 voor beide
grenzen.

---

## Ophalen — de URL-vorm hoort bij de grens

De specs staan als **release-asset** op GitHub. Bouw de URL zelf op uit artifact en versie;
er is geen lijst die je moet raadplegen en er is geen script van ons dat je nodig hebt.

```
https://github.com/Sim007/showcase-cbt/releases/download/<artifact>-<versie>/<artifact>-<versie>.yaml
https://github.com/Sim007/showcase-cbt/releases/download/<artifact>-<versie>/<artifact>-<versie>.yaml.sha256
```

Ophalen en verifiëren:

```sh
A=scenario-api; V=0.10.0
B=https://github.com/Sim007/showcase-cbt/releases/download/$A-$V
curl -fsSLO "$B/$A-$V.yaml"
curl -fsSLO "$B/$A-$V.yaml.sha256"
sha256sum -c "$A-$V.yaml.sha256"      # macOS: shasum -a 256 -c "$A-$V.yaml.sha256"
```

**Het checksumbestand heet naar zijn asset, sinds 0.10.0.** Daarvóór heette het in elke
release `SHA256SUMS`, en dan overschrijft de tweede download de eerste zodra je twee releases
naar dezelfde map haalt — waarna `sha256sum -c` het verkeerde bestand verifieert zonder
foutmelding. Jullie vonden dat en losten het op met een submap per artifact; die is nu
overbodig. Dat de vondst van jullie kwam en niet van ons, staat in `besluiten.md`.

Let op `-L`: GitHub stuurt de download door naar een opslag-URL. En op de hoofdletter in
`Sim007`.

**Deze vorm is onderdeel van het contract.** Wijzigt hij, dan is dat een breaking change —
ook als de spec zelf geen letter verandert. Dat geldt ook voor de eigenaarsnaam en de
reponaam, want die zitten in de URL. Wij behandelen een hernoeming op GitHub daarom als wat
het is: een wijziging aan de grens, met een aankondiging vooraf.

**Waarom jullie `ci/get-contract.sh` niet krijgen.** Dat is ons gereedschap voor onze eigen
pipeline. Zouden we het meeleveren, dan wordt onze ophaalmethode onderdeel van de afspraak en
kunnen jullie breken doordat wij een script wijzigen terwijl de spec identiek blijft. Dat is
voor de derde keer dezelfde fout — eerst Docker, toen `npx` — en die maken we niet nog eens.
Drie regels `curl` in jullie eigen taal is de hele koppeling.

**De checksum is geen formaliteit.** Een release-tag is bij GitHub te verwijderen en opnieuw
te zetten; onveranderlijkheid is daar discipline en geen eigenschap. Ons script weigert op een
bestaande release, en dat is het maximale dat wij kunnen afdwingen. Wordt een asset tóch
vervangen, dan is het `.sha256`-bestand de plek waar dat opvalt — en dan valt het op bij jullie en niet
bij ons. Bewaar de checksum die je bij het pinnen hebt gezien.

**De stubbundel is hernoemd én verlaagd.** Wat jullie hebben heet
`scenario-api-stubbundel-1.0.0.tgz`. Dat wordt:

```
https://github.com/Sim007/showcase-cbt/releases/download/stubbundel-0.9.0/stubbundel-0.9.0.tgz
```

Twee wijzigingen in één stap. De naam, omdat de bundel niet van `scenario-api` is maar van
allebei de specs. En het nummer omlaag, omdat 1.0.0 zou beloven dat er niet meer gebroken
wordt terwijl de hoofdstuk-sweep nog loopt — zie `besluiten.md`, 2026-08-13. De inhoud is
gelijk gebleven, op één toevoeging na: `manifest.json` noemt nu per spec de versie en de
checksum die erin zit, zodat je kunt vaststellen dat de bundel hoort bij de spec die je zelf
hebt opgehaald.

Vanaf nu bewegen de drie nummers los van elkaar: `scenario-api`, `run-stream` en de bundel
hebben elk hun eigen reeks.

---

## Draaien

```sh
docker compose -f compose/registry.yml up -d

ci/pipeline-contract.sh showcase-cbt scenario-api 0.9.0 \
  contracts/showcase-cbt/scenario-api/0.9.0/openapi.yaml
ci/pipeline-contract.sh showcase-cbt run-stream 0.9.0 \
  contracts/showcase-cbt/run-stream/0.9.0/asyncapi.yaml

ci/generate-stub.sh        showcase-cbt scenario-api 0.9.0
ci/generate-stream-stub.sh showcase-cbt run-stream 0.9.0 scenario-api 0.9.0
```

De stub draait op WireMock met `build/stub/mappings` eronder. Beide generatoren schrijven
daarheen: eerst de operaties, dan de stream erbij.
