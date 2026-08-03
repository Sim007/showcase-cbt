# 1. Basis (API)

> Vereist: [hoofdstuk 0](../00-start/README.md). Dit hoofdstuk begint waar dat ophoudt.

Twee deelsystemen, één grens: Order (consumer) → Payment (provider), REST, spec-first,
contract in Apicurio. Dit hoofdstuk is de referentie-implementatie: het beschrijft de
opzet die de andere showcases alleen nog aanvullen.

**Wat het aantoont en waarom het zo werkt** staat in
[docs/showcase-cbt.md](../docs/showcase-cbt.md), hoofdstuk 1. Hieronder staat hoe je het
draait.

---

## De korte weg

```sh
00-start/demo/demo.sh          # eerst hoofdstuk 0: de startsituatie
01-basis/demo/demo.sh          # dan dit: het register en de contracttesten erbij
01-basis/demo/demo.sh --stap   # met een pauze ertussen, voor een presentatie
ci/opruimen-alles.sh           # alles weg: omgevingen, register, rapporten
```

De demo opent het rapport in je browser en **vult het tijdens de run**: elke stap komt
erbij, de tellers lopen op, en zolang hij bezig is ververst de pagina zichzelf. Aan het
eind stopt dat vanzelf en staat het eindrapport er. Zet je een terminal naast de browser,
dan zie je het deelsysteem door de gang lopen en bij elke gate een oordeel krijgen.

Alleen de terminal is ook goed: `CBT_LIVE=0 01-basis/demo/demo.sh`.

De demo begint waar hoofdstuk 0 ophoudt: beide deelsystemen draaien al, en er is geen
register. Hier komt eerst het register erbij, en daarna loopt dezelfde gang nog een keer —
dezelfde deelsystemen, dezelfde versies, nu met gate, stub en verificatie aan beide kanten.
Zo zie je wat contracttesten toevoegt in plaats van dat je het moet geloven.

Draai eerst `00-start/demo/demo.sh`; deze stopt met een melding als er niets op Test staat.
Achteraf blijven Test en Acceptatie staan om naar te kijken; `ci/opruimen-alles.sh` haalt
ook die weg.

**Opnieuw draaien kan meteen.** De demo ruimt eerst zijn eigen sporen op — het register en
de CI-omgevingen — en laat staan wat hoofdstuk 0 heeft neergezet. Dat is nodig omdat een
contractversie onveranderlijk is: `1.0.0` een tweede keer publiceren levert een 409, en dat
hoort ook zo.

Het demoscript bedenkt niets zelf: het roept dezelfde pipelines aan die een squad ook
draait. Wil je begrijpen wat er gebeurt, lees dan hieronder verder — dat zijn precies de
commando's die de demo uitvoert.

---

## De pipelines

Bouwen gebeurt per **microservice**, deployen per **deelsysteem**, en het contract heeft
een eigen pipeline. De gate is telkens de vorige omgeving groen — behalve bij de laatste,
en dat is met opzet.

### 0 — het schema naar het register

```sh
ci/pipeline-contract.sh order-payment payment-api 1.0.0 \
  contracts/order-payment/v1.0.0/openapi.yaml
```

De diff-gate met de publicatie, en daarna terughalen ter controle. Het contract heeft een
eigen pipeline omdat het een eigen levenscyclus heeft: een grens wijzigt op een ander moment
dan de code die hem implementeert, en spec-first vraagt dat het contract er eerder is.

### 1 — de microservice bouwen en testen

```sh
ci/pipeline-microservice.sh payment payment-api
ci/pipeline-microservice.sh order   order-api
```

Unit, integratie, en een image met de versie uit de `pom.xml`. De contractlaag zit hier
niet in: die vraagt een draaiend deelsysteem.

### 2 — het deelsysteem naar een efemere CI-omgeving

```sh
ci/pipeline-ci.sh order   1.0.0
ci/pipeline-ci.sh payment 1.0.0
```

