# showcase-cbt

Een showcase die contract-based testing aantoonbaar maakt: één werkend voorbeeld per
grenstype, draaiend op één laptop, om het mechanisme te tonen in plaats van te
beschrijven. Het fictieve systeem is Order → Payment → Notification.

**Dit is showcasecode, geen productiecode.** Het is een demonstratie en geen levering.
Wie zo wil gaan testen, richt dat zelf in, in eigen deelsystemen en eigen pipelines. Dat
een map bruikbaar is als startpunt, is een prettig gevolg en geen belofte.

Licentie: [MIT](LICENSE). De volledige beschrijving staat in
[docs/showcase-cbt.md](docs/showcase-cbt.md).

## Structuur

| Pad | Inhoud |
|---|---|
| `ci/` | de gedeelde scripts, één exemplaar — nooit een kopie in een hoofdstukmap |
| `contracts/` | alle specs, per grens en versie |
| `compose/registry.yml` | Apicurio, het contractregister, gedeeld |
| `playwright/` | config en gedeelde specs: smoke, later UI |
| `01-basis/` … `09-frontend-shell/` | een map per hoofdstuk; 02 t/m 05 gebruiken de deelsystemen uit `01-basis/` |

## Vereisten

Docker en bash. Op Windows via WSL2, niet via Git Bash. `curl` gebruiken de scripts van
de host; extern gereedschap — oasdiff, jq — draait als container op een vastgepinde tag
via [ci/lib/tools.sh](ci/lib/tools.sh).

## Stap 1

Nog geen deelsystemen: dit is het contractmechanisme alleen. Registry omhoog, spec erin,
spec eruit.

```sh
docker compose -f compose/registry.yml up -d

ci/publish-contract.sh order-payment payment-api 1.0.0 \
  contracts/order-payment/v1.0.0/openapi.yaml

ci/get-contract.sh order-payment payment-api 1.0.0
```

Het register draait op <http://localhost:8080>, de UI op <http://localhost:8888>.
`get-contract.sh` schrijft de spec naar `build/contracts/` en drukt dat pad af. Dat is
het enige pad waarlangs iets aan de spec komt: nooit van schijf, nooit uit de repo van
de provider.

## Vereenvoudigingen

Bewuste versimpelingen voor de demo. Ze staan hier bij elkaar zodat niemand ze aanziet
voor een blauwdruk.

| Vereenvoudiging | Waar | In het echt |
|---|---|---|
| Het register kent geen authenticatie | `compose/registry.yml` | OIDC ervoor, met rollen per team |
| Het register slaat op in memory en is leeg na een herstart | `compose/registry.yml` | sql of kafkasql op een externe database |
| `publish-contract.sh` wordt met de hand aangeroepen | `ci/publish-contract.sh` | vanuit een pipeline; dat verandert wie het script start, niet wat het doet |

## Bevindingen

Wat tijdens het bouwen afweek van het document of van de verwachting. Ze staan hier
omdat een showcase die alleen het geslaagde pad toont, minder waard is.

| Onderwerp | Bevinding |
|---|---|
| Apicurio 3.3.1 | `APICURIO_STORAGE_KIND=mem` uit de 3.0-documentatie bestaat niet meer en laat de container falen. Zonder die variabele draait 3.3.1 op h2 in memory, wat is wat de showcase nodig heeft. |
| Apicurio 3.3.1 | Er is geen `/q/health`-endpoint; de healthcheck draait op `system/info`. |
| Compatibility rule | De rule `BACKWARD` doet voor artifact type `OPENAPI` in 3.3.1 wél inhoudelijk werk: een breuk die de gate omzeilt, krijgt HTTP 400 met een `RuleViolationException`. Het tweede net uit §1.9 van het document bestaat dus echt. |
| Diff-gate | `currency` uit de `required`-lijst halen is voor oasdiff géén breaking wijziging: een verzoek wordt daarmee minder streng. Het document gebruikt dat in §2 als voorbeeld van een breuk die geweigerd wordt; dat klopt niet. De omgekeerde beweging — `currency` weer verplicht maken — is wél breaking en wordt wél geweigerd. |
| Contractpad | Het document schrijft `contracts/order-payment/v1/openapi.yaml`, de repository gebruikt `v1.0.0/`. |
