# Besluiten — de afwegingen erachter

Wat er is besloten, waarom, en wat het kost. Per besluit een datum, want een afweging is
houdbaar zolang de omstandigheden gelijk blijven en niet langer.

Het besluit zelf staat kort in `showcase-cbt.md`. Dit bestand bevat het bewijs: wat er is
geprobeerd, wat eruit kwam, en wat er is opgegeven. Zonder dat leest een keuze als een
voorkeur, en dan gaat iemand hem over een half jaar opnieuw voeren.

> **Naschrift 2026-08-14 — "hoofdstuk" heet overal "scenario".** De showcase spreekt sinds
> die datum consequent van scenario's; `context.md` deed dat al. De notities hieronder zijn
> níét herschreven: ze zijn gedateerd, en een verslag dat je aanpast is geen verslag meer.
> Waar hieronder "hoofdstuk 0 en 1" staat, lees "scenario 00 en 01" — dat geldt ook voor de
> regels die nog gelden, zoals de uitzondering op de gegenereerde runbestanden.

---

## 2026-08-02 — Wat de drift-check vergelijkt

**De vraag.** Hoofdstuk 1 schreef "drift: runtime-spec vs gepubliceerde spec". De vraag was
wat dat in de praktijk oplevert, en of het naast de contractverificatie iets toevoegt.

**De meting.** springdoc-openapi 2.9.0 in payment-api, en zijn `/v3/api-docs` met oasdiff
tegen de gepubliceerde v1.0.0 gehouden. Zes verschillen in de ene richting, zeven in de
andere:

| Wat de runtime-spec zegt | Wat het contract zegt |
|---|---|
| `responses: [200]` | 201 en 400 |
| `currency: {type: string}` | `enum [EUR, USD, GBP]` |
| `amount: {type: number}` | `double`, met `minimum` en `maximum` |

**En geen ervan was een misdragende implementatie.** De contractverificatie stond groen; de
service geeft echt 201 terug met het juiste schema. Wat afweek was de *zelfbeschrijving*:
springdoc leidt af uit Javatypes, en `String currency` kan geen enum uitdrukken,
`BigDecimal amount` geen minimum, en `ResponseEntity<PaymentResponse>` geen 201 naast een
400.

**Wat drift dan wél toevoegt.** Een schaduw-API: een operatie die de service aanbiedt en
die de spec niet noemt. Hoeveel dat precies is, blijkt kleiner dan bij het opschrijven
werd aangenomen — gemeten door twee soorten schaduw in te bouwen en beide controles erop
los te laten:

| Schaduw | Drift | Contractverificatie (gegenereerd) |
|---|---|---|
| `GET /v1/payments` — nieuwe methode op een bekend pad | rood | **rood**: *Unsupported method GET returned 200, expected 405* |
| `GET /v1/payments/../intern/alles` — een nieuw pad | rood | **groen** |

Schemathesis probeert methoden uit op paden die hij uit de spec kent; een pad dat daar niet
in staat, kan hij niet raden. Alleen die tweede rij is dus van drift alleen.

Terzijde, en het versterkt een eerder besluit: de geschreven contractverificatie ziet ook
de eerste rij niet. Handgeschreven tests proberen geen methoden uit die niemand heeft
bedacht.

**Het besluit.** De drift-check vergelijkt de **operaties**: welke paden en methoden biedt
de draaiende service aan, en komt dat overeen met wat het contract belooft. Niet de
schema's, niet de statuscodes, niet de voorbeelden.

**Wat we daarmee niet doen, en waarom.** De implementatie annoteren tot springdoc het
contract reproduceert — `@ApiResponse`, `@Schema(allowableValues = …)` — zou de vergelijking
volledig maken. De prijs is dat het contract dan tweemaal geschreven staat: één keer in
YAML en één keer in annotaties, die uit elkaar kunnen lopen. Dat is code-first dat een
schema-first-opzet binnensluipt, en de valutalijst zou in drie plekken staan in plaats van
twee. Een bredere gate die altijd rood staat om redenen die niets met drift te maken
hebben, is geen gate.

**Wanneer herzien.** Als de implementatie zijn contract wél uit zichzelf kan uitdrukken —
bijvoorbeeld doordat de code uit de spec wordt gegenereerd in plaats van ernaast
geschreven. Dan verdwijnt de duplicatie en kan de vergelijking breder.

---

## 2026-08-02 — Contractverificatie: gegenereerd of geschreven

**De vraag.** De providerkant moet volledig worden getoetst aan de spec: elke operatie,
elke responsecode, happy en unhappy. Dat kan met testgevallen die uit de spec worden
gegenereerd, of met tests die je zelf schrijft. `CLAUDE.md` legt de testlagen vast als
JUnit-tags, en een generator levert die niet — dus de vraag was of dat zwaar genoeg weegt.

**De aanpak: allebei bouwen.** Schemathesis 4.24.3 tegen de gedeployde container, en een
JUnit-test met `swagger-request-validator` 3.0.0 tegen dezelfde container.

### Wat de gegenereerde variant vond

Zes gebreken, in een implementatie die 15 groene tests had:

| Verzoek | Was | Hoort |
|---|---|---|
| `PUT`, `DELETE`, `PATCH`, `QUERY` | 500 | 405 |
| 405 zonder `Allow`-header | — | RFC 9110 eist hem |
| `amount: 1.4e308` | 500 — `NUMERIC(38,2)` liep over | 400 |
| `orderId: null` | 201, en `null` kwam terug in de response | 400 |
| `orderId: false` | 201 — Jackson maakte er `"false"` van | 400 |
| `currency: null` | 500 — `Set.of(…).contains(null)` gooit NPE | 400 |

De vierde is de leerzaamste: een `null` die je binnenlaat komt er aan de andere kant weer
uit, en dan schendt de **response** het schema dat de provider zelf publiceert.

De handgeschreven integratietests die er op dat moment stonden, vonden er nul van. Dat is
geen verwijt aan die tests — het is de aard van het verschil. **Wat je zelf opschrijft, dekt
wat je zelf bedenkt.** Niemand verzint een verzoek met `orderId: false`.

### Wat de geschreven variant biedt

Leesbaarheid en een plek in de bestaande toolchain: zes tests met begrijpelijke namen,
`@Tag("contract")`, zichtbaar in de Maven-uitvoer naast unit en integratie. En hij toetst
niet zijn eigen verwachting: `swagger-request-validator` houdt elke response tegen de spec
uit het register, dus de norm ligt ook hier buiten de test.

### Het besluit: allebei, en de pipeline kiest

`ci/verify-contract.sh <groep> <artifact> <versie> <basis-url> <netwerk> [stijl]` met
`gegenereerd` (standaard), `geschreven` of `beide`. Een pipeline kiest er één; `beide` is
voor de demo.

Dit is een showcase, en het verschil tussen die twee stijlen is precies wat een lezer wil
zien. Eén ervan verwijderen zou het argument tot een bewering maken.

De botsing met `CLAUDE.md` lost zichzelf daarmee op: de geschreven variant draagt de tag,
de gegenereerde levert een JUnit XML-rapport, en het woord `contract` staat in de
scriptnaam en in de pipeline-uitvoer.

### Beide zijn getoetst op rood worden

`201` vervangen door `200` in de implementatie. Gegenereerd:
*Undocumented HTTP status code — Received: 200, Documented: 201, 400*. Geschreven: twee
gefaalde asserts. Een controle die nooit rood wordt is geen controle, en dat moet je een
keer aantonen in plaats van aannemen.

### Wanneer herzien

Als het onderhoud van twee stijlen gaat knellen. Voor een productiesituatie zou ik de
gegenereerde variant als gate nemen en de geschreven als documentatie van de
belangrijkste paden — of de geschreven laten vallen.

### Een valkuil die de eerste meting waardeloos maakte

De eerste run leverde zes bevindingen op die allemaal onzin waren. Alle compose-bestanden
stonden op één vast netwerk, en de stub neemt daar de servicenaam van de buur over —
bedoeld op de CI-omgeving, maar met het echte deelsysteem erbij verwees `payment-api` naar
twee containers en was het toeval wie antwoordde.

Sindsdien is **de omgeving het netwerk** en is elk deelsysteem daarin een eigen
compose-project. Wie deze opzet nabouwt, loopt tegen dezelfde val aan.

---

## 2026-08-01 — De stub: zelf genereren of een kant-en-klare mockserver (O7)

**De vraag.** Hoofdstuk 1.6 beschrijft een eigen generator die van de OpenAPI-spec
WireMock-mappings maakt. Dat is werk. De vraag was of een bestaande mockserver hetzelfde
doet, en het openstaande punt O7 hield die vraag vast.

**De aanpak: bouwen in plaats van vergelijken.** Geen afweging op documentatie, maar beide
kandidaten opgestart tegen de echte spec uit het register, met het scenario uit 1.2 als
beslissende proef.

### Prism — `stoplight/prism`

De nieuwste tag, 5.15.10, start niet:

```
TypeError: Cannot read properties of undefined (reading 'isPrimary')
    at createMultiProcessPrism
```

Met 5.14.2 draait hij wel. Vier proeven tegen de gepubliceerde v1.0.0:

| Proef | Uitkomst |
|---|---|
| `GET /v1/payments/pay-88f21c` | 200 — **padtemplates werken native** |
| `POST` met bedrag 49,95 | 201, `ACCEPTED`, exact de `example` uit de spec |
| `POST` met bedrag 600,00 | 201, **`ACCEPTED`** — verwacht was `DECLINED` |
| `POST` met een niet-gedeclareerd veld `tip` | 400 — **valideert requests tegen de spec** |

### WireMock — `wiremock/wiremock:3.13.2`

Twee handgeschreven mappings, een matcher op de body met een prioriteit erboven:

```json
"bodyPatterns": [ { "matchesJsonPath": "$[?(@.amount > 500.00)]" } ]
```

| Proef | Uitkomst |
|---|---|
| `POST` met bedrag 49,95 | 201, `ACCEPTED` |
| `POST` met bedrag 600,00 | 201, **`DECLINED`** |

### Het besluit

**WireMock, met een eigen generator.** Eén reden, en het is geen kwaliteitsoordeel: de
showcase heeft een response nodig die afhangt van de inhoud van het verzoek. Prism kiest
per statuscode altijd hetzelfde voorbeeld en kan die keuze principieel niet maken. Daarmee
zou de consumertest van Order de afgewezen betaling nooit kunnen doorlopen, en dat is
precies de tak die hoofdstuk 1 wil aantonen.

### Wat het kost

Twee dingen die Prism gratis doet, staan nu als eigen werk in 1.6: **padtemplates
matchen** — waarvan het document zelf zegt dat generatoren daarop stukgaan — en het
**opbouwen van bodies uit de `example`-waarden**.

### Wat we opgeven

Prism valideert binnenkomende requests tegen de spec, inclusief
`additionalProperties: false`. Dat is precies de eerste helft van de consumerverificatie:
*wat Order verstuurt voldoet aan de spec*. Met WireMock komt die validatie niet vanzelf —
hij moet uit het request journal of uit een validatie-extensie komen. Dat is bekend werk,
geen verrassing, maar het hoort in de begroting van dit besluit.

### Wanneer herzien

Zodra Prism een response op requestinhoud kan kiezen, of zodra het scenario uit 1.2
verdwijnt. Wie deze opzet overneemt zonder zo'n scenario, kan stap 2 tot en met 5 van 1.6
vervangen door één regel: start Prism met de spec.

### Terzijde

Twee keer nu is de nieuwste tag van een tool niet bruikbaar gebleken:
`APICURIO_STORAGE_KIND=mem` bestaat niet meer in Apicurio 3.3.1, en `prism:5.15.10` crasht
bij het starten. Vastgepinde versies zijn in deze showcase geen formaliteit.

## 2026-08-03 — De demo begint met een release zoals het nu gaat

De demo liep van een schone lei naar een volledige contractgang. De uitgangssituatie werd
verteld en niet getoond, en dat is dezelfde fout die deze showcase aan anderen verwijt:
beweren in plaats van aantonen. Wie bij de start niet laat zien wat er al was, krijgt
halverwege de vraag terug.

De demo heeft daarom drie bedrijven: a) wat er draait, b) een gewone patchrelease door de
bestaande pipeline, c) contracttesten erbij. In b komt het schema in geen enkele stap voor
— dat is de aanschouwelijke vorm van "de spec is documentatie".

**Afgewogen en niet gedaan.** De wijziging in b breaking maken zou de pointe harder maken,
maar dat is hoofdstuk 3 en die pointe moet daar landen. In b gaat het goed; het punt is dat
niets in die pipeline het heeft vastgesteld.

**Gevolg voor de versies.** c herbouwt geen images. Het deelsysteem krijgt alleen
`grenzen.env` erbij, dus alleen de deelsysteemversie beweegt: payment staat daarna op
deelsysteem 1.1.0, microservice 1.0.1, contract 1.0.0. Drie niveaus met drie verschillende
getallen, in hoofdstuk 1 al af te lezen. Eerder stond er dat ze "toevallig gelijk" waren en
dat het onderscheid pas vanaf hoofdstuk 2 zichtbaar werd; dat excuus is daarmee weg.

## 2026-08-03 — Het dashboard bestaat ook zonder testen (O11 gesloten)

O11 vroeg waar het dashboard gebouwd wordt en waar zijn gegevens vandaan komen. De
aanleiding om hem te sluiten kwam van buiten het testverhaal: vraag een squad welke
interfaces zijn deelsysteem aanbiedt, en het antwoord komt traag of niet — niet uit onwil,
maar omdat er geen plek is waar het staat.

Eén register maakt daar een opzoekvraag van. Het dashboard leest daarom uit drie bronnen:
versies uit de draaiende info-endpoints, gates uit het rapport, grenzen uit het register.
Geen enkel gegeven komt uit een demoscript — anders toont het wat iemand bedoelde in plaats
van wat er is, en dat is dezelfde fout als een stub die niet uit de spec komt.

Voorlopig één pagina: boven wat er nu draait, eronder wat er in deze run is gebeurd. De
stip op de horizon is een site met een pagina per deelsysteem en per grens, en de
testsoorten als kolommen — zodat een UI-test er later bij kan zonder verbouwing.

## 2026-08-03 — De site leidt af en bewaart niets

De vraag was of we het over een site hebben of over een systeem. Het antwoord bepaalt meer
dan de naam: het verschil zit op één punt, namelijk of het ding eigen toestand heeft.

Gekozen: **een site.** Hij leidt alles af uit drie bronnen — versies uit de draaiende
info-endpoints, gates uit het rapport, grenzen uit het register — en bewaart zelf niets.
Weggooien mag altijd; regenereren kost een run. Wat je niet bewaart, kan niet stilletjes
verouderen, en een site die alleen afleidt kan niet liegen over iets wat elders al veranderd
is.

