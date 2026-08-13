# Besluiten — de afwegingen erachter

Wat er is besloten, waarom, en wat het kost. Per besluit een datum, want een afweging is
houdbaar zolang de omstandigheden gelijk blijven en niet langer.

Het besluit zelf staat kort in `showcase-cbt.md`. Dit bestand bevat het bewijs: wat er is
geprobeerd, wat eruit kwam, en wat er is opgegeven. Zonder dat leest een keuze als een
voorkeur, en dan gaat iemand hem over een half jaar opnieuw voeren.

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

