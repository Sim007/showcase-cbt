# 0. Startsituatie

> Vereist: niets. Hoofdstuk 1 vereist dit hoofdstuk.

Wat er draait vóórdat contracttesten bestaan. Dit hoofdstuk varieert niets en toont geen
enkele techniek uit de showcase — het staat er om te laten zien waar de rest vandaan komt.

**Wat het aantoont en waarom het zo werkt** staat in
[docs/showcase-cbt.md](../docs/showcase-cbt.md), hoofdstuk 0. Hieronder staat hoe je het
draait.

---

## De korte weg

```sh
00-start/demo/demo.sh          # de twee bedrijven achter elkaar
00-start/demo/demo.sh --stap   # met een pauze ertussen, voor een presentatie
ci/opruimen-alles.sh           # alles weg: omgevingen, register, rapporten
```

Daarna gaat [hoofdstuk 1](../01-basis/README.md) verder waar dit ophoudt.

---

## De twee bedrijven

### a — de uitgangssituatie

Beide deelsystemen op Test en Acceptatie, versie 1.0.0. Dit gaat stil: het is het gegeven
en niet het argument.

```sh
ci/toon-versies.sh test
ci/toon-versies.sh acceptatie
```

Wat er ligt en wat niet:

| | Er wel | Er niet |
|---|---|---|
| De grens | het schema, als bestand naast de code | het register |
| De implementatie | beide kanten, gebouwd en gedeployd | — |
| De toetsing | unit, integratie, e2e | de contracttesten |

### b — een release zoals het nu gaat

Payment repareert een bug en gaat naar Acceptatie, langs de pipelines die er al waren:

```sh
ci/pipeline-microservice.sh payment payment-api
ci/pipeline-test.sh         payment 1.0.1
ci/pipeline-acceptatie.sh   payment 1.0.1
```

De bugfix zit in [PaymentService.java](../deelsystemen/payment/payment-api/src/main/java/cbt/payment/PaymentService.java):
bedragen worden op twee decimalen opgeslagen. Puur intern — `amount` staat niet in de
response, dus aan de grens verandert er niets.

**Let op wat er niet gebeurt.** In geen enkele stap komt het schema van de grens voor. Het
ligt in `contracts/`, het wordt niet gelezen, en niets valt erop.

---

## Wat je moet zien

Alles wordt groen, en dat is terecht — de fix is goed. De vraag die erop volgt is:

> Payment 1.0.1 staat op Acceptatie en alles was groen. **Weet Order dat?**

Deze wijziging raakte de grens niet. Maar dat weet je omdat iemand de code heeft gelezen,
niet omdat de pipeline het heeft vastgesteld — en een wijziging die de grens wél raakt,
geeft precies dezelfde uitkomst.

---

## Het rapport

```
00-start/rapport/rapport-cbt-00.md      chronologisch, met een tijdstip per stap
00-start/rapport/rapport-cbt-00.html    dezelfde inhoud, om te laten zien
```

Leg hem naast `01-basis/rapport/rapport-cbt-01.html`. Die van hoofdstuk 0 is korter en
bevat geen enkele regel over een contract, een stub of drift. Dat verschil is de hele
showcase, in twee bestanden.