**Wanneer het alsnog een systeem wordt.** Drie redelijke wensen forceren die stap: historie
over runs heen ("was het gisteren ook groen?"), altijd bereikbaar zijn zonder eerst iets te
draaien, en meerdere omgevingen tegelijk in beeld. Geen van drieën raakt deze showcase —
alles draait op één laptop en een run duurt minuten. Het punt van dit besluit is dat een
ontwerpsessie die kant mag verkennen maar niet ongemerkt mag kiezen.

**En dan is hij een deelsysteem als elk ander.** Hij wordt consumer van het register: pint
een contractversie op de registry-API, krijgt een `grenzen.env`, en zijn eigen pipeline
verifieert hem tegen die spec. Het dashboard ondergaat dan het mechanisme dat het toont.
Sterker dan wat er nu ligt, maar niet in hoofdstuk 1.

De harde eisen staan als negen controleerbare regels in `docs/showcase-site.md`, elk met de
voorwaarde waaronder hij geschonden is. De eerste twee — elk gegeven uit echte toestand, en
ontbrekend blijft ontbrekend — wegen zwaarder dan de rest: een pagina die toont wat iemand
bedoelde in plaats van wat er is, laat precies het probleem zien dat deze showcase
bestrijdt, en doet dat onzichtbaar.

## 2026-08-03 — De startsituatie krijgt een eigen hoofdstuk: 00-start

De demo had drie bedrijven in één script: a) wat er draait, b) een release zoals het nu
gaat, c) contracttesten erbij. Dat werkt, maar niets houdt tegen dat a of b het register
aanraakt. De bewering "hier speelt het schema geen rol" rustte dan op discipline in plaats
van op de indeling.

`00-start/` roept alleen de scripts aan die er vóór contracttesten al waren. Daarmee is het
geen bewering meer maar een eigenschap. Dezelfde zet als "de omgeving ís het netwerk" en
"een stub die méér kan dan wat hij vervangt, is net zo fout als een die minder kan".

Bijvangst: een eigen rapport. `rapport-cbt-00` is zichtbaar dunner dan `rapport-cbt-01` en
bevat geen enkele contractregel. Twee rapporten naast elkaar tonen het verschil beter dan
één rapport met een knip erin. En `01-basis` heeft geen vlag meer nodig om bij c te
beginnen — het is gewoon een ander hoofdstuk, met 0 als vereiste.

**Niet hernoemd naar `01-cbt`.** Elk hoofdstuk is cbt; de repository heet er al naar.
`01-basis` zegt wél wat het is: de referentie-implementatie die de andere hoofdstukken
alleen nog aanvullen.

**Geen placeholder nodig voor de API-tests.** Ze bestaan al en ze zijn echt: unit en
integratie aan beide kanten, een smoke en een gebruikersflow. Wat ontbreekt is niet de test
maar de norm buiten de test. `OrderIntegratieTest` mockt `PaymentClient` met Mockito en
schrijft het antwoord van de buur zelf voor — die mock is niet fout maar onbewijsbaar, en
blijft groen als Payment verandert.

Daarmee klopte het document op één punt niet: het zei dat de handgeschreven mock in de
CI-omgeving staat. Hij staat binnen de test. Dat maakt het contrast met hoofdstuk 1 scherper
in plaats van vager — de stub verplaatst de norm naar buiten de test.

## 2026-08-03 — Vier scopes, en stubs bestaan op één niveau

De omgevingen stonden als drie kolommen naast elkaar beschreven, elk met eigen kenmerken.
Dat leest als drie keuzes terwijl het één trap is: microservice, deelsysteem, systeem,
systeem plus de buitenwereld. Elke trede vervangt minder dan de vorige.

De regel eronder is: **een omgeving vervangt precies wat hij niet bevat, en de vervanging
komt uit het contract van die grens.** Daaruit volgt dat stubs op één niveau bestaan — de
CI-omgeving. Eronder is het een mock in code, in hetzelfde proces en met de norm binnen de
test. Erboven valt er niets te stubben. Een stub van een buurdeelsysteem op Test is
daarmee geen keuze maar een fout, en dat is nu na te kijken in plaats van aan te voelen.

**e2e bleek relatief aan de scope.** Dezelfde laag loopt op drie treden: door het
deelsysteem, door het systeem, door de keten. Dat verscherpt "de as is scope, niet
snelheid" in plaats van het tegen te spreken. Zolang Payment uit één service bestaat valt
e2e binnen het deelsysteem samen met de contractverificatie; vanaf hoofdstuk 8 wordt het
onderscheid zichtbaar.

**Waarom er twee blijvende omgevingen zijn, is nu beantwoord: eigenaarschap.** Test is de
laatste omgeving die je volledig bezit — resetten, versiebeheren, afdwingen. Acceptatie is
de eerste waar dat niet meer geldt. Samenvoegen betekent dat andermans storing jouw Test
rood maakt en dat een reset iets moet terugzetten wat niet van jou is.

Dat botst niet met bijlage A. De knip op eigenaarschap is technisch en blijft; wat daar een
concessie heet is de *vorm* — een blijvende omgeving met mensen die ernaar kijken. Die
nuance stond er niet en is toegevoegd, want zonder haar lijken 1.3 en bijlage A elkaar
tegen te spreken.

**Eén cel gecorrigeerd.** De CI-omgeving had "—" bij buitenwereld. Ook daar is de
buitenwereld gestubd, net als de buren; dat volgt uit de regel en stond er anders.

## 2026-08-03 — Zes pipelines per artefact, en gedeelde pipelines die niemand tegenhouden

Er stonden er vier. Er ontbraken er twee, en het onderscheid tussen de twee soorten stond
er niet.

**Het contract krijgt een eigen pipeline.** Een grens wijzigt op een ander moment dan de
code die hem implementeert, en de contractversie beweegt los van de microserviceversie. Als
publiceren een stap in de microservicepipeline was, zou elke codewijziging aan de spec komen
en zou een spec zonder implementatie niet te publiceren zijn — terwijl schema-first juist
vraagt dat het contract er eerder is.

**Productie hoort in het model, ook al bouwen we hem niet.** De belofte is dat een squad
zijn deelsysteem zelf naar productie brengt; stopt het model bij Acceptatie, dan stopt het
verhaal één stap te vroeg. Een vierde omgeving op een laptop toont niets nieuws, dus hij
wordt beschreven en niet gebouwd — en dat staat erbij.

Op productie staat **check** en niet test. Daar wordt niet meer aangetoond dat het werkt,
daar wordt waargenomen dat het werkt: health, versies, monitoring. Wie op productie test,
heeft de omgevingen ervoor niet vertrouwd.

**Twee soorten pipelines, en het verschil is waar ze aan hangen.** De zes per artefact
hangen aan een wijziging en zijn een gate. De gedeelde — alle grenzen, alle smokes, alle
gebruikersflows — hangen aan een moment, want de samenstelling verandert ook als jij niets
doet. Daaruit volgt de regel: **een gedeelde pipeline is nooit een gate voor één squad.**
Moet een squad wachten tot de tribe-brede run groen is, dan is de afstemming terug die
contracttesten wegneemt, alleen nu in gereedschap gegoten.

## 2026-08-03 — O2 gesloten: de omgeving wordt met zichzelf vergeleken

De versieconformiteitscheck wachtte op een antwoord: waar komt de verwachte samenstelling
vandaan? Die vraag was fout gesteld, en dat werd zichtbaar door de pipeline "alle grenzen".

Er bestaat geen verwachte samenstelling. Randvoorwaarde 4 zegt dat elk deelsysteem op zijn
eigen tempo opschuift, dus er is geen moment waarop een bepaalde combinatie de bedoelde is.
Een lijst met verwachte versies zou die randvoorwaarde tegenspreken en zou verouderen zodra
iemand anders releaset.

De juiste vraag is niet "draait hier de bedoelde combinatie" maar "sluit alles hier op
elkaar aan". Die is uit de omgeving zelf af te leiden: elke pin die een consumer meldt, moet
door een provider op diezelfde omgeving geserveerd worden. Geen bestand, geen onderhoud.

In hoofdstuk 5 doet hij daarmee precies wat hij moet: een consumer die gepind staat op een
versie die niemand meer serveert wordt rood, zonder dat iemand een lijst bijhield.

## 2026-08-03 — De site wordt een subrepo, en de grens die daarbij hoort

`showcase-site` krijgt een eigen repository, opgenomen in `showcase-cbt`. De reden is
levensloop: de site wordt gepubliceerd en niet gedraaid, en een eigen historie past daar
beter bij.

**Dit is een uitzondering op "één repository" en dat vraagt om een grens.** Het argument
tegen negen repositories was dat gedeelde scripts dan uit elkaar lopen. Dat argument geldt
hier niet zolang het script dat de toestand uitleest in `ci/` blijft staan, waar alle
scripts staan. Wat in de subrepo hoort is wat alleen de site nodig heeft: opmaak, sjablonen,
later meer pagina's. Wat er nooit in hoort is de gegenereerde pagina zelf — die is uitvoer
van een run.

De toets is dezelfde als bij de vork site/systeem: zolang de subrepo alleen bevat wat
regenereerbaar is, is er geen tweede plek waar de waarheid staat. Komt er iets in dat
nergens anders te vinden is, dan is de vork genomen en is het een systeem.

## 2026-08-03 — De startsituatie raakt de grens, maar test hem niet

Hoofdstuk 0 stond beschreven als "de API-tests bestaan al, alleen ligt hun norm binnen de
test". Dat was waar en te vaag. Scherper: **er is geen enkele test wiens onderwerp de grens
is.** De smoke op Test loopt er doorheen, dus de grens wordt geraakt — maar als hij omvalt
is de uitslag een rode smoke en begint het zoeken, want de test wees niet naar de grens.

Dat onderscheid — geraakt versus getest — houdt de startsituatie eerlijk. Zonder die nuance
wordt het een stroman: "ze testten de grens niet". Ze testten hem wel, één keer, laat,
samengesteld en alleen op het gelukkige pad.

Wat er in de startsituatie ontbreekt staat nu als tien punten in 0.2. Drie ervan stonden
nergens: de gate op een schemawijziging, de drift-check en de versieconformiteit. De eerste
is bovendien geen test maar een vergelijking van twee artefacten, en dat staat er nu bij.

De bindende zin eronder: alles wat er in de startsituatie is, toetst tegen een norm die de
schrijver zelf heeft bedacht. Daarmee is wat hoofdstuk 1 toevoegt niet *meer* testen maar
één ding waaruit de rest volgt — een norm die buiten de test ligt.

## 2026-08-03 — Versieconformiteit heeft het register als grond, niet als optie

De check was in pipeline-test gezet en draaide daardoor ook in hoofdstuk 0. Dat is fout: hij
staat in de tabel *Wat contracttesten toevoegt*, dus hij hoort niet in de startsituatie.

De uitweg is geen `if register bereikbaar`, want dat is een truc. De check toetst elke pin op
twee dingen: staat die versie als gepubliceerde versie in het register, en wordt hij op deze
omgeving geserveerd. Zonder register faalt de eerste voorwaarde en is de check niet van
toepassing — niet uitgezet, maar zonder grond.

Dat maakt hem meteen strenger: een pin op een versie die nooit gepubliceerd is, is ook fout.
En het legt bloot waarom hij in de startsituatie niets zou vaststellen: daar zijn de versies
op de info-endpoints twee handgeschreven beweringen die met elkaar vergeleken worden.

## 2026-08-03 — Hoofdstuk 1 bumpt geen enkele versie

De vraag was of de deelsystemen na hoofdstuk 1 naar 1.1.0 moeten, omdat ze dan meedoen aan
contracttesten. Antwoord: nee. De onderliggende artefacten veranderen niet — niet het
contract, niet de microservice, niet de samenstelling van het deelsysteem. Een
deelsysteemversie is een pin op een samenstelling, en een nieuw nummer op een ongewijzigde
samenstelling is leeg.

**Wat wél verandert is het oordeel, niet het artefact.** Dezelfde payment 1.0.1 die in
hoofdstuk 0 groen door de pipeline kwam, gaat in hoofdstuk 1 langs de contractlaag.
Strengere norm, ongewijzigd artefact.

Daaruit volgt iets dat sterker is dan de versietabel die het vervangt: hoofdstuk 1 is in de
eerste plaats geen nieuwe manier van werken vooruit, maar **een uitspraak over wat er al
staat**. Dat is ook wat een squad als eerste meemaakt die dit invoert — de eerste run gaat
over de huidige release en niet over de volgende. Gaat hij rood, dan heeft de pipeline niets
kapotgemaakt: hij heeft zichtbaar gemaakt wat al niet klopte.

Zou de deelsysteemversie hier oplopen, dan zou dat suggereren dat er iets aan het
deelsysteem is veranderd. Er wordt alleen scherper gekeken, en dat is een eigenschap van de
pipeline en niet van wat erdoorheen gaat.

**Bijvangst bij het bouwen.** `opruimen-alles.sh` herstartte het register in plaats van het
omlaag te halen. Daardoor kon hoofdstuk 0 een bereikbaar-maar-leeg register aantreffen — een
derde toestand die nergens in het ontwerp voorkomt, en waarin de versieconformiteitscheck
elke pin terecht rood zou maken op een moment dat hij niet hoort te draaien. Het register
gaat nu omlaag, en `pipeline-test.sh` slaat de stap over als er geen register is, zodat het
rapport van hoofdstuk 0 er ook geen groene regel over toont.

## 2026-08-03 — Hoofdstuk 0 en 1 verschillen in één ding

Hoofdstuk 0 draaide één deelsysteem — een patchrelease van payment — en hoofdstuk 1 draaide
er twee. Daarmee was de vergelijking tussen de twee rapporten niet zuiver: een deel van het
verschil was dekking en niet contracttesten. Precies de soort claim die deze showcase
anderen verwijt.

Beide hoofdstukken doen nu hetzelfde: **twee deelsystemen, dezelfde versies, dezelfde
omgevingen.** De patchrelease en de bugfix zijn eruit, want een tweede variabele maakt de
aftrekking troebel.

> Het werk dat contracttesten toevoegt = wat hoofdstuk 1 doet − wat hoofdstuk 0 doet.

Gemeten: 22 regels tegenover 35. Nul regels over een contract, stub, drift of conformiteit
in hoofdstuk 0. Dat verschil is af te lezen in plaats van te geloven, en het is een
ondergrens — in een bestaande omgeving komt er eenmalig reparatiewerk bij.

