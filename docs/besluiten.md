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
spec-first-opzet binnensluipt, en de valutalijst zou in drie plekken staan in plaats van
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
en zou een spec zonder implementatie niet te publiceren zijn — terwijl spec-first juist
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

