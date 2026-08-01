# CLAUDE.md

Showcase van contract-based testing. Geen productiecode. Het doel is één werkend voorbeeld per grenstype dat op een laptop draait en het mechanisme laat zien.

De volledige beschrijving staat in `docs/showcase-cbt.md`. Bij twijfel over wat iets moet doen: dat document is de bron, niet je eigen aanname. Wijkt de opdracht af van het document, meld dat dan en wijzig niets.

## Onwrikbaar

- `ci/`, `contracts/`, `playwright/` en `deelsystemen/` staan uitsluitend op de hoofdmap. Nooit een kopie in een hoofdstukmap.
- Services staan alleen in `deelsystemen/`, één exemplaar per deelsysteem. Een genummerde map bevat nooit een service.
- Een deelsysteemmap is een houder en zelf geen service. Elke service staat eronder in een eigen map: `deelsystemen/payment/payment-api/`, `deelsystemen/payment/payment-mf/`. Ook een frontend hoort daar en niet in een hoofdstukmap.
- Namen enkelvoud: `payment`, niet `payments`. Zo heten het deelsysteem, de map en het artifact in het register hetzelfde.
- Een genummerde map bevat alleen tests: demoscript, hoofdstukspecifieke specs, README.
- Compose staat op drie plekken, elk met een eigen reden. De CI-omgeving is per deelsysteem: `deelsystemen/<naam>/docker-compose.ci.yml`, met alle services van dat deelsysteem plus stubs. Test en Acceptatie stellen alle deelsystemen samen en staan op de hoofdmap in `compose/`. Het register ook, want dat is gedeelde infrastructuur.
- De spec wordt nooit van schijf gelezen. Alles gaat via `ci/get-contract.sh`.
- Geen logica in yaml. Pipelinebestanden roepen uitsluitend scripts uit `ci/` aan.
- Nooit committen wat gegenereerd is: stubmappings, `build/`, `node_modules/`, `.env`.
- Geen `latest`-tags, niet voor images en niet voor contractversies.

## Werkwijze

- Begin elke opdracht met een plan en wacht op akkoord. Bouw daarna in kleine commits, één onderwerp per commit.
- Elke commit die `docs/showcase-cbt.md` raakt, bumpt de versieregel en krijgt een regel in de wijzigingslog. Eén commit is één versie: nooit twee wijzigingen onder hetzelfde nummer, want dan valt er niet meer naar terug te vallen.
- Kom je iets tegen dat niet klopt met het document of dat niet werkt zoals verwacht: meld het en stop. Niet stilzwijgend een alternatief kiezen.
- Voeg geen library toe zonder één regel in de commit waarom hij nodig is. Zo min mogelijk dependencies.
- Vereenvoudigingen die bewust voor de demo zijn gemaakt — register zonder authenticatie, opslag in memory — krijgen een commentaarregel op de plek zelf en komen in de README onder "Vereenvoudigingen".

## Terminologie

Nederlands voor de kernbegrippen, Engels voor techniek.

| Term | Betekenis |
|---|---|
| grens | interface waar eigenaarschap wisselt tussen deelsystemen |
| contract | de gepubliceerde specificatie van een grens |
| deelsysteem | wat één team bezit en zelfstandig naar productie brengt; bestaat uit services |
| service | één bouwbaar en deploybaar onderdeel van een deelsysteem: een microservice of een micro-frontend. Nooit "component" |
| contractverificatie | toetsing van een implementatie aan de gepubliceerde spec |

De piramide heeft drie lagen: `unit`, `integratie` en `e2e`. Contracttesten voegt er geen vierde aan toe — contractverificatie ís integratie, met de spec als norm in plaats van de test.

De JUnit-tags zijn `unit`, `integratie` en `contract`. Die derde tag bestaat omdat de pipeline hem op een ander moment draait, na de deploy op de CI-omgeving, en niet omdat het een aparte laag is. Gebruik die woorden overal hetzelfde: in scriptnamen, tags en pipeline-uitvoer.

## Veiligheid

- Geen secrets in code, yaml of compose. Alles uit environment, met `.env.example` in de repository.
- Actuator stelt uitsluitend `health` en `info` bloot. Nooit een wildcard.
- Foutresponses volgen het `Error`-schema uit het contract: geen stacktrace, geen interne paden.
- Images op een vastgepinde tag, containers draaien als non-root.
- Scripts: `set -euo pipefail`, geen `curl -k`, nooit credentials op de commandoregel.

## Platform

Docker en bash zijn de enige vereisten. Werkt op Linux, macOS en Windows via WSL2 — niet via Git Bash. Extern gereedschap draait als container via `ci/lib/tools.sh`; roep die tools nergens anders rechtstreeks aan.

Scripts zijn POSIX-compatibel: geen bash 4-constructies, geen GNU-specifieke vlaggen op `sed`, `date` of `grep`.