**Twee dingen die de vraag "draait order eigenlijk wel?" blootlegde.** Order draaide, maar
kwam in geen enkele regel van het rapport voor omdat hij buiten de pipelines was neergezet.
En het oordeel op Test beweerde "elke pin wordt daar geserveerd" terwijl die controle in
hoofdstuk 0 helemaal niet draait. Een oordeel dat meer stelt dan er is gecontroleerd, is wat
deze showcase bestrijdt; het noemt nu alleen wat er werkelijk is vastgesteld.

**"Bedrijf" is vervangen door "deel".** Bedoeld was de theaterbetekenis — eerste bedrijf,
tweede bedrijf — maar in een Nederlandse technische tekst leest het als onderneming, en dat
is een woord dat je één keer verkeerd leest en dan nooit meer goed.

## 2026-08-03 — Een gebruikersflow kan niet van één squad zijn

Hoofdstuk 1 laat elk deelsysteem zijn eigen weg naar Acceptatie lopen. Daarmee kwam een
volgordeprobleem boven: de gebruikersflow in de Acceptatie-pipeline van Payment spant over
de keten en heeft Order nodig. Staat Order er nog niet, dan valt hij om.

De verleiding is dan een deployvolgorde af te spreken. **Dat is precies de afstemming die
contracttesten wegneemt**, alleen in gereedschap gegoten: de ene squad wacht op de andere.

Wat er faalde was ook niet Payment. De contractverificatie op zijn CI-omgeving was groen —
zijn kant van de grens klopt, vastgesteld zonder dat Order ergens draaide. Wat faalde was de
gebruikersflow, en die zei iets anders: *deze omgeving is niet compleet.* Een juiste
uitkomst met een juiste boodschap, en geen tekort van contracttesten maar het bewijs dat ze
werken.

De regel uit 1.4 beslist waar hij hoort: een gedeelde pipeline is nooit een gate voor één
squad, en een gebruikersflow ís gedeeld — hij volgt wat een gebruiker doet, en die merkt
niets van de indeling in deelsystemen. Hij is daarom uit pipeline 5 gehaald en staat in
`ci/pipeline-gebruikersflows.sh`: gepland, over de keten, geen gate. Pipeline 5 houdt over
wat alleen over dít deelsysteem gaat — deployen, health, en vanaf hoofdstuk 7 zijn eigen
koppelingen naar buiten.

**Symptoom dat daarmee verdween.** De demo moest het andere deelsysteem stil vooruit
deployen voordat een flow iets kon zeggen. Die regel was het bewijs dat de flow op de
verkeerde plek hing.

## 2026-08-03 — De CI-omgeving bestond al, alleen de stub kwam ergens anders vandaan

Hoofdstuk 0 sloeg de CI-omgeving over en ging van bouwen rechtstreeks naar Test. Dat klopte
niet met het ontwerp: de startsituatie heeft een efemere CI-omgeving, en daar staat een
stub waar een buur hoort. Alleen is die stub met de hand geschreven door de consumer, niet
gegenereerd uit een gepubliceerd contract.

Daarmee is een eerdere correctie in dit document half fout gebleken. Er stond dat de
handgeschreven mock "binnen de test" staat in plaats van in de CI-omgeving. Het is
allebei: een Mockito-mock in Order's integratietest, én een handgeschreven WireMock-stub op
zijn CI-omgeving. Die tweede was weggeredeneerd omdat hij niet gebouwd was.

Hij staat er nu, in `deelsystemen/order/stub-handgeschreven/`. Handgeschreven is broncode,
dus die hoort in git — anders dan de gegenereerde tegenhanger in `build/stub/`. Hij dekt
het gelukkige pad en verder niets, en dat is geen slordigheid maar hoe je een stub schrijft
als er geen norm is om hem uit af te leiden.

**`pipeline-ci.sh` draait nu met of zonder register.** Zonder: deploy op de efemere
omgeving met de handgeschreven stub, e2e binnen het deelsysteem, opruimen. Met: de stub
komt uit het register, en drift, provider- en consumerverificatie komen erbij. Eén script,
want het ís dezelfde pipeline die stappen erbij krijgt — precies wat de showcase beweert.

**Gevolg voor het getal.** Het verschil tussen de twee rapporten was 22 tegenover 35; nu 28
tegenover 37. Dat is eerlijker: de CI-omgeving werd eerst aan contracttesten toegeschreven
terwijl hij er al was. Wat overblijft zijn negen regels die met naam te noemen zijn.

## 2026-08-03 — Beide hoofdstukken lopen in dezelfde volgorde

Hoofdstuk 1 was opgezet als scènes en begon bewust met Order — het publiek verwacht dat de
consumer als laatste moet, en die verwachting omdraaien was de helft van het argument.
Hoofdstuk 0 liep intussen per deelsysteem: eerst Payment, dan Order.

Dat kost meer dan het opbrengt. Twee rapporten met een andere volgorde dwingen de lezer om
zelf te zoeken welke regel bij welke hoort, en juist die vergelijking is de kern van deze
opzet. Hoofdstuk 1 volgt nu de volgorde van hoofdstuk 0, en de negen extra regels staan op
hun plek tussen regels die verder identiek zijn.

**Wat er van het oorspronkelijke argument overblijft, is genoeg.** Order's CI-omgeving
bevat nog steeds geen Payment. Dat Payment er net is langsgekomen maakt dat sterker in
plaats van zwakker: hij is klaar, en Order heeft hem alsnog niet geraadpleegd. Was hij niet
klaar geweest, dan was de uitkomst dezelfde.

## 2026-08-06 — De aftrekking wordt afgedwongen in plaats van aangenomen

Hoofdstuk 0 en 1 zeggen alleen samen iets. Elk apart is het een demo die groen wordt; de
bewering die ze samen dragen is dat het verschil tussen de twee rapporten het werk is dat
contracttesten toevoegt. Die bewering klopt alleen zolang al het andere gelijk is.

**En hij breekt stilletjes.** Voegt hoofdstuk 6 een deelsysteem toe aan één van beide, zet
hoofdstuk 2 payment op 1.1.0, of hangt iemand een scène om — dan blijven allebei de
hoofdstukken gewoon groen en wordt alleen de conclusie onwaar. Niets zegt er iets over.

Dat is precies de soort bewering die deze showcase aanvalt, gebouwd in de showcase zelf. Het
antwoord is dan ook hetzelfde: maak hem toetsbaar. `ci/vergelijk-rapporten.sh` kijkt of elke
stap uit hoofdstuk 0 in dezelfde volgorde terugkomt in hoofdstuk 1, en leidt de toevoeging af
uit wat overblijft. Wordt dat rood, dan is de koppeling gebroken en zie je het meteen.

**Gevolg dat er gratis bij komt:** het getal negen is niet langer door mij geteld maar door
een script afgeleid. Ik heb deze week twee keer een samenvattend getal gepresenteerd dat ik
niet had nagerekend; dit is de structurele versie van die correctie.

Vergeleken wordt op onderdeel en stapnaam. Tijdstip en bijzonderheden verschillen per run, en
de tekst van een oordeel luidt in hoofdstuk 0 anders dan in hoofdstuk 1 — wat vergeleken
wordt is de structuur en niet de formulering.

De controle staat in geen van beide rapporten. Hij gaat niet over de deelsystemen maar over
de showcase, en testbewijs van een deelsysteem hoort niet vermengd te raken met een controle
op de demo.

## 2026-08-06 — "Schema-first" in plaats van "spec-first"

De aanpak heet vanaf nu **schema-first**. Het artefact blijft de **spec**: "de gepubliceerde
spec", "spec-as-truth" en "de spec uit het register" veranderen niet.

Dat onderscheid is de hele reden. "Spec-first" gebruikte hetzelfde woord voor de werkwijze en
voor het ding, en dan lees je "de spec is er eerst" als een uitspraak over een bestand in
plaats van over een volgorde van werken. Schema-first zegt wat er eerst is: het schema, vóór
de implementatie. Wat daaruit gepubliceerd wordt, is en blijft de spec.

Negen plekken aangepast in `showcase-cbt.md`, `CLAUDE.md` en dit bestand.

**Deze afweging staat hier en niet in een wijzigingslog.** De opdracht vroeg om een regel in
de wijzigingslog van `showcase-cbt.md`, maar dat document heeft er geen en hoort er geen te
hebben: `CLAUDE.md` legt vast dat het de opzet beschrijft zoals hij nu is, zonder versienummer
en zonder log, en dat afwegingen hierheen gaan. Git houdt de geschiedenis bij.

Daarbij viel een restant op: 1.13 zei nog "de wijzigingslog is daarmee ook de driftlog". Die
zin wijst nu naar dit bestand, wat hij feitelijk al deed.

## 2026-08-06 — Een lus die groen meldde over veertien berichten die niemand bekeek

Dit staat hier als demomateriaal en niet als bugfix in de historie, want het is het
faalpatroon waar deze hele showcase over gaat — nu aangetroffen in het gereedschap dat dat
patroon moet aantonen.

**Wat er gebeurde.** De stubgenerator voor de stream valideert elk bericht tegen zijn eigen
payloadschema. De lus las de berichten van standaardinvoer:

```sh
while IFS="$(printf '\t')" read -r schema bericht; do
  ajv validate ...
done < "${TMP}/verloop.jsonl"
```

Elk gereedschap in deze opzet draait in een container met `--interactive`, dus met
standaardinvoer open. Die container slokte bij het eerste bericht de rest van het bestand
op. De lus stopte daarna, en het script meldde:

```
stap 4: 1 berichten voldoen aan hun payloadschema
```

**Waarom dat erger is dan een fout.** Het script faalde niet. Het meldde succes. Wie niet
toevallig op het getal lette, had een controle die veertien van de vijftien berichten
overslaat — en die zou blijven overslaan, stil, bij elke volgende run. Precies wat deze
showcase aanwijst als het probleem met een groene test die niets toetst.

Het is bovendien alleen opgemerkt doordat het aantal ernaast stond. Had de stap alleen "ok"
gezegd, dan was er niets te zien geweest. **Een controle die zijn omvang niet meldt, is niet
te controleren.**

**De oplossing.** De lus leest van bestandsdescriptor 3, zodat wat het lichaam met
standaardinvoer doet er niet toe doet:

```sh
while IFS="$(printf '\t')" read -r schema bericht <&3; do
  ...
done 3< "${TMP}/verloop.jsonl"
```

**Wat het aantoont.** Het gereedschap heeft zelf ook een grens: tussen de shell die de lus
draait en de container die het werk doet. Die grens is niet beschreven en niet getoetst, en
daar ging het mis — op dezelfde manier als een niet-afgedwongen grens tussen twee
deelsystemen. Contracttesten lost dat niet op; het laat zien waar je moet kijken.

**En het is geen eenmalige misser.** Bij het uitbreiden van dezelfde generator sloeg het
een tweede keer toe, in een andere vorm:

```sh
AL_AF="$(printf '%s' "${AL_AF}" | jq -c --argjson nr "$(stap_veld "${I}" nummer)" '...')"
```

`stap_veld` roept ook een container aan, en die staat in de pijp die de buitenste `jq` moet
voeden. De binnenste at de invoer van de buitenste op; `AL_AF` werd leeg en `--argjson`
klapte eruit. Dat het déze keer hard faalde in plaats van stil groen te melden, was geluk.

De regel die eruit volgt: **een gereedschap in een pijp of een lus moet zijn invoer expliciet
toegewezen krijgen.** Geen container nesten in een pijplijn die een andere container voedt,
en een lus over regels leest van een eigen bestandsdescriptor.

## 2026-08-06 — Groep is de aanbieder, artifact is de interface

De contracten van de nieuwe grens staan onder `contracts/showcase-cbt/<artifact>/<versie>/`.
De oudere grens staat onder `contracts/order-payment/v<versie>/`. Vanaf nu geldt de eerste
indeling: **de groep is de aanbieder, het artifact is de interface.**

**De reden is scherper dan dat er twee conventies waren.** De naam `order-payment` legt de
afnemer van vandaag vast. Krijgt Payment er morgen een tweede afnemer bij, dan verandert de
spec niet — maar de groepsnaam is dan onwaar geworden. Hij belooft een tweezijdige relatie
terwijl er een aanbieder met meerdere afnemers staat.

Dat is precies het soort naam dat stil verkeerd gaat: niets faalt, niemand merkt het, en het
register — de plek waar de tribe moet kunnen opzoeken wie wat aanbiedt — gaat liegen over de
vorm van zijn eigen inhoud.

De aanbieder verandert niet als er een afnemer bij komt. Daarom hoort die in de naam.

**Te doen:** `order-payment/v1.0.0/openapi.yaml` wordt `payment/payment-api/1.0.0/openapi.yaml`,
met de bijbehorende groep in het register. Dat raakt `grenzen.env`, de pipelines en de
demoscripts van hoofdstuk 0 en 1, dus het gebeurt niet terloops. Het staat hier zodat het
niet verdwijnt.

## 2026-08-07 — "Provider" mag, mits de grens erbij staat

`context.md` verbood provider en consumer voor de verhouding tussen showcase-CBT en
showcase-website. Dat verbod komt uit de tijd dat de website alleen het venster was: er was
geen grens, dus de woorden sloegen nergens op en verwarden alleen maar.

Dat is veranderd. De website ligt bij een andere squad, er wisselt eigenaarschap, en daarmee
is het een grens als elke andere. **Een showcase over provider-driven testen die de provider
van zijn eigen grens niet mag benoemen, ondergraaft zichzelf.**

De regel wordt daarom niet opgeheven maar aangescherpt: de woorden horen bij een *grens*, niet
bij een product. Showcase-website is geen consument van showcase-CBT als geheel — alleen van
één grens. Dus: **provider van `scenario-api`**, nooit "de provider".

Dat onderscheid is precies wat `context.md` zelf al vastlegde toen het zei dat elke
deelsysteemgrens een contractgrens is, ook binnen één squad. Een rol hoort bij een grens; dat
staat ook in 1.5 van `showcase-cbt.md` als de reden dat `grenzen.env` per grens een rol
noemt en niet per deelsysteem. Deze beslissing maakt de terminologie gelijk aan het model dat
er al stond.

De vervangende tekst voor `context.md` staat in de opdracht en landt daar zodra dat document
naar deze repo verhuist.

## 2026-08-09 — Drie gegenereerde runbestanden mogen wél gecommit worden

`CLAUDE.md` zegt: nooit committen wat gegenereerd is. Hier wijken we daarvan af, en dat is
een uitzondering met een grens eromheen — geen versoepeling van de regel.

**Waarvoor.** Uitsluitend voor `contracts/showcase-cbt/run-stream/0.9.0/runs/*.jsonl`: de
drie fixtures. Niet voor gegenereerde bestanden in het algemeen, niet voor
stubmappings, niet voor `build/`.

