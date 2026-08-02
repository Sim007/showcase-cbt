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
hoofdstuk. De afwegingen achter de keuzes staan in
[docs/besluiten.md](docs/besluiten.md), de beveiligingsbevindingen in
[docs/security.md](docs/security.md).

| Pad | Inhoud |
|---|---|
| `ci/` | de gedeelde scripts, één exemplaar — nooit een kopie in een hoofdstukmap |
| `contracts/` | alle specs, per grens en versie |
| `compose/` | wat van geen enkel deelsysteem is: het register, de stub, externe koppelingen |
| `playwright/` | config en gedeelde specs: smoke, later UI |
| `deelsystemen/` | alle services, één map per deelsysteem; daaronder een map per service |
| `01-basis/` … `09-frontend-shell/` | een map per hoofdstuk, met alleen tests: demoscript, hoofdstukspecifieke specs, README |

## Vereisten

Docker en bash. Op Windows via WSL2, niet via Git Bash. `curl` gebruiken de scripts van
de host; extern gereedschap — oasdiff, jq, yq, ajv, Maven, WireMock, Schemathesis — draait
als container op een vastgepinde tag via [ci/lib/tools.sh](ci/lib/tools.sh). Er is dus
geen JDK of Maven op de machine nodig.

## Beginnen

Het register is gedeeld en staat los van de hoofdstukken. Eén keer omhoog en het blijft
staan.

```sh
docker compose -f compose/registry.yml up -d
```

Het register draait op <http://localhost:8080>, de UI op <http://localhost:8888>. Opslag
is in memory: na een herstart is hij leeg, en dat is voor een demo precies goed.

Variabelen — versies, poorten, het adres van de buur — staan in
[.env.example](.env.example). Kopieer naar `.env` als je iets wilt afwijken.

Ga daarna naar het hoofdstuk dat je wilt zien.

## De hoofdstukken

| # | Hoofdstuk | Waar het over gaat | Staat |
|---|---|---|---|
| 1 | [Basis (API)](01-basis/) | Order → Payment, REST, het hele mechanisme | in aanbouw |
| 2 | [Wijziging zonder breuk](02-wijziging-zonder-breuk/) | additieve wijziging, v1.1.0 | nog niet |
| 3 | [Breaking wijziging](03-breaking/) | twee majors naast elkaar | nog niet |
| 4 | [Acceptatie](04-acceptatie/) | de gebruikersflow over de keten | nog niet |
| 5 | [Sunset](05-sunset/) | een oude major uit de runtime | nog niet |
| 6 | [Async](06-async/) | Payment → Notification, AsyncAPI | nog niet |
| 7 | [SOAP](07-soap/) | externe betaalprovider, WSDL/XSD | nog niet |
| 8 | [Frontend binnen een deelsysteem](08-frontend-binnenkant/) | Angular → eigen backend | nog niet |
| 9 | [Frontend in shell](09-frontend-shell/) | shell ↔ remote, module-API | nog niet |

Hoofdstuk 1 is de referentie: die schrijft de opzet volledig uit, de andere vullen aan.

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
| De toegestane valuta's staan zowel in de spec als in de code | `PaymentService` | afgedwongen door de drift-check; met de hand gelijk houden is een risico dat je moet zien |

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
| Compose | Eén gedeeld netwerk laat de stub en het echte deelsysteem dezelfde servicenaam dragen. Dan is het toeval wie antwoordt, en meet een contractverificatie niets. Nu een netwerk per compose-project. |
| Contractverificatie | Zes gebreken gevonden in een implementatie met vijftien groene tests, waaronder een response die zijn eigen schema schond. |
| Stub versus echte buur | WireMock accepteert standaard een h2c-upgrade, Tomcat niet. De JDK-HttpClient vraagt die aan, dus Order werkte tegen het echte Payment en niet tegen de stub. Een stub die méér kan dan wat hij vervangt, is net zo fout als een die minder kan. |
