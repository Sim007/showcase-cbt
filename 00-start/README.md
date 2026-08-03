# 0. Startsituatie

> Vereist: niets. Hoofdstuk 1 vereist dit hoofdstuk.

Wat er draait vóórdat contracttesten bestaan: twee deelsystemen, door de bestaande
pipelines, naar Test en Acceptatie. Alles groen.

Hoofdstuk 1 doet **exact hetzelfde** — dezelfde deelsystemen, dezelfde versies — maar dan
mét contracttesten. Het verschil tussen de twee rapporten is daarmee precies wat
contracttesten toevoegt, en niets anders.

**Wat het aantoont en waarom het zo werkt** staat in
[docs/showcase-cbt.md](../docs/showcase-cbt.md), hoofdstuk 0. Hieronder staat hoe je het
draait.

---

## De korte weg

```sh
00-start/demo/demo.sh          # dit hoofdstuk
00-start/demo/demo.sh --stap   # met een pauze ertussen, voor een presentatie
ci/opruimen-alles.sh           # alles weg: omgevingen, register, rapporten
```

Daarna gaat [hoofdstuk 1](../01-basis/README.md) verder waar dit ophoudt.

---

## Elk deelsysteem zijn eigen weg

```sh
ci/pipeline-microservice.sh payment payment-api
ci/pipeline-ci.sh           payment 1.0.0
ci/pipeline-test.sh         payment 1.0.0
ci/pipeline-acceptatie.sh   payment 1.0.0

ci/pipeline-microservice.sh order order-api
ci/pipeline-ci.sh           order 1.0.0
ci/pipeline-test.sh         order 1.0.0
ci/pipeline-acceptatie.sh   order 1.0.0

ci/pipeline-gebruikersflows.sh acceptatie
```

Dat is de hele bestaande gang. Twee dingen zijn de moeite waard om apart te bekijken.

**De CI-omgeving bestaat hier al.** Order roept Payment aan, dus daar staat een stub in
zijn plaats — met de hand geschreven, door Order zelf:
[stub-handgeschreven/](../deelsystemen/order/stub-handgeschreven/). Hij dekt het gelukkige
pad en verder niets, want er is geen norm om meer uit af te leiden. Payment is provider en
roept niemand aan, dus zijn CI-omgeving heeft geen stub nodig.

**De gebruikersflow hangt aan geen enkele deploy.** Hij spant over de keten, dus hij draait
één keer nadat beide deelsystemen er staan. In dit hoofdstuk levert dat geen spanning op —
de tribe deployt toch samen.

**Let op wat er niet gebeurt.** In geen enkele stap komt het schema van de grens voor. Het
ligt in `contracts/`, het wordt niet gelezen, en niets valt erop.

| | Er wel | Er niet |
|---|---|---|
| De grens | wordt geraakt — de smoke loopt er doorheen | is nergens onderwerp van een test |
| De stub | er is er een op de CI-omgeving | hij komt niet uit een contract |
| De norm | in de test, door de schrijver bedacht | buiten de test, gepubliceerd |

---

## Wat je moet zien

Alles wordt groen, en terecht. Het punt is niet dat er iets misgaat — het punt is dat je
**aan deze uitkomst niet kunt zien óf er iets misgaat aan de grens.**

Order's integratietest mockt Payment en schrijft het antwoord van de buur zelf voor:

```java
@MockitoBean
private PaymentClient paymentClient;
```

Die mock is niet fout. Hij is **onbewijsbaar** — hij bevestigt wat de schrijver dacht dat
Payment doet, en blijft groen als Payment verandert.

---

## Het rapport

```
00-start/rapport/rapport-cbt-00.md      chronologisch, met een tijdstip per stap
00-start/rapport/rapport-cbt-00.html    dezelfde inhoud, om te laten zien
```

Leg hem naast `01-basis/rapport/rapport-cbt-01.html`:

| | Hoofdstuk 0 | Hoofdstuk 1 |
|---|---|---|
| Deelsystemen | order en payment | order en payment |
| Versies | alle 1.0.0 | alle 1.0.0 |
| Omgevingen | CI, Test, Acceptatie | CI, Test, Acceptatie |
| Regels | 28 | 37 |

Omdat de dekking gelijk is, ís dat verschil het werk dat contracttesten toevoegt — negen
regels: de diff-gate met publicatie en terughalen, een gegenereerde stub in plaats van een
geschreven, de verificatie aan beide kanten, de drift-check en de versieconformiteit.