**Dit is de scène waar de demo om draait.** Order's pipeline komt tot een oordeel zonder
Payment in zijn omgeving: daar staat een stub die uit de spec uit het register is
gegenereerd, onder dezelfde servicenaam. Payment draait ondertussen gewoon op Test en
Acceptatie — het punt is niet dat hij nergens is, maar dat Order hem niet nodig heeft.

Wat deze pipeline doet, leidt hij af uit `deelsystemen/<naam>/grenzen.env`:

| | Payment | Order |
|---|---|---|
| `SERVEERT` | `order-payment payment-api 1.0.0` | — |
| `PINT` | — | `order-payment payment-api 1.0.0` |

Serveert een deelsysteem een contract, dan volgen de drift-check en de providerverificatie.
Pint hij er een, dan een stub en de consumerverificatie in beide richtingen. Payment doet
nu het eerste, Order het tweede — en in hoofdstuk 6 doet Payment allebei zonder dat er een
script bij hoeft. Een rol hoort bij een grens, niet bij een deelsysteem.

De omgeving wordt na afloop opgeruimd, ook als er iets faalt.

### 3 — het deelsysteem naar Test

```sh
ci/pipeline-test.sh payment 1.0.0
ci/pipeline-test.sh order   1.0.0
```

Deploy, versieconformiteit en de smoke van dát deelsysteem. Geen contractverificatie: die hoort op
de CI-omgeving, waar het deelsysteem alleen staat en een run goedkoop is.

Elk deelsysteem meldt daarna alle drie de versieniveaus:

```sh
curl -s http://localhost:8081/actuator/info
```

| Wat | Waarde | Betekenis |
|---|---|---|
| `deelsysteem.versie` | 1.0.0 | wat er gedeployd is |
| `build.version` | 1.0.0 | de microservice, uit de pom |
| `contract.serveert` | 1.0.0 | de grens, uit het register |

Ze staan nu alle drie op 1.0.0, en dat is opzet: tussen hoofdstuk 0 en 1 verandert er geen
enkel versienummer, zodat het verschil tussen de twee rapporten alleen contracttesten kan
zijn. Vanaf hoofdstuk 2 lopen ze uit elkaar, en dan is het onderscheid het punt.

### 4 — het deelsysteem naar Acceptatie

```sh
ci/pipeline-acceptatie.sh payment 1.0.0
ci/pipeline-acceptatie.sh order   1.0.0
```

Deploy en healthcheck, meer niet. Geen smoke: die is op Test al gedraaid, en herhalen
verplaatst werk naar de duurste plek.

**Geen gebruikersflow ook.** Die spant over de keten en kan dus niet van één squad zijn:
zou hij hier hangen, dan blokkeert de afwezigheid van je buur jouw release. Geen van beide
pipelines hierboven wacht op de ander.

### 5 — de gebruikersflows over de keten

```sh
ci/pipeline-gebruikersflows.sh acceptatie
```

Gedeeld, gepland, en **geen gate**. Hij kijkt eerst of de omgeving compleet is, zodat de
melding gaat over wat er ontbreekt in plaats van over een rode test. Ontbreekt er een
deelsysteem, dan is dat een signaal voor de tribe — iemand moet nog deployen — en geen
reden om een deployvolgorde af te spreken.

---

## Het testbewijs

Elke stap van elke pipeline komt in één rapport, bij het hoofdstuk waar het over gaat:

```
01-basis/rapport/rapport-cbt-01.md      chronologisch, met een tijdstip per stap
01-basis/rapport/rapport-cbt-01.html    dezelfde inhoud, om te laten zien
```

De demo maakt de HTML aan het eind; los kan ook met `ci/rapport-html.sh`. Die pagina is
zelfstandig — alle opmaak zit erin, dus doorsturen werkt. Openen is genoeg:

```sh
open 01-basis/rapport/rapport-cbt-01.html      # macOS
xdg-open 01-basis/rapport/rapport-cbt-01.html  # Linux
```