**Waarom.** De consumer moest de drie runs reconstrueren uit `ci/generate-stream-stub.sh`,
want als bestand bestonden ze niet. Er was dus niets om naar te verwijzen en niets om tegen
te valideren. Een fixture is een artefact dat we léveren, geen tussenproduct van een
build.

**Onder welke voorwaarde.** `ci/generate-stream-stub.sh --controleer` genereert opnieuw en
vergelijkt, en faalt bij verschil. Dat is wat de regel eigenlijk beschermt: een gecommit
gegenereerd bestand veroudert stil. Met die controle kan dat niet.

**Zonder die controle vervalt de uitzondering.** Verdwijnt `--controleer` uit de pipeline,
dan horen deze bestanden ook te verdwijnen.

**En wanneer hij hoe dan ook vervalt:** zodra de fixtures als release-asset gepubliceerd
worden. Dan is er een plek waar ze per versie staan met een checksum, en is een kopie in de
werkboom overbodig.

**Herzien op 2026-09-10.** Geen vervaldatum — die zou verzonnen zijn, want Releases staat
niet in scope en heeft dus geen opleverdatum. Dit is een verplichting om te kijken: op die
dag wordt de uitzondering opnieuw verantwoord of gaan de bestanden eruit. Een uitzondering
die niemand meer bekijkt, is er geen meer maar een gewoonte.

**Het zijn fixtures en geen opnames.** Ze zijn bit-voor-bit reproduceerbaar: de tijdstempels
komen van een vaste basis, het `runId` is vast. Er is niets opgenomen — er is iets
uitgerekend. Dat maakt de vervalvoorwaarde ook bereikbaar: iets dat volledig uit de generator
volgt, hoeft niet gecommit te blijven zodra het elders per versie op te halen is.

**En het maakt duidelijk wat de controle wél aantoont.** `--controleer` regenereert en
vergelijkt, en dat toont aan dat *de generator niet is gedrift* — niet dat de inhoud klopt.
Dat laatste is het werk van de spec en van de schemavalidatie binnen de generator. Het
verschil is klein om op te schrijven en groot als iemand er later op vertrouwt.

Dit staat er zo uitgebreid bij omdat een uitzondering zonder vervaldatum over drie maanden
een precedent is waar iemand naar wijst.

## 2026-08-10 — Eén schema kan niet twee rollen doen

`additionalProperties: false` op de payloadschema's is een **ware en nuttige** uitspraak over
wat wij versturen: hij vangt onze eigen typefouten. Diezelfde regel is **schadelijk** voor
wat de ontvanger valideert: voegen wij in 1.1.0 een optioneel veld toe, dan klapt zijn client
eruit — terwijl scenario 02 van deze showcase precies dat een niet-brekende wijziging noemt.

Wij leverden alleen de strenge variant mee. **Wij gaven de ontvanger dus het gereedschap om
zichzelf te breken bij onze eerste additieve wijziging** — en hij zou het niet merken, want
onze 1.0.0-stub stuurt nooit een extra veld.

**Het besluit.** Twee schema's uit één bron. Streng blijft hier, voor uitgaand verkeer.
Alleen het ontvangstschema gaat mee in de bundel — twee sets naast elkaar zou betekenen dat
de verkeerde nog steeds te pakken valt, en dan is de val verplaatst in plaats van weg.

Wat eruit gaat, in de volgorde van de drie tolerantie-eisen:

| Tolerantie | Wat er weg moet |
|---|---|
| onbekend veld negeren | `additionalProperties: false` |
| onbekend berichttype overslaan | de enum op `Soort`, plus een index van soort naar schema |
| onbekende enum-waarde niet fataal | de enums op `Uitkomst` en `reden` |

**Wat het ontvangstschema daarna nog toetst is vorm en geen woordenschat.** Verplichte velden
aanwezig, types kloppen, structuur klopt. Een `soort` met een typefout komt er doorheen. Dat
is de prijs, en hij is te betalen omdat zo'n typefout van ons komt en aan onze verzendkant
door het strenge schema wordt gevangen. Het staat in de bundel-README zodat niemand over een
half jaar denkt dat het meer controleert dan het doet.

**En de tolerantie is te draaien in plaats van te beloven.** `TOLERANTIE=ja` laat de stub
alle drie tegelijk sturen. Alle drie, want een schakelaar die een derde van de belofte toetst
en groen meldt is hetzelfde patroon als een lus die na één bericht stopt.

## 2026-08-10 — De lege-verzamelingseis, en waarom hij niet alleen in CLAUDE.md staat

De regel: **een gate faalt bij een lege verzameling, tenzij het verwachte aantal expliciet is
opgeschreven.** Dan is nul een bewering in plaats van een bijproduct.

"Faalt altijd bij nul" was te grof. Waar leeg legitiem is, levert dat een gate op die mensen
uitzetten — en dan ben je terug bij stil groen met een stap ertussen.

**Maar een regel in CLAUDE.md is een afspraak**, en dit hele project betoogt dat een afspraak
te zwak is: hij staat in een document, hij wordt gelezen door wie hem leest, en als hij
gebroken wordt merkt niemand dat op het moment zelf. Een regel over stil groen die zelf
alleen als afspraak bestaat, is de zwakke vorm van wat we laten zien.

Daarom allebei. In `CLAUDE.md` voor wie bouwt, en toetsbaar in `ci/controle-gates.sh`: elk
script in `ci/` moet `verwacht_minstens` aanroepen of met een reden in de vrijstellingslijst
staan. De richting is met opzet omgekeerd — een nieuw script moet iets declareren of expliciet
worden vrijgesteld. Vergeten is geen optie meer.

**Wat dit niet bereikt:** showcase-website heeft een eigen `CLAUDE.md`, en deze regel komt
daar niet. Dat is de hoofdstukvraag in het klein — een standaard die per repository is
vastgelegd, geldt niet tribebreed. Niet opgelost, wel vastgelegd.

## 2026-08-13 — De geleefde grens gaat naar 0.9.0, de getoonde blijft op 1.0.0

Twee soorten grenzen in één repository, en ze hebben tegengestelde versiebehoeften. Dat
onderscheid is nu ook in de nummers zichtbaar.

**De getoonde grens houdt 1.0.0.** `payment-api` 1.0.0, 1.1.0 en 2.0.0 zijn de inhoud van de
scenario's: hoofdstuk 2 gaat over een additieve wijziging naar 1.1.0, hoofdstuk 3 over een
major naar 2.0.0. Die nummers zijn script. Ze beloven niets aan niemand en ze mogen daarom
niet meebewegen met hoe af de showcase is.

**De geleefde grens gaat naar 0.9.0.** `scenario-api` en `run-stream` zijn een belofte aan
squad 2, en de hoofdstuk-sweep staat nog open. 1.0.0 zou zeggen: hier mag je op bouwen en
wij breken dit niet meer. Dat is niet waar zolang er nog hoofdstukken langskomen die de
scenariostructuur kunnen raken. `0.x.y` zegt wat er werkelijk geldt — er mag nog gebroken
worden — en dat is de eerlijke stand.

**Wat het kost.** Vrijwel niets: `contract-showcase-website.md` noemde beide specs
uitdrukkelijk een voorstel dat "nergens daarbuiten" stond, dus er is niets gepind dat nu
breekt. Eén ding wél: de bundel die squad 2 heeft heet `scenario-api-stubbundel-1.0.0.tgz`
en wordt `stubbundel-0.9.0.tgz`. Naamswijziging én versieverlaging in één stap, en dat is
een melding en geen voetnoot.

**Waarom niet gewoon 1.0.0 laten staan en later breken.** Omdat dat precies de gewoonte is
die contracttesten bestrijdt: een nummer dat iets belooft wat de eigenaar niet van plan is na
te komen. Een grens waar je nog aan sleutelt hoort een nummer te dragen dat dat zegt.

## 2026-08-13 — Een gate leest uit de werkboom, nooit uit het kanaal

Dit is een regel voor elke gate die er nog bij komt, en hij is ontstaan uit een fout die
bijna gemaakt werd.

Het voorstel was: het register hangt af van de groep — Apicurio voor de getoonde grenzen,
GitHub Releases voor de geleefde. Dat klinkt sluitend en het breekt `controle.sh`. Die
publiceert de spec **van schijf** naar een leeg register en regenereert de fixtures daaruit.
Leest `get-contract.sh` voor die groep uit Releases, dan haalt de controle bij elke push de
laatst **uitgegeven** spec op in plaats van die in de werkboom. Wijzig je de spec en push je,
dan vergelijkt hij de oude release met de oude fixtures en meldt groen. De wijziging is dan
door geen enkele gate gekomen.

**Twee rollen die één woord deelden.**

| | Wat | Wie leest het | Wanneer |
|---|---|---|---|
| werkregister | Apicurio, gevuld uit de werkboom, per run weggegooid | onze pipeline | vóór de gates |
| distributiekanaal | GitHub Releases, onveranderlijk | squad 2 | ná de gates |

**De regel:** *een gate hoort vóór publicatie, dus leest uit de werkboom en nooit uit het
kanaal.* Wie een gate toevoegt die uit een kanaal leest, toetst wat er al is uitgegeven — en
dat is per definitie niet wat er beoordeeld moet worden.

Dat de regel andersom ook geldt, staat er niet voor niets bij: een consumer leest juist wél
uit het kanaal, want die moet hebben wat er is uitgegeven en niet wat wij in onze werkboom
hebben staan. Dezelfde spec, twee bronnen, en welke de juiste is hangt af van of je vóór of
ná de gate staat.

**Waarom dit hier staat en niet in een scriptcommentaar.** Het is de vierde keer in deze
reeks dat stil groen bijna binnenkwam, en de eerste keer dat het zou zijn binnengekomen via
de reparatie van stil groen. Een regel in een script bewaakt dat script; een regel hier
bindt de volgende.

## 2026-08-13 — Twee rapportfixtures, met dezelfde behandeling als de runbestanden

`ci/vergelijk-rapporten.sh` draait vanaf nu bij elke push. Hij vraagt twee rapporten, en die
zijn er op een runner niet: echte rapporten staan in `<hoofdstuk>/rapport/`, die map staat in
`.gitignore`, en testbewijs hoort bij een run. Er moest dus invoer komen.

**Waarvoor.** Uitsluitend voor `ci/fixtures/rapport-zonder-cbt.md` en
`ci/fixtures/rapport-met-cbt.md`: acht stappen en dertien stappen, genoeg om de vergelijker
door al zijn gevallen te sturen — gelijke stappen, toegevoegde stappen, en een oordeelregel
waarvan de tekst verschilt terwijl de sleutel gelijk blijft.

**Waarom geen `--zelftest`.** Een vergelijker toetsen tegen invoer die hij zelf verzint,
toetst niets. De fixtures komen van buiten het script.

**Het zijn verwachtingen en geen opnames.** Dat is het verschil met de runbestanden: die zijn
uitgerekend door een generator en bit-voor-bit reproduceerbaar, deze zijn met de hand
geschreven. Daarmee is hun zwakte een andere. Ze kunnen niet drift ten opzichte van een
generator, maar wel ten opzichte van het rapportformaat.

**Waaraan te zien is dat ze verouderd zijn.** Verandert `rapport_start` of `_rapport_regel` in
`ci/lib/tools.sh` de kolommen, dan blijven deze bestanden staan zoals ze zijn en meldt de
vergelijking groen over iets wat niet meer op een echt rapport lijkt. Dat is precies het
patroon dat dit hoofdstuk bestrijdt, dus is het geen aantekening maar een controle:
`controle.sh` laat `tools.sh` ter plekke één vers rapport schrijven en legt de kopregel naast
die van beide fixtures. Wijken ze af, dan is het rood met de mededeling dat de fixture
verouderd is.

**Wat die controle niet dekt.** Alleen de kopregel, dus de kolommen. Verandert de vorm van een
stapregel zonder dat de kop meebeweegt, dan ziet hij het niet. Dat is bewust smal gehouden:
de vergelijker leest zelf ook alleen veld 3 en 4, dus verder reikt zijn afhankelijkheid niet.

**Herzien op 2027-02-13**, samen met de vrijstellingen in `controle-gates.sh`. Vervalt eerder
als de demo's van hoofdstuk 0 en 1 automatisch gaan draaien: dan zijn er echte rapporten en
zijn deze twee overbodig.

## 2026-08-13 — De demo's draaien nergens automatisch, en dat is het gat eromheen

Nu vastgelegd omdat er anders alleen een reparatie zou staan en niet het gat dat de reparatie
mogelijk maakte.

**Wat er staat.** Van de 28 scripts in `ci/` en de demomappen draaien er **10** mee bij elke
push. De andere **18** — 16 in `ci/` plus de twee demoscripts — vragen gebouwde images,
gedeployde containers of een omgeving, en vallen daarom alleen onder de bereikbaarheidsregel:
er is aangetoond dát ze ergens worden aangeroepen, niet dát ze werken.

**Wat dat betekent.** Voor die 18 is de enige verificatie dat iemand de demo draait en kijkt.
Dat is een workaround en geen oplossing, en het is precies wat een exitcode 127 in
`vergelijk-rapporten.sh` maandenlang onzichtbaar hield: het script wérd aangeroepen, alleen
door een demo, en een demo draait niet in CI.

**Waarom het nu niet is opgelost.** De demo's in CI hangen betekent Maven, `docker build`,
deploys en Playwright bij elke push. Dat is een eigen opdracht met een eigen looptijd en een
eigen afweging over wat een push mag kosten — laptopbudget is een ontwerpeis, en een runner
die de hele showcase draait is een andere belofte dan deze repository nu doet.

**Wat er tot die tijd geldt.** De 18 staan met reden en herzieningsdatum in
`vrijstelling_uitvoering` in `ci/controle-gates.sh`. Loopt die datum af, dan is de vraag niet
"waarom staat dit hier" maar "kan het inmiddels wel".

**Dit hoort een O-nummer te krijgen** in `docs/showcase-cbt.md` 1.13, naast O3 tot en met
O14. Dat is nog niet gedaan: dit document beschrijft de afweging, de openstaandepuntenlijst
in de showcasebeschrijving is een andere plek en die wordt in een eigen wijziging bijgewerkt.

## 2026-08-14 — De compatibiliteitsrichting volgt uit wie schrijft en wie leest

`publish-contract.sh` zette `BACKWARD` hard op elk artifact. Op twee van de drie klopte dat,
en dat het klopte was toeval: er is nooit gekozen, het was de standaardwaarde van een script.

