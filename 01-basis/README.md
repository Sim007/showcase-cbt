# 1. Basis (API)

> Vereist: niets, behalve het register uit de [hoofd-README](../README.md#beginnen).

Twee deelsystemen, één grens: Order (consumer) → Payment (provider), REST, spec-first,
contract in Apicurio. Dit hoofdstuk is de referentie-implementatie: het beschrijft de
opzet die de andere showcases alleen nog aanvullen.

**Wat het aantoont en waarom het zo werkt** staat in
[docs/showcase-cbt.md](../docs/showcase-cbt.md), hoofdstuk 1. Hieronder staat hoe je het
draait.

---

## De korte weg

```sh
01-basis/demo/demo.sh          # de vijf scènes achter elkaar
01-basis/demo/demo.sh --stap   # met een pauze ertussen, voor een presentatie
01-basis/demo/opruimen.sh      # alles weg, ook Test en Acceptatie
```

De demo loopt de hele gang af, van contract tot gebruikersflow op Acceptatie, en eindigt
met het rapport. Hij ruimt zelf op voordat hij begint, dus je kunt hem meteen opnieuw
draaien. Achteraf blijven Test en Acceptatie staan om naar te kijken; `opruimen.sh` haalt
ook die weg.

Het demoscript bedenkt niets zelf: het roept dezelfde pipelines aan die een squad ook
draait. Wil je begrijpen wat er gebeurt, lees dan hieronder verder — dat zijn precies de
commando's die de demo uitvoert.

---

## De vier pipelines

Bouwen gebeurt per **microservice**, deployen per **deelsysteem**. Dat levert vier soorten
pipeline op, en de gate is telkens de vorige omgeving groen.

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

**Dit is de scène waar de demo om draait.** Order's pipeline draait volledig groen terwijl
Payment nergens bestaat: wat hij tegenkomt is een stub die uit de spec uit het register is
gegenereerd.

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

Deploy, healthcheck en de smoke van dát deelsysteem. Geen contractverificatie: die hoort op
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

Ze staan nu toevallig gelijk. Vanaf hoofdstuk 2 lopen ze uit elkaar, en dan is het
onderscheid het punt.

### 4 — het deelsysteem naar Acceptatie

```sh
ci/pipeline-acceptatie.sh payment 1.0.0
ci/pipeline-acceptatie.sh order   1.0.0
```

Deploy en de gebruikersflow met het label van dat deelsysteem. Geen smoke: die is op Test
al gedraaid, en herhalen verplaatst werk naar de duurste plek.

Een gebruikersflow spant over deelsystemen heen, dus dit werkt pas als de omgeving compleet
is. De eerste keer dat je een lege Acceptatie vult, deploy je ze dus allebei voordat de
flow iets kan zeggen; daarna schuift elk deelsysteem op zijn eigen tempo op. Ontbreekt er
een, dan zegt de pipeline dat met zoveel woorden.

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
| `ci/deploy.sh` | chart + release + omgevingswaarden |

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
| Order draait groen zonder dat Payment bestaat | de consumer is onafhankelijk van zijn buur |
| De stub komt uit het register, niet uit de test | de norm ligt buiten de test |
| `600.00` levert `CANCELLED`, geen fout | een afgewezen betaling is geen contractschending |
| `amount: 0` levert 400 `INVALID_AMOUNT` | dát is er wel een |
| Drie versies naast elkaar op één endpoint | contract, microservice en deelsysteem bewegen los |