| Tijd | Onderdeel | Stap | Uitkomst | Bijzonderheden |
|---|---|---|---|---|
| 19:30:22 | payment-api 1.0.0 | unit | groen | Tests run: 9 |
| 19:30:43 | payment 1.0.0 → CI | drift | groen | 2 operaties komen overeen |
| 19:30:57 | payment 1.0.0 → CI | contractverificatie, provider | groen | 1632 generated, 1632 passed |
| 19:30:57 | payment 1.0.0 → CI | — | oordeel | voldoet aan payment-api 1.0.0 |

Dat is wat "releasen op testbewijs" concreet maakt: niet dát het groen was, maar wát er
wanneer is aangetoond en tegen welke contractversie.

De map `*/rapport/` staat in `.gitignore` — een testbewijs hoort bij een run en niet bij de
broncode. Een ander hoofdstuk schrijft naar zijn eigen bestand:

```sh
CBT_RAPPORT="$PWD/02-wijziging-zonder-breuk/rapport/rapport-cbt-02.md" \
  ci/pipeline-ci.sh payment 1.1.0
```

De machineleesbare kant staat er los van: JUnit XML in `build/contract-rapport/` en
`build/smoke-rapport/`, plus Surefire per module.

---

## De losse onderdelen

De pipelines knopen deze scripts aan elkaar. Los aanroepen kan ook, en dat is handig om te
zien wat er gebeurt.

| Script | Wat het doet |
|---|---|
| `ci/publish-contract.sh` | publiceert via de diff-gate; bij een leeg register valt er niets te vergelijken |
| `ci/get-contract.sh` | haalt de spec op — het enige pad waarlangs iets aan de spec komt |
| `ci/generate-stub.sh` | de acht stappen uit §1.6, met twee artefactcontroles aan het eind |
| `ci/verify-contract.sh` | contractverificatie, `provider` of `consumer` |
| `ci/drift.sh` | biedt de service precies de operaties die het contract belooft? |
| `ci/smoke.sh` | de smoke van een deelsysteem, of `keten` over alle grenzen |
| `ci/gebruikersflow.sh` | de flows van één deelsysteem, of `keten` over alles |
| `ci/deploy.sh` | chart + release + omgevingswaarden |
| `ci/versieconformiteit.sh` | wordt elke pin op deze omgeving daar ook geserveerd? |
| `ci/toon-versies.sh` | wat draait er, uitgelezen bij de containers zelf |

---

## Zien dat het ook rood wordt

Een controle die nooit rood wordt, is geen controle. Vier manieren om dat aan te tonen:

| Breek dit | Wat er rood wordt |
|---|---|
| `HttpStatus.CREATED` → `OK` in `PaymentController` | contractverificatie: *Undocumented HTTP status code* |
| een `example` uit de spec halen en publiceren | de stubgeneratie, met opzet |
| een endpoint toevoegen dat niet in het contract staat | de drift-check |
| `HttpPaymentClient` een extra veld laten meesturen | de consumerverificatie |

Die laatste is de leerzaamste: de stub accepteert dat extra veld gewoon en Order blijft
groen draaien. Alleen de toetsing aan de spec ziet het.

---

## Wat je moet zien

| Scène | Waarom het ertoe doet |
|---|---|
| Order draait groen zonder Payment in zijn CI-omgeving | de consumer is onafhankelijk van zijn buur |
| De stub komt uit het register, niet uit een hoofd | vergelijk met `deelsystemen/order/stub-handgeschreven/` uit hoofdstuk 0 |
| `600.00` levert `CANCELLED`, geen fout | een afgewezen betaling is geen contractschending |
| `amount: 0` levert 400 `INVALID_AMOUNT` | dát is er wel een |
| Geen Acceptatie-pipeline wacht op de ander | de gebruikersflow is gedeeld en geen gate |
| Drie versies naast elkaar op één endpoint | contract, microservice en deelsysteem bewegen los |