**De regel is breder dan die ene instelling.** Welke kant compatibel moet blijven volgt uit
de richting van het verkeer op die grens:

| | Wie schrijft | Wie leest | Richting |
|---|---|---|---|
| REST | de consumer stuurt een verzoek | de provider | `BACKWARD` |
| stream | de provider vertelt | de consumer | `FORWARD` |

Op `run-stream` schrijven wij en leest showcase-website. Met `BACKWARD` keurt de gate daar
juist de wijziging goed die hen breekt: een veld uit `required` halen is voor een lézer
veilig — hij eist minder — maar wij zijn de schrijver, en wat wij niet meer sturen mist de
consumer. Gemeten op een `JSON`-artifact: `BACKWARD` geeft daar HTTP 200, `FORWARD` geeft 400
met `OBJECT_TYPE_REQUIRED_PROPERTIES_MEMBER_ADDED`.

De richting staat daarom per grens in `ci/registers.env`, met de reden erbij, en een grens
zonder regel laat de publicatie falen. Kiezen is verplicht, vergeten kan niet — dezelfde
omgekeerde formulering als bij de vrijstellingen.

**Wat dit algemeen maakt:** een compatibiliteitsregel is geen instelling van een register
maar een uitspraak over een richting. Wie hem als standaard overneemt, kiest de helft van de
tijd de verkeerde — en merkt dat pas als de gate iets doorlaat.

## 2026-08-16 — De stream blijft open tussen runs door

Eén verbinding per sessie, niet per run. De consumer sluit hem, niet de provider. Een tweede
scenario starten gaat over dezelfde verbinding.

**Wat daaruit volgt.** `runId` is niet langer een detail voor herverbindingen maar het enige
waaraan de website ziet dat er een nieuwe run begint. En een momentopname met `run: null` is
vanaf nu de normale begintoestand van elke sessie, geen randgeval voor een late kijker.

**Er hoort een heartbeat bij, en die is niet vrijblijvend.** Een stille SSE-verbinding wordt
door proxies en browsers opgeruimd. "Altijd open" beloven zonder teken van leven is een
belofte die het transport niet houdt. Elke 20 seconden een SSE-commentaarregel.

**Een commentaarregel en geen zevende berichtsoort**, en dat is een afweging en geen detail:
`EventSource` levert een commentaarregel nooit aan de applicatie af, dus een browserclient
kan er niet over struikelen. Een echt bericht fírt wél, en dan moet elke consumer hem
wegfilteren — dan verplaats je het werk naar de kant met de meeste lezers. Wie hem wél moet
kennen is iedereen die de ruwe stream leest: een eigen parser, een `curl -N`, onze replayer.

**De prijs, en die staat er bewust bij.** AsyncAPI 2.6.0 kan een commentaarregel niet
uitdrukken — het formaat kent alleen berichten op een kanaal. De heartbeat staat dus in proza
in de kanaalbeschrijving, op de enige plek waar geen enkel net staat: geen schema dat hem
afdwingt, en de structuurkant is de erkende schuld uit O13. **Derde keer deze maand dat een
belofte in proza landt**, en de vorige twee — `omgeving` ontbreekt, `deelsysteem` ontbreekt —
zijn allebei misgelezen. Dat is geen reden om het niet te doen; het is een reden om te weten
waar de volgende bevinding vandaan komt.

**Waarom een herverbinding geen resync hoeft te dragen.** De hele showcase draait op één
laptop, met iemand ernaast. Een reconnect is daarmee geen normale gebeurtenis maar een
storing; showcase-website zet de automatische reconnect van `EventSource` uit en toont het.
Opnieuw beginnen is de herstelactie, en die hoort bij de mens. Daardoor raken er binnen een
run geen cli-regels kwijt en hoeft de momentopname niets in te halen.

## 2026-08-17 — Elke opname een eigen `runId`, en waarom er één het oude houdt

De drie fixtures droegen alle drie `run-7c41a9`: drie verschillende verlopen die beweerden
dezelfde run te zijn. Onoefenbaar, en erger dan dat — verkeerd oefenbaar, want een consumer
die op `runId` bijhoudt welke run hij volgt, krijgt materiaal dat zijn logica bevestigt
terwijl het niets aantoont. Dat wordt dragend zodra de stream open blijft.

Nu: `voltooid` = `run-7c41a9`, `gestopt` = `run-3b8e02`, `midden` = `run-9d15f4`. Vast en
reproduceerbaar, want dat is de voorwaarde waaronder deze gegenereerde bestanden gecommit
mogen staan.

**`voltooid` houdt het oude nummer, en dat is een keuze.** Datzelfde nummer staat op zestien
plekken in beide specs als `example`. Alle drie hernummeren zou die examples ongeldig maken,
en dan was deze reparatie geen losse stap meer maar een specwijziging — precies wat hem uit
de wachtrij hield terwijl showcase-website erop zat te wachten.

**Wat blijft staan, genoteerd omdat het ooit gaat verwarren:** er is nu één fixture waarvan
het `runId` gelijk is aan het voorbeeldnummer in de specs. Wie een bericht ziet met
`run-7c41a9` kan niet aan het nummer zien of het uit de `voltooid`-opname komt of uit een
voorbeeld. Als daar ooit verwarring over ontstaat, komt ze hiervandaan.

## 2026-08-17 — Stand van deel A, en wat deel B nog moet

Het besluit "de stream blijft open" is in twee delen geknipt, langs wie er iets van merkt.
De oorspronkelijke knip — eerst de stub, dan de publicatie — kon niet: de stub moet de
heartbeat zenden en die staat in `run-stream`, dus stub-vóór-spec levert een stub op die iets
doet wat de spec niet beschrijft.

**Deel A staat en is uitgegeven.** `scenario-api 0.11.0` met de afwezigheidsregel bij `Stap`,
`run-stream 0.11.0` met de heartbeat in de kanaalbeschrijving, beide gepubliceerd, getagd en
langs de publieke URL geverifieerd. De fixtures zijn opnieuw gegenereerd met drie eigen
`runId`'s. De melding aan showcase-website staat in
`docs/melding-showcase-website-0.11.0.md`, met vooraan dat de bundel hier nog niet naar
handelt.

**Deel B moet nog, in één keer.** `ci/stubbundel/stub.js` krijgt vier gedragswijzigingen die
niet los opleverbaar zijn: de verbinding openhouden, roteren op `POST /v1/runs` in plaats van
op een sluiting, een idle-momentopname bij verbinden, en de heartbeat zenden. Openhouden
zonder roulatiesignaal geeft een stub die na één run stilvalt; roteren zonder
idle-momentopname geeft een tweede run zonder begin. Daarna: bundel `0.11.0`, zijn tag, en
een korte melding dat het gereedschap de specs heeft ingehaald.

**Eén ding dat in deel B moet meeveranderen en makkelijk vergeten wordt.**
`ci/toets-stubbundel.sh` leest tot een aantal berichten dat hijzelf noemt. Zodra de stub
openblijft is dat aantal niet meer de natuurlijke grens van een run maar een getal dat ik
zelf heb gekozen, en dan toetst de gate zijn eigen aanname. Hij moet lezen **tot
`run-afgerond`**, met de tijdslimiet als vangnet daaromheen.

> **Gecorrigeerd op 2026-08-17.** Hier stond dat die toets tot 21 berichten las, het aantal
> van een volledige run. Dat klopte niet: hij las twaalf seconden en eiste er minstens vijf
> (`VERWACHT_MINSTENS=5`, `--max-time 12`). De redenering hierboven blijft staan — hij moest
> hoe dan ook weg — maar het getal was verzonnen, en dat maakt het erger en niet beter: 21
> klinkt afgeleid van de opname en 5 is zichtbaar willekeurig. **Vierde keer deze maand dat
> een document iets beweert wat de code niet doet.** De drie ervoor gingen over beloften aan
> een ander (`omgeving`, `deelsysteem`, "twee draaiwijzen"); deze gaat over een verslag aan
> onszelf, en dat is de soort die niemand tegenleest.

## 2026-08-17 — Deel B: zes gedragswijzigingen, en wat `midden` daarbij verliest

Deel B stond op vier: openhouden, roteren op `POST /v1/runs`, een momentopname bij
verbinden, en de hartslag. Het werden er zes, en de twee erbij zijn geen uitbreiding maar
een gevolg dat bij het knippen over het hoofd is gezien.

**De stub kreeg toestand, en daarmee een plicht.** `POST /v1/runs` zegt in de spec: er kan
één run tegelijk lopen, en loopt er al een dan volgt een 409 met het `runId` van die run.
Zolang de stub na elke start weer vergat wat hij deed, kón hij die regel niet hebben. Nu hij
weet dat er een replay loopt, is 201 blijven geven geen versimpeling meer maar een stub die
niet weigert wat de echte kant weigert — en dat is zijn hele bestaansreden.

**En het `runId` in de 201 moest uit de opname komen.** De routebody is de example uit de
spec, dus elke start antwoordde `run-7c41a9` terwijl de stream om beurten `run-3b8e02` of
`run-9d15f4` afspeelde. Dat is niet "de stub die iets bepaalt": het example is een voorbeeld
en geen voorschrift dat elk antwoord dat nummer draagt. Het is de stub die zijn twee kanten
over dezelfde run aan het woord houdt. Zonder dat was `e4ea4de` — elke opname zijn eigen
nummer — een halve reparatie geweest, want de verwarring stond dan een laag lager terug.

**Wat het gekost heeft: `midden` toont niet meer wat hij toonde.** Die opname was er voor de
late kijker, en dat geval hoort vanaf 0.11.0 bij het *verbinden* en niet bij het *starten*.
Er waren twee uitwegen. De ene: `midden` uit de rotatie halen en zijn momentopname sturen aan
wie verbindt terwijl er een run loopt — maar dan meldt die momentopname `run-9d15f4` terwijl
er een andere run speelt, en dan liegt hij over welke run het is. De andere: hem in de
rotatie laten en accepteren dat hij na een POST afspeelt als een run die bij stap 3 begint.

Het is de tweede geworden. **Een fixture die minder toont is een kleinere fout dan een
momentopname die de verkeerde run aanwijst** — de eerste maakt het oefenmateriaal armer, de
tweede maakt het verkeerd, en verkeerd oefenmateriaal bevestigt de logica van de consumer
zonder iets aan te tonen. Dat is precies het argument uit `e4ea4de`, en het geldt hier
opnieuw.

**De stub stelt daarom nooit zelf een momentopname samen.** Uit de replaypositie een stand
berekenen kon: hij weet welke regels hij verstuurd heeft. Maar dan bepaalt hij de toestand
van een run, en toont hij iets wat nergens is vastgelegd. Wie midden in een run aansluit,
krijgt de opgenomen opening van die run en niet de stand van nu. Dat staat in de
bundel-README als grens, niet als detail.

**Het gat is echt en het is gemeld.** Het late-kijkersgeval is tegen de bundel niet meer te
oefenen. Dat staat in de melding aan showcase-website en niet alleen hier, want zij zijn
degenen die erop stuklopen — en een verlies dat alleen in ons eigen besluitenlogboek staat,
is voor hen geen verlies maar een verrassing.

**`HARTSLAG_MS` is erbij gekomen, en dat is een schakelaar die niet in de spec staat.** De
spec zegt 20 seconden; een run duurt er acht. Zonder die schakelaar ziet geen enkele toets
ooit een hartslag, en dan is "er is een heartbeat" een bewering zonder gate — bovenop een
kanaalbeschrijving waar al vaststaat dat er geen schema onder staat. Twee ongedekte lagen
boven elkaar is er één te veel. Hij hoort in dezelfde categorie als `TOLERANTIE=ja`:
gereedschap om een contractbelofte te kunnen aantonen, geen gedrag dat het contract
beschrijft. Dat onderscheid staat met zoveel woorden in de bundel-README, anders leest de
volgende het als contractgedrag.

**Wat blijft staan:** de WireMock-stream-stub uit `ci/generate-stream-stub.sh` houdt het
gedrag van 0.10.0 — sluit na `run-afgerond`, roteert per verbinding, geen hartslag. Dat is
vanaf nu de enige plek in de repository die de gepubliceerde spec tegenspreekt. Vastgelegd
als O16, niet nu opgelost: WireMock kan een rotatie op een POST en een periodieke
commentaarregel vermoedelijk niet, en dat uitzoeken hoort niet in de levering van deel B.

## 2026-08-18 — De stub leidt zijn toestand af uit wat hij verstuurd heeft

Herziening van de regel van gisteren, en van de kwalificatie eronder.

**Wat er stond.** "De stub stelt nooit zelf een momentopname samen", met als gevolg dat wie
midden in een run verbindt de opgenomen openingsregel van die opname kreeg. Dat is als grens
van de bundel opgeschreven, in de README en in de melding aan squad 2.

**Wat het was.** Squad 2 heeft het gemeten: verbind terwijl `voltooid` op stap 5 staat, en de
stub stuurt `run: null` — waarna de losse stapberichten volgen die nergens meer aan te hangen
zijn, want `stap-gestart` en `stap-afgerond` dragen geen `scenarioId`. In het schema staat bij
`run`: *"Null wanneer er geen run loopt. Zwijgen zou dubbelzinnig zijn."* De stub sprak dus de
spec tegen die hij hoort voor te doen. **Dat is geen beperking maar non-conformiteit**, en het
verschil is niet academisch: een beperking beschrijf je, een non-conformiteit repareer je.

**De regel die het had moeten zijn.** De oorspronkelijke formulering was in bedoeling goed en
in bereik te breed. Nu:

> De stub leidt zijn toestand uitsluitend af uit wat hij verstuurd heeft, nooit uit wat hij
> vermoedt.

Dat sluit verzinnen nog steeds uit en laat toe wat feitelijk is. De stand begint bij de
openingsmomentopname van de opname — zelf een opgenomen uitspraak over de toestand — en wordt
bijgewerkt door precies de berichten die de deur uit gaan. Eén detail dat blijft: `Run` eist
`gestartOp` en `run-gestart` draagt dat niet, dus dat wordt de `tijd` van dat bericht. In de
fixtures scheelt dat een seconde met de opgenomen waarde. Wij melden het moment waarop wij de
start gemeld hebben, en dat is wat wij kunnen weten.

**Het late-kijkersgeval komt hiermee terug, langs de goede kant.** Bij het knippen van deel B
is gekozen `midden` in de rotatie te laten en het late-kijkersgeval op te geven, omdat het
alternatief een momentopname was die over de lopende run loog. Die afweging klopte. Wat toen
niet gezien is: er was een derde weg, en die lag niet in de fixtures maar in de stub. Je kunt
nu op elk zelfgekozen moment aansluiten, wat dichter bij de werkelijkheid staat dan een opname
met een vastgelegd instappunt.

