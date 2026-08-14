# showcase-cbt

Een showcase die contract-based testing aantoonbaar maakt: één werkend voorbeeld per
grenstype, draaiend op één laptop, om het mechanisme te tonen in plaats van te
beschrijven. Het fictieve systeem is Order → Payment → Notification.

**Dit is showcasecode, geen productiecode.** Het is een demonstratie en geen levering.
Wie zo wil gaan testen, richt dat zelf in, in eigen deelsystemen en eigen pipelines. Dat
een map bruikbaar is als startpunt, is een prettig gevolg en geen belofte.

Licentie: [MIT](LICENSE).

## Waar staat wat

**Wat er is en waarom** staat in [docs/showcase-cbt.md](docs/showcase-cbt.md) — het
ontwerp, van begrip tot pipeline. **Hoe je het draait** staat in de README van elk
scenario. De afwegingen achter de keuzes staan in
[docs/besluiten.md](docs/besluiten.md), de beveiligingsbevindingen in
[docs/security.md](docs/security.md).

| Pad | Inhoud |
|---|---|
| `ci/` | de gedeelde scripts, één exemplaar — nooit een kopie in een scenariomap |
| `contracts/` | alle specs, per grens en versie |
| `compose/` | wat van geen enkel deelsysteem is: het register, de stub, externe koppelingen |
| `playwright/` | config en gedeelde specs: smoke, later UI |
| `deelsystemen/` | alle services, één map per deelsysteem; daaronder een map per service |
| `00-start/` … `09-frontend-shell/` | een map per scenario, met alleen tests: demoscript, scenariospecifieke specs, README |

## Vereisten

Docker en bash. Op Windows via WSL2, niet via Git Bash. `curl` gebruiken de scripts van
de host; extern gereedschap — oasdiff, jq, yq, ajv, Maven, Playwright, WireMock,
Schemathesis — draait als container op een vastgepinde tag via
[ci/lib/tools.sh](ci/lib/tools.sh). Er is dus geen JDK, Maven of Node op de machine nodig.

**Optioneel, alleen voor je editor.** Omdat er niets lokaal geïnstalleerd is, kan je IDE
`@playwright/test` niet vinden en onderstreept hij de imports in de smoke-specs. De runs
hebben er geen last van; wil je die kringels weg, haal de types dan lokaal binnen:

```sh
. ci/lib/tools.sh && npm install --no-save "@playwright/test@${PLAYWRIGHT_VERSIE}"
```

De versie komt uit `ci/lib/tools.sh`, zodat er maar één plek is die hem vastlegt.
`node_modules/` staat in `.gitignore`.

## Beginnen

Niets opstarten. Elk scenario zet neer wat het nodig heeft en ruimt het daarna op.

**Scenario 0 heeft met opzet géén register** — dat is het hele punt van dat scenario: het
schema ligt in `contracts/`, het wordt niet gelezen, en niets valt erop. Start je er tóch
één, dan staat hij er ongebruikt bij, naast de zin dat hij er niet is.

Scenario 1 zet het register zelf omhoog en laat het daarna staan, zodat je erin kunt kijken:
het draait op <http://localhost:8080>, de UI op <http://localhost:8888>. Opslag is in memory,
dus na een herstart is hij leeg — voor een demo precies goed.

Variabelen — versies, poorten, het adres van de buur — staan in
[.env.example](.env.example). Kopieer naar `.env` als je iets wilt afwijken.

Begin daarna bij scenario 0 en 1, in die volgorde. Samen zijn ze het hele verhaal: eerst
wat er draait zonder contracttesten, dan wat die toevoegen.

```sh
00-start/demo/demo.sh          # de startsituatie, en een release zoals het nu gaat
01-basis/demo/demo.sh          # het register en de contracttesten erbij
ci/opruimen-alles.sh           # alles weg: omgevingen, register, rapporten
```

