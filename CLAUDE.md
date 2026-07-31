# CLAUDE.md

Showcase van contract-based testing. Geen productiecode. Het doel is één werkend voorbeeld per grenstype dat op een laptop draait en het mechanisme laat zien.

De volledige beschrijving staat in `docs/showcase-cbt.md`. Bij twijfel over wat iets moet doen: dat document is de bron, niet je eigen aanname. Wijkt de opdracht af van het document, meld dat dan en wijzig niets.

## Onwrikbaar

- `ci/`, `contracts/` en `playwright/` staan uitsluitend op de wortel. Nooit een kopie in een hoofdstukmap.
- Hoofdstuk 02 t/m 05 bevatten geen services; die gebruiken `01-basis/`.
- De spec wordt nooit van schijf gelezen. Alles gaat via `ci/get-contract.sh`.
- Geen logica in yaml. Pipelinebestanden roepen uitsluitend scripts uit `ci/` aan.
- Nooit committen wat gegenereerd is: stubmappings, `build/`, `node_modules/`, `.env`.
- Geen `latest`-tags, niet voor images en niet voor contractversies.

## Werkwijze

- Begin elke opdracht met een plan en wacht op akkoord. Bouw daarna in kleine commits, één onderwerp per commit.
- Kom je iets tegen dat niet klopt met het document of dat niet werkt zoals verwacht: meld het en stop. Niet stilzwijgend een alternatief kiezen.
- Voeg geen library toe zonder één regel in de commit waarom hij nodig is. Zo min mogelijk dependencies.
- Vereenvoudigingen die bewust voor de demo zijn gemaakt — register zonder authenticatie, opslag in memory — krijgen een commentaarregel op de plek zelf en komen in de README onder "Vereenvoudigingen".

## Terminologie

Nederlands voor de kernbegrippen, Engels voor techniek.

| Term | Betekenis |
|---|---|
| grens | interface waar eigenaarschap wisselt tussen deelsystemen |
| contract | de gepubliceerde specificatie van een grens |
| deelsysteem | een zelfstandig te releasen applicatie |
| contractverificatie | toetsing van een implementatie aan de gepubliceerde spec |

Testlagen heten `unit`, `integratie` en `contract`, als JUnit-tag en in de pipeline-uitvoer. Gebruik die woorden overal hetzelfde.

## Veiligheid

- Geen secrets in code, yaml of compose. Alles uit environment, met `.env.example` in de repository.
- Actuator stelt uitsluitend `health` en `info` bloot. Nooit een wildcard.
- Foutresponses volgen het `Error`-schema uit het contract: geen stacktrace, geen interne paden.
- Images op een vastgepinde tag, containers draaien als non-root.
- Scripts: `set -euo pipefail`, geen `curl -k`, nooit credentials op de commandoregel.

## Platform

Docker en bash zijn de enige vereisten. Werkt op Linux, macOS en Windows via WSL2 — niet via Git Bash. Extern gereedschap draait als container via `ci/lib/tools.sh`; roep die tools nergens anders rechtstreeks aan.

Scripts zijn POSIX-compatibel: geen bash 4-constructies, geen GNU-specifieke vlaggen op `sed`, `date` of `grep`.