**De bundelversie is losgemaakt van de contractversie.** `controle.sh` gaf `VERSIE` door als
bundelversie, dus deze reparatie — die geen enkele spec raakt — zou om een contractversie
hebben gevraagd. Dat ontkent "drie versies, elk hun eigen levenscyclus" in de code terwijl het
document het belijdt. Nu staat `BUNDELVERSIE` er apart. Dezelfde klasse als de
compatibiliteitsrichting die overal hardgecodeerd op `BACKWARD` stond: een keuze die nooit is
gemaakt omdat er een standaardwaarde in de weg zat.

## 2026-08-18 — Afgekeurde specs horen bij het scenario, niet bij de contracten

Vooruitlopend op scenario 02 en 03, en vastgelegd omdat het de eerste toepassing is van
"scenariospecifieke specs" uit `CLAUDE.md`.

De tegenvoorbeelden — `merchantId` verplicht toevoegen onder 1.1.0, en de brekende wijziging
aangeboden als 1.2.0 — worden nooit gepubliceerd. Ze bestaan om door de gate tegengehouden te
worden. **Het zijn dus geen contractversies**, en in `contracts/` staan uitsluitend
contractversies: dat is de map waar het register uit gevuld wordt en waar onveranderlijkheid
geldt. Een spec die per definitie wordt afgekeurd, hoort daar niet tussen te staan alsof hij
een kandidaat is.

Ze komen in `02-wijziging-zonder-breuk/specs/` en `03-breaking/specs/`, bij het demoscript dat
ze aanbiedt. Dat is dezelfde regel als voor de rest van een genummerde map: wat er staat is
testmateriaal van dat scenario en niets anders.

**De precedent, breder dan deze twee bestanden:** de vraag is niet welk formaat een bestand
heeft maar welke rol het speelt. Een OpenAPI-bestand dat bedoeld is om te falen is een
testgeval in de vorm van een spec, en het hoort waar de andere testgevallen staan.

---

# Geleerd

Hierboven staat wat er gekozen is. Hieronder staat wat die keuzes hebben gekost.

Deze notities zijn ontstaan tijdens het bouwen, niet erna bedacht. Ze staan hier omdat ze
het argument van de showcase dragen: elk van deze gevallen is iets wat in een echte tribe
ook gebeurt, en meestal onopgemerkt blijft.

De datum is die van het vastleggen, niet van het voorval.

## 2026-08-07 — Stil groen is de standaarduitkomst, niet de uitzondering

Twee keer meldde eigen gereedschap groen over dingen die niemand had bekeken. De
validatielus las van stdin; de aangeroepen container at de rest van het bestand op, waarna
de lus stopte na één bericht en groen meldde over veertien ongecontroleerde berichten. Bij
het uitbreiden van dezelfde generator dook het opnieuw op, in andere vorm: een container
genest in een pijplijn die een andere container voedt.

Dat het de tweede keer hard faalde in plaats van stil groen te melden, was geluk. Dat hoort
erbij te staan, want dat is het punt.

Regel: geen container nesten in een pijplijn die een andere container voedt; een lus over
regels leest van een eigen bestandsdescriptor. En breder: een groene toets zonder zichtbaar
aantal gecontroleerde items zegt niets.

## 2026-08-07 — Publiceren zonder afnemer is geen publiceren

*(Het nummer is op 2026-08-13 verlaagd naar 0.9.0; zie het besluit van die datum. De tekst
hieronder beschrijft de situatie van 2026-08-07 en blijft zoals hij is.)*

`run-stream` draagt het nummer 1.0.0 en is na de eerste keer in het register zetten tweemaal
gewijzigd: de uitkomst-enum, en de server-url die het pad dubbel bevatte.

**Dat mocht, en dat is precies het ongemakkelijke.** De spec is nog niet officieel 1.0.0 en
staat nog nergens buiten de squad, dus er is niets geschonden. Maar het nummer zegt van wel.
Een versienummer is een belofte aan iemand anders, en dat nummer stond er al voordat er
iemand was om de belofte aan te doen.

Een register dat in memory op localhost draait en bij elke demo wordt weggegooid, is dan ook
geen register maar een demo-onderdeel. "Gepubliceerd" betekende hier: staat in een lade die
morgen leeg is.

Zolang een spec voor een andere squad een bestand in een git-repo is, is het de afspraak in
een document die te zwak is. Onveranderlijkheid is pas echt als iemand anders de versie kan
ophalen — tot dat moment is het een voornemen, hoe netjes de nummering ook oogt.

## 2026-08-07 — Eén document, twee plekken, verkeerde conclusie

De squad onderbouwde een modelleerkeuze met een passage uit context.md die al geschrapt was.
Ze lazen de versie in de andere repo, omdat de nieuwe daar nog niet was geland. De uitkomst
bleef toevallig goed; de redenering was onjuist.

Kosten: één ronde. De volgende keer is dat niet gegarandeerd. Een kopie van een document is
geen kopie maar een tweede document met vertraging.

## 2026-08-07 — Een stub die alleen groen kent, test de verkeerde helft

De eerste stub serveerde vijftien berichten die allemaal slaagden — precies de kritiek die
de consumer op zijn eigen simulator had. Alles wat de andere kant moet afleiden hangt juist
aan het mislukte pad: welke stappen geen bericht kregen, waarom de run stopte, wat er dan in
het rapport hoort.

Zonder dat pad bouwt de consumer zijn afleidlogica tegen een situatie die niet bestaat, en
blijkt dat pas bij de eerste echte run.

## 2026-08-07 — Een gate toetst niet wat je denkt dat hij toetst

De server-url stond er tweemaal in. De stub had er geen last van; alleen wie de spec léést,
zag het. De diff-gate toetst breuken, niet geldigheid, en oasdiff leest geen AsyncAPI — voor
de ene grens gold de gate wel en voor de andere niet, zonder dat iets dat zei.

Regel: een gate die niet kan toetsen, meldt dat hardop en laat de publicatie falen tenzij
het expliciet wordt bevestigd. Stilte is geen akkoord.

## 2026-08-07 — De aanname zat niet in het contract maar in het gereedschap eromheen

De consumer kon de geleverde stub niet draaien: geen Docker op de werklaptop, geen
abonnement. Het contract stelde die eis nergens — de verpakking wel. Zolang provider en
consumer dezelfde laptop deelden, was die aanname onzichtbaar.

Regel: lever een stub in de technologie van de consumer, niet in die van de provider. Wat je
meelevert is onderdeel van de afspraak, ook als het niet in de spec staat.

## 2026-08-07 — Waarom er is afgesplitst

De website is bewust bij een andere squad belegd, zodat de rol van PO werkelijk gespeeld
wordt in plaats van beschreven. Alle notities hierboven komen uit die keuze voort; geen
ervan was voorzien.

Wat nog niet is meegemaakt en het meest zal leren: de tweede wijziging. Een breaking change
over een grens die je niet zelf aanstuurt, met een deprecatieperiode en een squad met een
eigen backlog. Dat is scenario 03 en 05 in het echt.

## 2026-08-09 — Een example dat intern niet klopt, komt door geen enkele gate

Het scenario-example noemde `order` bij de deelsystemen en had geen enkele order-stap. Alle
stappen waren van payment of van de keten.

Niemand zag het. De consumer niet — die redeneerde over een geval dat dit example helemaal
niet kon voortbrengen, en kwam er pas op door zelf een scenario te verzinnen. De spec niet:
elk veld klopt afzonderlijk, `deelsystemen` is een geldige lijst en `stappen` ook. De stub
niet: die genereerde er netjes een run uit, alleen zonder order. En Spectral, die we
volgende stap invoeren, zal het ook niet zien — hij lint velden, en wat hier ontbreekt is
**samenhang tussen twee velden**.

Dat is de categorie: een example kan volledig geldig zijn en tegelijk onmogelijk. Er is geen
linter voor "wat je hier belooft, komt verderop niet voor".

Wat het gekost heeft was klein — de consumer merkte het op en de reparatie was een paar
regels. Wat het had kunnen kosten is groter: hun afleidlogica was gebouwd tegen een geval
dat de fixtures niet bevatten, en dat blijkt dan pas bij de eerste echte run.

## 2026-08-10 — De eerste workflow van dit project is een controle op een uitzondering

Deze repository gaat over pipelines en gates, en had er zelf geen: `.github/workflows/`
bestond niet. De eerste die er komt draait geen tests en bouwt geen artefact — hij controleert
of een uitzondering op een eigen regel nog aan zijn voorwaarde voldoet.

Dat is geen ironie maar een aanwijzing. Wat je aan anderen laat zien, richt je voor jezelf
het laatst in.

## 2026-08-10 — Een stub die alleen de huidige versie spreekt, kan een tolerantiefout niet tonen

De stub serveerde 1.0.0 en niets anders. Alles paste, dus alles leek goed — maar een consumer
die bij een onbekend veld, een onbekend berichttype of een onbekende enum-waarde omvalt, viel
daarmee niet door de mand. Dat blijkt pas bij de eerste additieve wijziging, in productie.

`TOLERANTIE=ja` laat de stub sturen wat een volgende versie zou kunnen sturen. Daarmee is
tolerantie iets om te draaien in plaats van te beloven.

**Deze week de derde keer dat de aanname in het gereedschap zat en niet in het contract.**
Eerst Docker, dat de ontvanger niet had. Toen `npx`, dat bij hem niet werkte. Nu een stub die
alleen het heden kent. Het contract klopte alle drie de keren; wat eromheen zat niet — en dat
staat nergens in een spec.

## 2026-08-17 — Een belofte in een README is een bewering zonder gate

De README van deze repository zegt over de stubbundel: **"Twee draaiwijzen, allebei
getoetst"**, met een tabel van wat je hoort te zien — een preflight, een 400 op een
niet-gedeclareerd veld, drie streams met hun aantallen.

Er was geen enkel script dat de bundel startte. `toets-tolerantie.sh` en
`bouw-stubbundel.sh` werken op bestanden; de enige plek waar de stream werd gelezen was een
`curl -N` in een README, met de hand. Wat er automatisch getoetst werd, was of de bundel te
**bouwen** viel — niet of hij werkte.

"Allebei getoetst" was dus waar op de dag dat iemand het deed, en daarna een bewering.

**Dezelfde klasse als de `/api/hoofdstukken`-aanname**, alleen langs een andere weg. Die kwam
uit een overdrachtsdocument en reisde mee omdat niemand hem tegen de spec hield; deze staat
in onze eigen README en overleefde omdat een README niet draait. Beide keren stond er geen
gate tussen, en beide keren klonk de bewering met elke herhaling zekerder.

**Wat het gevaarlijk maakt is de vorm.** Een README beschrijft wat er hoort te gebeuren, in
de tegenwoordige tijd, en leest daarmee als vastgesteld. Er is geen verschil in toon tussen
"dit is getoetst" en "dit is één keer nagekeken", en geen enkel gereedschap kent dat verschil
wél.

**Wat ervoor in de plaats komt:** `ci/toets-stubbundel.sh` start de bundel, stuurt een
niet-gedeclareerd veld en eist een 400, leest de stream en toetst elk bericht op JSON met een
`soort`. Draait mee in `controle.sh`. De regel in de README is daarmee voor het eerst waar op
elke dag in plaats van op één dag.

**En de manier van lezen hoort erbij.** Die toets leest **tot een verwacht aantal berichten,
met een tijdslimiet** — niet tot de verbinding sluit. Dat is nodig zodra de stub openblijft,
en het is sowieso strenger: een lus die op EOF wacht telt niet wat hij zag en komt bij nul
berichten net zo vrolijk terug als bij twintig. Een toets die hángt is bovendien erger dan
een die faalt: hij meldt niets, ook geen rood, en een pipeline die niets meldt lijkt nog te
draaien.

## 2026-08-15 — Erkende schuld: de structuurkant van `run-stream` is ongedekt

**De schuld heet: *kanaal- en operatiewijzigingen op `run-stream` worden door niets
getoetst.*** Een kanaal dat verdwijnt of van naam verandert, een operatie die weggaat, een
berichttype dat uit de `oneOf` valt — daar staat geen gate tussen.

**Wat er wél staat.** De inhoud van de berichten wordt beoordeeld: `ci/ontvangstschemas.sh`
zet de zes payloadschema's als `JSON`-artifacts in het register met `FORWARD`, en dat net is
gemeten en werkt. Onze wijzigingen zitten vrijwel altijd daar — een veld erbij, een veld dat
verplicht wordt, een type dat opschuift.

**Waarom de andere helft er niet is.** Twee kandidaten getoetst en beide afgevallen.

De `COMPATIBILITY`-regel van het register is voor artifacttype `ASYNCAPI` een no-op: zelfs
alle kanalen weghalen levert HTTP 200, terwijl dezelfde regel op een `OPENAPI`-artifact een
verwijderd pad netjes weigert met `RuleViolationException`.

`asyncapi diff` classificeert wél op kanaalniveau — een hernoemd kanaal geeft `breaking` —
maar hij is niet in te zetten binnen onze eigen regels. De CLI crasht zodra hij als non-root
draait (`TypeError: oclifHandler is not a function`), en `CLAUDE.md` eist dat containers als
non-root draaien. Read-only mount en `--network none` zijn wél haalbaar; `--user` niet.

**En waarom we die regel niet buigen.** De blootstelling zou klein zijn: twee specs, geen
netwerk, alleen lezen. Maar de waarde van een onwrikbare regel zit in dat woord, en de eerste
uitzondering is altijd de best onderbouwde — dat is precies waarom hij de deur opent. Onze
eigen eis aan een explain is hier bovendien niet te halen: die moet verifieerbaar zijn bij de
aanvrager, en de aanvrager is een externe CLI die we niet kunnen bevragen en die bij de
volgende versie anders kan werken.

Daar komt bij dat dit gereedschap bij elke meting minder deed dan het belooft: geen
payloadclassificatie, zwijgen bij ongeldige invoer, `--overrides` zonder effect, telemetrie
naar buiten, en nu root. Dat is geen gereedschap waarvoor je je strengste regel opgeeft.

**Wat de schuld waard is.** Kleiner dan hij klinkt. Een kanaal hernoemen of verwijderen is
een zichtbare, opzettelijke handeling — niet iets wat per ongeluk in een commit sluipt, zoals
een veld dat uit `required` valt. En het blijft niet onopgemerkt: de stubgeneratie en de
contractverificatie draaien op de spec, dus een verdwenen kanaal valt verderop alsnog om.
Alleen niet op het moment waarop het goedkoop is.