Leg daarna de twee rapporten naast elkaar. **Ze dekken hetzelfde:** dezelfde twee
deelsystemen, dezelfde versies, dezelfde omgevingen, dezelfde pipelines. Het enige verschil
is dat scenario 1 contracttesten doet — 28 regels tegenover 37, en die negen zijn met naam
te noemen.

> Het werk dat contracttesten toevoegt = wat scenario 1 doet − wat scenario 0 doet.

Beide zijn groen, en dat is met opzet: deze showcase toont het mechanisme en niet het
invoeren ervan. In een bestaande omgeving levert de eerste contractverificatie meestal een
lijst op — en dat is het echte werk van een squad. Wat het gereedschap doet is die lijst
eindig en precies maken.

## De scenario's

| # | Scenario | Waar het over gaat | Staat |
|---|---|---|---|
| 0 | [Startsituatie](00-start/) | hoe het gaat **zonder** contracttesten | **werkt** |
| 1 | [Basis (API)](01-basis/) | hoe het gaat **met** contracttesten — Order → Payment, REST | **werkt** |
| 2 | [Wijziging zonder breuk](02-wijziging-zonder-breuk/) | additieve wijziging, v1.1.0 | nog niet |
| 3 | [Breaking wijziging](03-breaking/) | twee majors naast elkaar | nog niet |
| 4 | [Acceptatie](04-acceptatie/) | de gebruikersflow over de keten | nog niet |
| 5 | [Sunset](05-sunset/) | een oude major uit de runtime | nog niet |
| 6 | [Async](06-async/) | Payment → Notification, AsyncAPI | nog niet |
| 7 | [SOAP](07-soap/) | externe betaalprovider, WSDL/XSD | nog niet |
| 8 | [Frontend binnen een deelsysteem](08-frontend-binnenkant/) | Angular → eigen backend | nog niet |
| 9 | [Frontend in shell](09-frontend-shell/) | shell ↔ remote, module-API | nog niet |

Scenario 1 is de referentie: die schrijft de opzet volledig uit, de andere vullen aan.
Scenario 0 varieert niets — het laat zien waar de rest vandaan komt.

## De stubbundel voor showcase-website

Naast de scenario's loopt een echte grens: showcase-CBT levert `scenario-api` en
`run-stream` aan de squad die showcase-website bouwt. Die krijgt een bundel om tegen te
bouwen — uitpakken en starten, verder niets.

```sh
ci/bouw-stubbundel.sh showcase-cbt scenario-api 0.9.0 run-stream 0.9.0 0.9.0
```

Levert `build/stubbundel-0.9.0.tgz` op, ongeveer 300 KB. De drie versies staan er los in:
de twee specs bewegen elk op hun eigen tempo, en de bundel heeft een eigen nummer omdat hij
van allebei is afgeleid. Welke versies erin zitten staat in `manifest.json`, met checksum.

**Twee draaiwijzen, allebei getoetst.** Ze horen hetzelfde te doen; de eerste is er omdat
de ontvanger geen Docker heeft, de tweede omdat wij die aanname niet nóg een keer willen
maken zonder hem te controleren.

| | Nodig | Commando |
|---|---|---|
| **Lokaal** | Node 20 of nieuwer, geen netwerk | `tar -xzf …tgz && cd bundel && node stub.js` |
| **Docker** | Docker, geen netwerk nodig | `docker run --rm --network none -v "$PWD:/w" -w /w node:22.23.2-alpine sh -c 'tar -xzf *.tgz && cd bundel && node stub.js'` |

**Wat je in beide gevallen hoort te zien:**

```
preflight (OPTIONS /v1/runs)            204
POST /v1/runs met een onbekend veld     400
stream, verbinding 1                    21 berichten, eindigt op run-afgerond voltooid
stream, verbinding 2                    12 berichten, eindigt op run-afgerond gestopt
stream, verbinding 3                    14 berichten, begint met een momentopname
```

