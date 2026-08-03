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

## De drie delen

```sh
ci/pipeline-microservice.sh payment payment-api
ci/pipeline-microservice.sh order   order-api

ci/pipeline-test.sh payment 1.0.0
ci/pipeline-test.sh order   1.0.0

ci/pipeline-acceptatie.sh payment 1.0.0
ci/pipeline-acceptatie.sh order   1.0.0
```

Dat is de hele bestaande gang: unit, integratie, een image, deploy, smoke, gebruikersflow.

**Let op wat er niet gebeurt.** In geen enkele stap komt het schema van de grens voor. Het
ligt in `contracts/`, het wordt niet gelezen, en niets valt erop.

Wat er wél draait:

| | Er wel | Er niet |
|---|---|---|
| De grens | wordt geraakt — de smoke loopt er doorheen | is nergens onderwerp van een test |
| De norm | in de test, door de schrijver bedacht | buiten de test, gepubliceerd |
| Het register | — | — |

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
| Regels | 22 | 35 |
| Regels over contract, stub, drift of conformiteit | **0** | het verschil |

Omdat de dekking gelijk is, ís dat verschil het werk dat contracttesten toevoegt.