**Herzien op 2027-02-13**, tegelijk met de vrijstellingen in `ci/controle-gates.sh`, zodat één
ronde ze alle drie langsloopt. Eerder herzien zodra een van deze twee gebeurt:

- er is gereedschap dat de structuur van een AsyncAPI vergelijkt en als non-root draait;
- `run-stream` gaat naar `1.0.0` — en dat kan niet zolang deze schuld staat, want dan beloof
  je onveranderlijkheid op een grens waarvan de helft niet bewaakt wordt.

**Wat er wél uit de afgeblazen bouw is overgenomen:** de vorige versie wordt nu ook
gevalideerd vóór de diff. Dat is los van welk gereedschap er ooit komt — vergelijken met een
document dat niet klopt zegt niets, en het gereedschap zegt daar zelf niets over.

## 2026-08-15 — De gate moet meten tegen de belofte, niet tegen het artefact dat het dichtst bij de hand ligt

Het compatibiliteitsnet op de payloads van `run-stream` zou vanzelfsprekend op de
gepubliceerde schema's gaan: die staan in de spec, ze zijn er, en ze beschrijven de berichten.

Gemeten wat dat oplevert: **elke additieve wijziging wordt afgekeurd**, op alle zes, met
`OBJECT_TYPE_PROPERTY_SCHEMAS_NARROWED`. En dat is correct geredeneerd — die schema's staan op
`additionalProperties: false`, dus een ontvanger die ze streng toepast breekt op een onbekend
veld.

**Alleen is dat niet de belofte die wij doen.** Wij beloven dat een consumer een onbekend veld
mag negeren; dat staat in de tolerantie-eisen en de stubbundel levert er een schema voor mee.
Compatibiliteit is een uitspraak over wat de ontvanger verdraagt, dus hoort de gate op het
artefact dat de ontvanger beschrijft. Op de ontvangstvariant: `400` bij een veld uit
`required`, `200` bij een veld erbij. Precies goed.

**De klasse:** een gate die correct redeneert over het verkeerde artefact is gevaarlijker dan
een gate die fout redeneert. Hij is niet te betrappen op een denkfout — je moet je afvragen
welke belofte je eigenlijk aan het meten bent, en dat is een vraag die niemand stelt zolang de
gate rood en groen doet wat je verwacht. Hier zou hij scenario 02 hebben geblokkeerd: de
wijziging die de showcase als niet-brekend tóónt, afgekeurd door de gate die niet-brekend moet
bewijzen.

**Tweede keer dat "één schema kan niet twee rollen doen" beslissend is** (2026-08-10), nu op
een plek waar niemand het zocht. Toen ging het over wat je meelevert aan een consumer; nu over
waar je een gate op zet. Hetzelfde onderscheid, twee lagen uit elkaar — en dat suggereert dat
het geen detail van de stubbundel was maar een eigenschap van de grens zelf.

## 2026-08-15 — Een negatieve test zegt niets zolang de positieve niet is aangetoond

De vier kanaries op de ontvangstvariant vragen twee dingen af te keuren en twee door te
laten. Om ze te kunnen bouwen genereert het script eerst een geldig bericht uit het schema:
elk verplicht veld met een waarde die bij zijn type past.

Die generator vulde elk tekstveld met `"x"`. En `runId` heeft een `pattern`:
`^run-[0-9a-f]{6}$`. Dus was het "geldige" bericht ongeldig, en werd **élk** bericht
afgekeurd.

**Waarna twee van de vier kanaries groen stonden.** "Bericht zonder verplicht veld →
afgekeurd": klopt. "Bericht met verkeerd type → afgekeurd": klopt. Beide om een reden die
niets met hun vraag te maken had. Alleen de derde kanarie viel op, en die had ik net zo goed
kunnen missen als er één minder was geweest.

**De klasse:** een test die iets moet afkeuren, bewijst niets zolang niet is aangetoond dat
hij het goede geval wél doorlaat. Een gate die alles afkeurt is groen op elke negatieve test,
en dat is niet te onderscheiden van een gate die precies het juiste afkeurt.

De reparatie is een nulde controle vóór de vier: het geldige bericht moet aantoonbaar geldig
zijn, anders faalt de toets met de mededeling dat de kanaries niets zeggen. En de waarden
komen nu uit de `example` van de spec — die is per definitie geldig, want de stubgeneratie
eist hem al.

**Dat dit opdook in de gate die tegen stil groen is gebouwd, is het ongemakkelijkste
voorbeeld van de reeks.** Niet omdat het erger is dan de vorige, maar omdat het laat zien dat
kennis van het patroon niet beschermt. Alleen een controle die het goede geval aantoont, doet
dat — en die moet je expliciet opschrijven, want hij voelt overbodig.

## 2026-08-15 — De koppeling zat in de afleiding zelf

De zes payloadschema's krijgen elk hun eigen versie, zodat een wijziging in één schema er
niet vijf meesleept. Dat is hetzelfde besluit als waarom `scenario-api` en `run-stream` niet
aan elkaar hangen.

De eerste afleiding kopieerde `components.schemas` **in zijn geheel** in elk payloaddocument
— makkelijk, en het maakt elk document zelfstandig. Gevolg: één veld toevoegen aan
`RunGestartPayload` veranderde de inhoud van alle zes, en dan publiceert het script er zes.
Gemeten: `6 gepubliceerd, 0 ongewijzigd` waar er `1, 5` hoorde te staan.

**De koppeling die het besluit wilde vermijden, was ingebouwd in de afleiding die het besluit
moest uitvoeren.** En hij zou pas zijn opgevallen als iemand zich had afgevraagd waarom er
zes versienummers waren opgeschoven — dus waarschijnlijk nooit, want een versie erbij ziet
eruit als werk dat gedaan is.

Nu gaat alleen mee wat een payload werkelijk gebruikt, transitief gevolgd langs `$ref`. Daarna
`1 gepubliceerd, 5 ongewijzigd`.

**Wat het algemeen maakt:** een afleiding die meer meeneemt dan nodig, maakt artefacten die
samen bewegen zonder samen te horen. Dat is dezelfde fout als een gedeelde database tussen
deelsystemen, drie ordes kleiner.

## 2026-08-15 — Gereedschap dat zwijgt bij ongeldige invoer, meldt groen

Twee kandidaten getoetst als tweede net op `run-stream`, en beide vielen af — maar de manier
waarop de tweede afviel is een klasse.

**`asyncapi diff` gaf geen uitvoer en exitcode 0** op een document dat niet valideert. Niet
`{"changes": []}`, niet een foutmelding: niets, en groen. Een gate die zijn uitvoer op
`breaking` grept ziet dan geen breuk en publiceert. `asyncapi validate` meldt hetzelfde
document netjes als fout — het gereedschap wíst het, en de diff zweeg erover.

Dat is precies wat Spectral doet zonder regelset: `No ruleset has been found`, exitcode 0.
Twee verschillende gereedschappen, dezelfde vorm.

**De klasse:** gereedschap dat zwijgt bij invoer die het niet aankan, is niet neutraal — het
is groen. En groen is de gevaarlijkste uitkomst, want daar kijkt niemand naar. Elke gate die
op extern gereedschap leunt heeft daarom twee controles nodig die niets met de vraag te maken
hebben: valideert de invoer, en is de uitvoer welgevormd. Pas dan mag het oordeel geloofd
worden.

**Ik vond het doordat mijn eigen kanarie fout was** — ik zette een veld in `required` zonder
het als property te declareren, en de parser gooide het weg. Tweede keer deze maand dat een
verkeerde tegenproef de echte tekortkoming blootlegde. Dat is geen toeval: een tegenproef die
niet doet wat je denkt, is precies de invoer waarop gereedschap zich anders gedraagt dan de
documentatie belooft.

**En de telemetrie erbij.** De AsyncAPI-CLI stuurt bij elke aanroep gebruiksgegevens naar
buiten, standaard aan. Ons gereedschap draait op `--network none`, dus dat moet expliciet uit
en offline getoetst. Vierde keer dat de aanname in het gereedschap zat in plaats van in het
contract — na Docker bij de ontvanger, `npx` bij de ontvanger, en een stub die alleen het
heden kende.

## 2026-08-14 — De consumer vond wat onze eigen verificatiestap niet zag

Alle drie de releases leverden een bestand dat `SHA256SUMS` heette. Wie ze naar dezelfde map
haalt, overschrijft stil de vorige — en `sha256sum -c` verifieert daarna het verkeerde
bestand en meldt `OK`. Stil groen, in de verificatiestap zelf.

**Wij hebben dat niet gezien, en we hadden het kunnen zien.** Ons eigen release-script haalt
elke asset terug langs de publieke URL en vergelijkt de checksum. Dat werkt — maar het doet
het per release, in een eigen map, één tegelijk. De fout ontstaat pas bij wat een consumer
doet en wij niet: drie releases naast elkaar ophalen. Onze verificatie was juist en
onvolledig, en die twee zijn van buiten niet te onderscheiden.

**Showcase-website loste het aan hun kant op**, met een submap per artifact. Dat is een
correcte reparatie van ons probleem op de verkeerde plek: elke volgende consumer moet hem
opnieuw bedenken, en wie hem niet bedenkt krijgt een groene verificatie van het verkeerde
bestand. Aan onze kant is het één bestandsnaam.

**Dat dit de eerste bevinding van de consumer is, telt.** De vorige vier kwamen uit eigen
gereedschap of een eigen doorloop. Deze kwam van de andere kant van de grens, en precies
daar waar wij niet kijken omdat wij nooit twee contracten tegelijk ophalen. Een consumer
gebruikt een grens anders dan de provider hem test — dat is geen tekortkoming van onze tests
maar een eigenschap van grenzen, en het is het argument om er één te hebben die je kunt
bevragen in plaats van een afspraak.

**En het raakt de versie.** De URL-vorm is onderdeel van de grens; dat staat sinds
2026-08-13 zo in `contract-showcase-website.md`. Een assetnaam wijzigen is dus breaking, ook
al verandert er geen letter aan de spec — vandaar 0.10.0 op beide specs terwijl hun inhoud
gelijk blijft. Het contract is de grens en niet alleen het schema.

## 2026-08-14 — Een bewering die iedereen doorgeeft omdat niemand hem meet

De opdracht voor de sweep zei: `/api/hoofdstukken` wordt `/api/scenarios`, plus de schema's
`Hoofdstuk` en `hoofdstukId` — breaking op een gepubliceerd contract, dus showcase-website
moet meebewegen.

Geen van die drie bestaat. `scenario-api` heeft `/v1/scenarios`, `ScenarioId` en
`ScenarioSamenvatting`, en heeft dat altijd gehad. In de hele repository komt `hoofdstukId`
nul keer voor. Wat er wél stond is één woord in een beschrijving.

**De bewering kwam uit een overdrachtsdocument van dag één** en is sindsdien in elke prompt
meegereisd — inclusief de prompt waarin showcase-website werd opgedragen mee te bewegen met
een wijziging die niet bestond. Niemand heeft hem tegen de spec gehouden, omdat iedereen
aannam dat iemand anders dat had gedaan.

**Dat is precies wat een contract oplost, en de reden dat het meetbaar moet zijn.** Een
afspraak over een grens verwatert; een gepubliceerde spec is te bevragen. Hier ging het mis
op de laag erboven: niet het contract was onduidelijk, maar wat iedereen dácht dat erin
stond. `grep` op de spec kostte vijftien seconden en had de hele coördinatieronde
overbodig gemaakt.

**De les is niet "meet je aannames".** Die kent iedereen. De les is dat een bewering
gevaarlijker wordt naarmate hij vaker is doorgegeven: bij de vijfde herhaling klinkt hij als
vastgesteld feit, en juist dan kijkt niemand meer. Wat dit had gevangen is een gewoonte:
elke uitspraak over het contractoppervlak wordt geciteerd uit de spec, met bestandsnaam en
regelnummer, of hij geldt niet.

## 2026-08-14 — Eén commit, twee stille regressies, en het was de commit tegen stil groen

`5975384` heette *de lege-verzamelingseis toetsbaar*. Hij bracht `verwacht_minstens`, de
gate die eist dat een controle zegt hoeveel hij verwachtte te zien, en hij bracht twee
manieren om stil om te vallen.

De eerste is eerder gevonden: `vergelijk-rapporten.sh` riep `verwacht_minstens` aan zonder
`tools.sh` te sourcen — exitcode 127. De tweede kwam pas bij een handmatige doorloop, weken
later:

```sh
_n="$(grep -oE '[0-9]+ passed' "${UITVOER}" | tail -1 | cut -d' ' -f1)"
```

Maven schrijft `Tests run: 4` en nergens `passed`. De grep vindt niets en geeft 1, de pijp
geeft 1 door `pipefail`, de toekenning geeft 1, en `set -e` beëindigt het script. Geen
melding, geen spoor. De consumerverificatie was groen — `Tests run: 4`, `BUILD SUCCESS` — en
de stap eromheen viel om.

**De providerkant ontsnapte per toeval.** Schemathesis schrijft `1632 passed`, dus daar
matchte de grep. Dezelfde regel, hetzelfde script, andere uitkomst omdat een gereedschap
een ander woord koos. Scenario 01 draaide daardoor half: Payment groen, Order rood.

**Drie dingen die dit typeren.**

*De vorm is dodelijker dan de fout.* Een toekenning uit een falende pijp beëindigt onder
`set -euo pipefail` het hele script. Dezelfde grep als **argument** — `bijzonderheid
"$(grep …)"` — doet dat niet, en binnen een functie die zelf in `$( )` wordt aangeroepen
ook niet. Van de zestien plekken die een teller grepten waren er dus vier gevaarlijk en
twaalf ongevaarlijk. Wie de klasse ruimer stelt dan de meting, repareert twaalf plekken en
verstopt de vier.

*De comments beschreven precies de bescherming die de regel eronder ondermijnde.* Bij
`smoke.sh` en `gebruikersflow.sh` staat er dat het aantal er als eigen bewering staat, omdat
leunen op het standaardgedrag van het gereedschap te zwak is. De regel die dat implementeert
kon het script stil doden.

*En iemand heeft het bijna gezien.* In `pipeline-ci.sh` staat één `|| true`, precies bij de
stap die omvalt — op de `bijzonderheid`-regel eronder, die het niet nodig had. Iemand liep
tegen het gedrag aan, greep ernaast, en het `|| true` maakte de misgreep permanent
onzichtbaar: het gaf het gevoel dat het afgedekt was. Een pleister op de goede plek en het
verkeerde ding is erger dan geen pleister, want hij stopt het zoeken.

**Wat ervoor in de plaats komt:** een teller in `tools.sh` die de drie bekende vormen kent,
nooit beëindigt, en 0 teruggeeft als hij niets herkent — waarna `verwacht_minstens` oordeelt.
De teller telt, de gate oordeelt. Komt er een vierde uitvoervorm bij, dan is dat een alarm
en geen nul.

