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

