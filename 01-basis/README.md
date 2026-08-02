# 1. Basis (API)

> Vereist: niets, behalve het register uit de [hoofd-README](../README.md#beginnen).

Twee deelsystemen, één grens: Order (consumer) → Payment (provider), REST, spec-first,
contract in Apicurio. Dit hoofdstuk is de referentie-implementatie: het beschrijft de
opzet die de andere showcases alleen nog aanvullen.

**Wat het aantoont en waarom het zo werkt** staat in
[docs/showcase-cbt.md](../docs/showcase-cbt.md), hoofdstuk 1. Hieronder staat hoe je het
draait.

> **In aanbouw.** De pipelinescripts en het demoscript bestaan nog niet, dus hieronder
> staat de handmatige route. Zodra `ci/pipeline-provider.sh` en `ci/pipeline-consumer.sh`
> er zijn, vervangen die de stappen 3 tot en met 6.

---

## 1. Het contract publiceren

Een contract komt niet in het register omdat iemand het erin zet, maar omdat het door de
diff-gate is gekomen.

```sh
ci/publish-contract.sh order-payment payment-api 1.0.0 \
  contracts/order-payment/v1.0.0/openapi.yaml
```

Bij een leeg register meldt hij dat er niets te vergelijken valt en publiceert hij. De
gate doet pas werk vanaf hoofdstuk 2.

Ophalen kan alleen via het script — nooit van schijf, nooit uit de repo van de provider:

```sh
ci/get-contract.sh order-payment payment-api 1.0.0
```

## 2. De deelsystemen bouwen

```sh
export CBT_ROOT="$PWD" && . ci/lib/tools.sh

mvn deelsystemen/payment/payment-api test
mvn deelsystemen/order/order-api test

docker build -t cbt/payment-api:1.0.0 deelsystemen/payment/payment-api
docker build -t cbt/order-api:1.0.0   deelsystemen/order/order-api
```

De testlagen zijn los te draaien, zoals de pipeline dat straks doet:

```sh
mvn deelsystemen/payment/payment-api test -Dgroups=unit
mvn deelsystemen/payment/payment-api test -Dgroups=integratie
```

## 3. De CI-omgeving van Order — zonder Payment

Dit is de scène waar de demo om draait: **Order werkt terwijl Payment nergens draait.**

Eerst de stub, gegenereerd uit de spec uit het register:

```sh
ci/generate-stub.sh order-payment payment-api 1.0.0 deelsystemen/order/stub-scenarios
```

Hij loopt de acht stappen uit §1.6 af en eindigt met twee artefactcontroles: elke
responsebody tegen zijn schema, en elke operation minstens één mapping. Ontbreekt er een
`example` in de spec, dan faalt hij — met opzet.

Dan de omgeving. Een omgeving is een **compose-project**: het deelsysteem plus wat het
daar nodig heeft.

```sh
STUB_MAPPINGS="$PWD/build/stub" \
docker compose -p ci-order \
  -f deelsystemen/order/docker-compose.yml \
  -f compose/stub.yml up -d
```

De stub draait onder de servicenaam `payment-api`, dus Order merkt geen verschil met Test.

```sh
curl -X POST http://localhost:8082/orders \
  -H 'Content-Type: application/json' -d '{"amount":49.95,"currency":"EUR"}'
# {"orderId":"ord-00001","status":"CONFIRMED","paymentId":"pay-88f21c"}

curl -X POST http://localhost:8082/orders \
  -H 'Content-Type: application/json' -d '{"amount":600.00,"currency":"EUR"}'
# {"orderId":"ord-00002","status":"CANCELLED","paymentId":"pay-88f21c"}
```

Die tweede komt uit een scenario-mapping: de spec beschrijft per status één response, en
een afgewezen betaling volgt niet uit de spec. Zie `deelsystemen/order/stub-scenarios/`.

```sh
docker compose -p ci-order -f deelsystemen/order/docker-compose.yml -f compose/stub.yml down
```

## 4. De CI-omgeving van Payment — en de contractverificatie

Payment heeft binnen dit hoofdstuk geen buren, dus zijn CI-omgeving is hijzelf.

```sh
docker compose -p ci-payment -f deelsystemen/payment/docker-compose.yml up -d
```

Daarna de toetsing aan de gepubliceerde spec. Twee stijlen; een pipeline kiest er één.

```sh
# gegenereerd uit de spec, standaard
ci/verify-contract.sh order-payment payment-api 1.0.0 \
  http://payment-api:8081 ci-payment_default

# met de hand geschreven, JUnit met tag contract
ci/verify-contract.sh order-payment payment-api 1.0.0 \
  http://payment-api:8081 ci-payment_default geschreven

# allebei, voor de demo
ci/verify-contract.sh order-payment payment-api 1.0.0 \
  http://payment-api:8081 ci-payment_default beide
```

Wil je zien dat het ook rood wordt: vervang `HttpStatus.CREATED` door `HttpStatus.OK` in
`PaymentController`, bouw opnieuw, en draai het weer. Een controle die nooit rood wordt is
geen controle.

## 5. Test — de echte keten

Beide deelsystemen, echte buren, geen stub. Een omgeving is een samenstelling van
deelsysteem-bestanden; elk deelsysteem staat maar één keer beschreven.

```sh
docker compose -p test \
  -f deelsystemen/payment/docker-compose.yml \
  -f deelsystemen/order/docker-compose.yml up -d

curl -X POST http://localhost:8082/orders \
  -H 'Content-Type: application/json' -d '{"amount":49.95,"currency":"EUR"}'
```

Zelfde aanroep als in stap 3, ander antwoord op één punt: `paymentId` komt nu van het
echte Payment (`pay-000001`) in plaats van uit de stub (`pay-88f21c`).

Elk deelsysteem meldt op zijn info-endpoint wat het draait:

```sh
curl http://localhost:8081/actuator/info   # provider: de versie die hij serveert
curl http://localhost:8082/actuator/info   # consumer: zijn pin
```

## Opruimen

```sh
docker compose -p test -f deelsystemen/payment/docker-compose.yml \
                       -f deelsystemen/order/docker-compose.yml down
docker compose -p ci-payment -f deelsystemen/payment/docker-compose.yml down
rm -rf build
```

Het register laat je staan; die is gedeeld. Wil je hem leeg: herstarten volstaat, want de
opslag is in memory.

---

## Wat je moet zien

| Scène | Waarom het ertoe doet |
|---|---|
| Order draait groen zonder dat Payment bestaat | de consumer is onafhankelijk van zijn buur |
| De stub komt uit het register, niet uit de test | de norm ligt buiten de test |
| `600.00` levert `CANCELLED`, geen fout | een afgewezen betaling is geen contractschending |
| `amount: 0` levert 400 `INVALID_AMOUNT` | dát is er wel een |
| Contractverificatie wordt rood bij 200 in plaats van 201 | de gate doet echt iets |