**Wat blijft staan.** `CONTRACT_STIJL=geschreven` en `beide` draaien nergens automatisch,
dus hun val was onzichtbaar en hun reparatie is alleen met de hand aangetoond. Dat is
dezelfde soort schuld als O15: geen fout, wel iets dat je moet weten dat je hebt.

## 2026-08-13 — Het document beschrijft iets dat er nog niet is, in de tegenwoordige tijd

Twee keer nu in één doorloop gevonden, en allebei op dezelfde manier: door het document naast
de repository te leggen, niet door een gate.

`showcase-cbt.md` beschreef twee CI-wrappers, GitLab en GitHub, die de vier pipelines
aanroepen. Er is er één, en die roept `ci/controle.sh` aan. En het beschreef Acceptatie als
"alle deelsystemen + `extern.yml`", terwijl `compose/extern.yml` niet bestaat.

**Geen van beide is een leugen.** Het zijn allebei ontwerpbesluiten die kloppen en die nog
niet gebouwd zijn. Het probleem zit in de werkwoordstijd: geschreven in de tegenwoordige tijd
leest een voornemen als een beschrijving, en dan gaat iemand ernaar handelen — een script
zoeken dat er niet is, of aannemen dat een omgeving een koppeling heeft die er niet is.

**Waarom dit hier hoort en niet bij de correcties zelf.** Het is een klasse en geen incident.
Dit document loopt bewust vooruit op de bouw: 1.13 zegt met zoveel woorden dat het de spec is
en de code de implementatie. Precies dáárdoor is de tegenwoordige tijd de standaardfout, en
niet de uitzondering. Wat schema-first oplevert aan scherpte, kost dit aan
onderhoudsdiscipline.

**Wat eraan te doen is, en wat niet.** Een gate is er niet: er bestaat geen controle die
"dit bestand wordt genoemd maar bestaat niet" scheidt van "dit bestand wordt genoemd als
toekomst". De enige maatregel is de formulering — *nog niet*, met de reden en waar het
vandaan komt — en de doorloop van document tegen repo als terugkerende handeling. Beide
gevallen zijn zo gecorrigeerd.

**En het is een aanwijzing bij de vorige notitie.** Daar bleek een deel van het contract
buiten elke gate te liggen; hier blijkt een deel van het ontwerp dat ook. Wat je niet kunt
afdwingen, moet je opschrijven op de plek waar iemand het leest — en dat blijft zwakker dan
een gate, altijd.

## 2026-08-13 — Een deel van dit contract ligt buiten de repo, en dus buiten elke gate

Squad 2 krijgt `ci/get-contract.sh` niet. Wat ze wél krijgen is een URL-vorm die ze zelf
opbouwen:

```
https://github.com/Sim007/showcase-cbt/releases/download/<artifact>-<versie>/<artifact>-<versie>.yaml
```

Dat is de juiste keuze — geef je het script mee, dan wordt onze ophaalmethode onderdeel van
de afspraak en kan de consumer breken doordat wij een script wijzigen terwijl de spec
onveranderd is. Maar er zit een gevolg aan dat groter is dan het lijkt.

**In die URL staan de eigenaarsnaam en de reponaam.** Die zijn nu onderdeel van de belofte, en
ze staan buiten de repository. Een hernoeming op GitHub — van eigenaar, van reponaam, of alleen
van hoofdlettergebruik — is daarmee een breaking change die in geen enkele commit terug te
vinden is en die geen enkele gate ziet. Er verandert niets aan de spec, niets aan de code,
niets aan een bestand; de grens breekt in een instellingenscherm.

Dat is geen theoretisch geval. De repository is ooit van `sim007` naar `Sim007` gegaan;
GitHub stuurde nog door, en dat is precies waarom het niemand opviel.

**Wat we eraan doen:** de vorm staat expliciet in `contract-showcase-website.md`, met erbij
dat wijziging ervan breaking is, en `RELEASE_REPO` staat in `ci/registers.env` met dezelfde
waarschuwing. Meer is er niet: dit is niet af te dwingen vanuit een repository die zelf
verhuist.

**Wat het algemeen maakt:** elk contract heeft een deel dat buiten het artefact ligt. Bij een
REST-grens is dat de hostnaam, bij een queue de naam van de topic, hier de URL-vorm. Dat deel
is even bindend als het schema en wordt door niets bewaakt. De diff-gate ziet het schema; wie
de omgeving eromheen verandert, komt langs geen enkele controle.

## 2026-08-13 — Een gate die op tekst toetst, toetst een voornemen

`ci/controle-gates.sh` is geschreven om stil groen uit te roeien. Zijn regel was: elk script
in `ci/` moet `verwacht_minstens` aanroepen. Zijn toets was: komt de tekst `verwacht_minstens`
in het bestand voor.

Dat is niet dezelfde vraag. `ci/vergelijk-rapporten.sh` riep hem aan zonder
`ci/lib/tools.sh` te sourcen. De aanroep stond er, de functie bestond niet, en onder
`set -euo pipefail` is dat exitcode 127 op de regel zelf. De gate zag de tekst en meldde
groen.

**Een tekstmatch toetst dat iemand het van plan was.** Of het ook gebeurt, staat er los van.
Dat is hetzelfde patroon als de lus die groen meldde over veertien berichten die niemand
bekeek: in beide gevallen was er een controle, en in beide gevallen ging er nul werk doorheen.
De vorm verschilt, de fout is dezelfde.

**Drie dingen maken dit geval scherper dan de vorige twee.**

*Hij brak in dezelfde commit wat hij moest bewaken.* De lege-verzamelingseis werd in één
commit aan negen scripts toegevoegd. Acht daarvan sourcete `tools.sh` al; de negende niet. De
gate die bij diezelfde commit hoorde, keurde het resultaat goed.

*Hij is geschreven door wie het patroon kende.* Niet uit onwetendheid — er lagen al twee
gedateerde notities over stil groen, van dezelfde hand, en de aanleiding staat in de
scriptkop. Kennis van het patroon beschermt niet tegen het patroon. Alleen een controle die
iets uitvoert doet dat.

*Het bleef maanden onzichtbaar omdat het enige dat hem draait buiten CI valt.*
`vergelijk-rapporten.sh` werd wél aangeroepen — door de demo van hoofdstuk 1, als laatste
inhoudelijke scène. Die demo draait op een laptop wanneer iemand hem start, en niet bij een
push. De aftrekking waar hoofdstuk 0 en 1 samen op rusten, was in de praktijk stuk: de scène
drukte zijn kop af en viel om, vlak voor het slotbeeld. Een gate zonder pipeline eromheen is
een script dat toevallig bestaat.

**Wat ervoor in de plaats komt.** Een oplosbaarheidstoets: elk commandowoord moet oplossen
naar een builtin, iets in PATH, een functie in het script zelf, of een functie uit een bestand
dat het script sourcet. Haal de source-regel weg en het antwoord verandert — dat is wat een
tekstmatch niet doet. Plus twee regels eromheen: `controle.sh` draait elk script dat zonder
deelsystemen kan draaien, en elk script moet ergens worden aangeroepen.

**En toen deed de nieuwe toets het ook zelf.** De eerste versie draaide de resolutie in een
subshell. `controle-gates.sh` sourcet zelf `tools.sh`, dus die subshell erfde precies de
functie die het onderzochte script miste — en de tegenproef meldde groen. De toets keek naar
zijn eigen omgeving in plaats van naar die van het script. Zichtbaar geworden doordat de
tegenproef er was; zonder die tegenproef was er een tweede gate bijgekomen die niets deed.

**Dat is de les, en hij is ongemakkelijker dan "schrijf betere gates".** Bij elk van deze
vier gevallen was er een controle, en bij elk ging er niets doorheen. Het onderscheid dat
telt is niet streng of soepel, maar: heeft deze controle werk verzet, en waar is dat te zien.
Vandaar `verwacht_minstens`, vandaar de tegenproef als vaste stap, en vandaar dat een gate
die nergens draait geen gate is.

**Wat nog openstaat.** 18 van de 28 scripts draaien nog steeds alleen in een demo, en dus
alleen als iemand kijkt. Zie het besluit van dezelfde datum hierboven.


## 2026-08-18 — Een beperking die je opschrijft in plaats van toetst, is een belofte zonder net

Bij `stubbundel-0.11.0` stond in de README: wie midden in een run verbindt, krijgt de
opgenomen opening van die run en niet de stand van dat moment. Eerlijk opgeschreven, met de
reden erbij, op twee plekken — de bundel-README en de melding aan squad 2.

Squad 2 liep er binnen een dag op stuk. En toen bleek het geen beperking te zijn maar een
stub die zijn eigen spec tegensprak: `run: null` betekent volgens het schema dat er geen run
loopt.

**Dat is de derde keer deze maand**, en de drie zijn dezelfde beweging:

| | Wat er is opgeschreven | Wat het was |
|---|---|---|
| README stubbundel | "twee draaiwijzen, allebei getoetst" | één keer met de hand nagekeken |
| kanaalbeschrijving | de hartslag staat in proza, er is geen schema onder | ongedekt tot er een `HARTSLAG_MS` kwam |
| bundel-README | "wie midden in een run aansluit, krijgt een momentopname die achterloopt" | non-conformiteit met de eigen spec |

**Waarom opschrijven zo aantrekkelijk is:** het voelt als het tegenovergestelde van verzwijgen.
Je bent eerlijk over een tekort, je zet het op de plek waar de lezer het vindt, en je bent
klaar. Wat je in werkelijkheid hebt gedaan is de verantwoordelijkheid verplaatst naar iemand
die het document leest op het moment dat het ertoe doet — en dat moment komt bij niemand.

**Wat het onderscheid wél is.** Een beperking is legitiem als hij volgt uit iets wat je niet
kúnt: geen schema in AsyncAPI 2.6.0 voor een commentaarregel, geen `asyncapi diff` die als
non-root draait. Dan schrijf je hem op met een naam en een herzieningsmoment, zoals O13. Wat
hier gebeurde was iets anders: er was geen belemmering, alleen een regel die ik zelf te breed
had geformuleerd. Een beperking die uit een eigen keuze volgt, is geen beperking maar een
besluit — en een besluit hoort een toets te krijgen of te worden teruggedraaid.

**De vuistregel die eruit volgt.** Ga je een tekort opschrijven, stel dan eerst één vraag:
kan ik hier een toets omheen zetten die rood wordt als het misgaat? Kan dat, dan is
opschrijven het verkeerde antwoord. Kan het niet, dan is het opschrijven pas het goede — en
dan hoort er een naam en een datum bij, want anders is het over drie weken niemands probleem.

## 2026-08-21 — Een regel die niet meeschaalt breekt niet, hij wordt betekenisloos

`generate-stream-stub.sh` koos de faalstap van de gestopte opname met: **de eerste gate die
niet de laatste is.** Bij zes stappen wees die stap 3 aan, en dat was precies het verhaal —
Payment faalt, de stappen van Order erna krijgen niets, en een deelsysteem dat nooit aan de
beurt kwam is het geval waar de afleidregel van de consumer op moet passen.

Toen de stamdata naar 27 stappen ging, was de eerste gate stap 1. De run stierf onmiddellijk,
26 stappen kregen geen bericht, en de opname toonde niets meer dan "er ging meteen iets mis".

**Er brak niets.** De generator liep door, alle berichten voldeden aan hun schema, elke gate
bleef groen, en het bestand was geldig. Dat is wat deze klasse anders maakt dan de vier
gevallen uit de gate-notitie: daar meldde een controle groen over werk dat niet gedaan was.
Hier werd het werk gedaan, klopte de uitkomst, en was alleen de *betekenis* weg.

**Waar dat aan lag: de regel beschreef een positie en niet een eigenschap.** "De eerste gate"
viel bij zes stappen toevallig samen met "de gate die iets tegenhoudt nadat er werk gelukt
is". Dat toeval was de hele werking, en het stond nergens.

Nu staat de eigenschap er wél: de eerste **contract**-gate, met als terugval de eerste gate
die werk vóór zich heeft en een ander deelsysteem ná zich. Die tweede trap is geen sier —
scenario 00 heeft per definitie geen contract-gate, dus daar is het de enige route.

**Waar dit nog meer zit.** Elke plek waar een keuze op een index of een volgorde rust in
plaats van op een kenmerk: `[0]`, "de eerste", "de laatste op één na". Ze werken tot de
verzameling groeit, en dan blijven ze werken zonder nog te kloppen. Een gate ziet dat niet;
alleen iemand die de uitkomst léést ziet het, en die kijkt pas als er iets anders misgaat.

## 2026-08-21 — Er bestaat geen echte showcase-CBT

Bij de verkenning voor "de website sluit aan op de echte kant" is gezocht naar wat
`/v1/runs`, `/v1/scenarios` of een SSE-stream serveert. Het antwoord is: **uitsluitend
`ci/stubbundel/stub.js`.** Er is geen server, geen endpoint, geen stream. De echte kant is
een verzameling shellscripts die een markdown-rapport schrijft.

**Er is weken over deze grens gepraat alsof er twee kanten waren.** Er is er één, en de
andere is de stub. Twee specs gepubliceerd, drie versies uitgegeven, een bundel geleverd,
een compatibiliteitsrichting per grens gekozen, een heartbeat afgesproken — allemaal over
een provider die niet draait.

**Dat maakt geen van die stappen verkeerd.** Spec-first betekent dat het contract er eerder
is dan de implementatie; dat is de bedoeling en niet een fout. Wat er misging is dat niemand
het verschil hardop maakte. "Showcase-CBT is provider van `run-stream`" en "showcase-CBT
zóu provider zijn van `run-stream`" zijn in elk document van deze maand hetzelfde opgeschreven.

**Dezelfde klasse als de `/api/hoofdstukken`-aanname**, en als "twee draaiwijzen, allebei
getoetst". Iedereen ging ervan uit, niemand mat het, en de bewering klonk met elke herhaling
zekerder. Het verschil is de omvang: dit ging niet over een endpoint of een regel in een
README maar over de vraag of de helft van de grens bestaat.

**Wat het meteen verklaart.** Waarom de stub zo zwaar leunt: hij is niet het hulpmiddel naast
de echte kant, hij ís de kant. Elke bevinding van squad 2 deze maand ging over de stub, en
elke reparatie zat in de stub. Dat leek toeval en was het niet.

**Wat eruit volgt als werkwijze:** bij een grens hoort de vraag "wat serveert dit vandaag" een
antwoord met een commando, niet met een naam. `curl` het, of het bestaat niet.