Die 400 is de reden dat de bundel bestaat: hij weigert wat niet in de spec staat, net als de
echte kant. Krijg je een 201, dan draait er iets anders dan deze bundel.

Met `TOLERANTIE=ja` stuurt de stream wat een volgende contractversie zou kunnen sturen — een
onbekend veld, een onbekend berichttype en een onbekende enum-waarde. Zie
[ci/stubbundel/README.md](ci/stubbundel/README.md).

## Vereenvoudigingen

Bewuste versimpelingen voor de demo. Ze staan hier bij elkaar zodat niemand ze aanziet
voor een blauwdruk.

| Vereenvoudiging | Waar | In het echt |
|---|---|---|
| Het register kent geen authenticatie | `compose/registry.yml` | OIDC ervoor, met rollen per team |
| Het register slaat op in memory en is leeg na een herstart | `compose/registry.yml` | sql of kafkasql op een externe database |
| `publish-contract.sh` wordt met de hand aangeroepen | `ci/publish-contract.sh` | vanuit een pipeline; dat verandert wie het script start, niet wat het doet |
| Beide deelsystemen gebruiken H2 in memory en zijn leeg na een herstart | `application.yml` van elke service | een eigen database per deelsysteem; gedeelde opslag blijft uitgesloten |
| Identificaties lopen op vanaf 1 per proces (`pay-000001`) | `PaymentService`, `OrderService` | een UUID of een sequence. Hier bewust deterministisch: een demo mag niet van toeval of van de tijd afhangen |
| De toegestane valuta's staan zowel in de spec als in de code | `PaymentService` | gegenereerde code, of één bron voor beide. Nu vangt de contractverificatie alleen de kant waarop de code te weinig accepteert |

## Bevindingen

Wat tijdens het bouwen afweek van de verwachting. Ze staan hier omdat een showcase die
alleen het geslaagde pad toont, minder waard is. De uitgebreide versie met de afwegingen
staat in [docs/besluiten.md](docs/besluiten.md).

| Onderwerp | Bevinding |
|---|---|
| Apicurio 3.3.1 | `APICURIO_STORAGE_KIND=mem` uit de 3.0-documentatie bestaat niet meer en laat de container falen. Zonder die variabele draait 3.3.1 op h2 in memory. |
| Apicurio 3.3.1 | Er is geen `/q/health`-endpoint; de healthcheck draait op `system/info`. |
| Prism 5.15.10 | Start niet — `TypeError: Cannot read properties of undefined`. 5.14.2 draait wel. |
| Diff-gate | oasdiff kent de gevolgen van `additionalProperties: false` niet: een veld uit een requestschema halen levert een warning op en geen error. |
| Diff-gate | oasdiff onderscheidt in zijn exitcode een gevonden breuk (1) van een mislukte vergelijking (102). Wie dat niet doet, meldt "breaking wijziging" terwijl er niets is getoetst. |
| Compose | Eén gedeeld netwerk laat de stub en het echte deelsysteem dezelfde servicenaam dragen. Dan is het toeval wie antwoordt, en meet een contractverificatie niets. Nu is de omgeving het netwerk en is elk deelsysteem daarin een eigen project. |
| Drift versus contractverificatie | Een generator probeert methoden uit op paden die hij uit de spec kent, en ziet dus een ongedocumenteerde `GET` op een bekend pad. Een pad dat nergens in de spec staat, kan hij niet raden — dat ziet alleen de drift-check. |
| Contractverificatie | Zes gebreken gevonden in een implementatie met vijftien groene tests, waaronder een response die zijn eigen schema schond. |
| Stub versus echte buur | WireMock accepteert standaard een h2c-upgrade, Tomcat niet. De JDK-HttpClient vraagt die aan, dus Order werkte tegen het echte Payment en niet tegen de stub. Een stub die méér kan dan wat hij vervangt, is net zo fout als een die minder kan. |
