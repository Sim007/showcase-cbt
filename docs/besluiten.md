# Besluiten — de afwegingen erachter

Wat er is besloten, waarom, en wat het kost. Per besluit een datum, want een afweging is
houdbaar zolang de omstandigheden gelijk blijven en niet langer.

Het besluit zelf staat kort in `showcase-cbt.md`. Dit bestand bevat het bewijs: wat er is
geprobeerd, wat eruit kwam, en wat er is opgegeven. Zonder dat leest een keuze als een
voorkeur, en dan gaat iemand hem over een half jaar opnieuw voeren.

---

## 2026-08-02 — Contractverificatie: gegenereerd of geschreven

**De vraag.** De providerkant moet volledig worden getoetst aan de spec: elke operatie,
elke responsecode, happy en unhappy. Dat kan met testgevallen die uit de spec worden
gegenereerd, of met tests die je zelf schrijft. `CLAUDE.md` legt de testlagen vast als
JUnit-tags, en een generator levert die niet — dus de vraag was of dat zwaar genoeg weegt.

**De aanpak: allebei bouwen.** Schemathesis 4.24.3 tegen de gedeployde container, en een
JUnit-test met `swagger-request-validator` 3.0.0 tegen dezelfde container.

### Wat de gegenereerde variant vond

Zes gebreken, in een implementatie die 15 groene tests had:

| Verzoek | Was | Hoort |
|---|---|---|
| `PUT`, `DELETE`, `PATCH`, `QUERY` | 500 | 405 |
| 405 zonder `Allow`-header | — | RFC 9110 eist hem |
| `amount: 1.4e308` | 500 — `NUMERIC(38,2)` liep over | 400 |
| `orderId: null` | 201, en `null` kwam terug in de response | 400 |
| `orderId: false` | 201 — Jackson maakte er `"false"` van | 400 |
| `currency: null` | 500 — `Set.of(…).contains(null)` gooit NPE | 400 |

De vierde is de leerzaamste: een `null` die je binnenlaat komt er aan de andere kant weer
uit, en dan schendt de **response** het schema dat de provider zelf publiceert.

De handgeschreven integratietests die er op dat moment stonden, vonden er nul van. Dat is
geen verwijt aan die tests — het is de aard van het verschil. **Wat je zelf opschrijft, dekt
wat je zelf bedenkt.** Niemand verzint een verzoek met `orderId: false`.

### Wat de geschreven variant biedt

Leesbaarheid en een plek in de bestaande toolchain: zes tests met begrijpelijke namen,
`@Tag("contract")`, zichtbaar in de Maven-uitvoer naast unit en integratie. En hij toetst
niet zijn eigen verwachting: `swagger-request-validator` houdt elke response tegen de spec
uit het register, dus de norm ligt ook hier buiten de test.

### Het besluit: allebei, en de pipeline kiest

`ci/verify-contract.sh <groep> <artifact> <versie> <basis-url> <netwerk> [stijl]` met
`gegenereerd` (standaard), `geschreven` of `beide`. Een pipeline kiest er één; `beide` is
voor de demo.

Dit is een showcase, en het verschil tussen die twee stijlen is precies wat een lezer wil
zien. Eén ervan verwijderen zou het argument tot een bewering maken.

De botsing met `CLAUDE.md` lost zichzelf daarmee op: de geschreven variant draagt de tag,
de gegenereerde levert een JUnit XML-rapport, en het woord `contract` staat in de
scriptnaam en in de pipeline-uitvoer.

### Beide zijn getoetst op rood worden

`201` vervangen door `200` in de implementatie. Gegenereerd:
*Undocumented HTTP status code — Received: 200, Documented: 201, 400*. Geschreven: twee
gefaalde asserts. Een controle die nooit rood wordt is geen controle, en dat moet je een
keer aantonen in plaats van aannemen.

### Wanneer herzien

Als het onderhoud van twee stijlen gaat knellen. Voor een productiesituatie zou ik de
gegenereerde variant als gate nemen en de geschreven als documentatie van de
belangrijkste paden — of de geschreven laten vallen.

### Een valkuil die de eerste meting waardeloos maakte

De eerste run leverde zes bevindingen op die allemaal onzin waren. Alle compose-bestanden
stonden op één vast netwerk, en de stub neemt daar de servicenaam van de buur over —
bedoeld op de CI-omgeving, maar met het echte deelsysteem erbij verwees `payment-api` naar
twee containers en was het toeval wie antwoordde.

Sindsdien maakt compose een netwerk per project, en **dat project is de omgeving**. Wie
deze opzet nabouwt, loopt tegen dezelfde val aan.

---

## 2026-08-01 — De stub: zelf genereren of een kant-en-klare mockserver (O7)

**De vraag.** Hoofdstuk 1.6 beschrijft een eigen generator die van de OpenAPI-spec
WireMock-mappings maakt. Dat is werk. De vraag was of een bestaande mockserver hetzelfde
doet, en het openstaande punt O7 hield die vraag vast.

**De aanpak: bouwen in plaats van vergelijken.** Geen afweging op documentatie, maar beide
kandidaten opgestart tegen de echte spec uit het register, met het scenario uit 1.2 als
beslissende proef.

### Prism — `stoplight/prism`

De nieuwste tag, 5.15.10, start niet:

```
TypeError: Cannot read properties of undefined (reading 'isPrimary')
    at createMultiProcessPrism
```

Met 5.14.2 draait hij wel. Vier proeven tegen de gepubliceerde v1.0.0:

| Proef | Uitkomst |
|---|---|
| `GET /v1/payments/pay-88f21c` | 200 — **padtemplates werken native** |
| `POST` met bedrag 49,95 | 201, `ACCEPTED`, exact de `example` uit de spec |
| `POST` met bedrag 600,00 | 201, **`ACCEPTED`** — verwacht was `DECLINED` |
| `POST` met een niet-gedeclareerd veld `tip` | 400 — **valideert requests tegen de spec** |

### WireMock — `wiremock/wiremock:3.13.2`

Twee handgeschreven mappings, een matcher op de body met een prioriteit erboven:

```json
"bodyPatterns": [ { "matchesJsonPath": "$[?(@.amount > 500.00)]" } ]
```

| Proef | Uitkomst |
|---|---|
| `POST` met bedrag 49,95 | 201, `ACCEPTED` |
| `POST` met bedrag 600,00 | 201, **`DECLINED`** |

### Het besluit

**WireMock, met een eigen generator.** Eén reden, en het is geen kwaliteitsoordeel: de
showcase heeft een response nodig die afhangt van de inhoud van het verzoek. Prism kiest
per statuscode altijd hetzelfde voorbeeld en kan die keuze principieel niet maken. Daarmee
zou de consumertest van Order de afgewezen betaling nooit kunnen doorlopen, en dat is
precies de tak die hoofdstuk 1 wil aantonen.

### Wat het kost

Twee dingen die Prism gratis doet, staan nu als eigen werk in 1.6: **padtemplates
matchen** — waarvan het document zelf zegt dat generatoren daarop stukgaan — en het
**opbouwen van bodies uit de `example`-waarden**.

### Wat we opgeven

Prism valideert binnenkomende requests tegen de spec, inclusief
`additionalProperties: false`. Dat is precies de eerste helft van de consumerverificatie:
*wat Order verstuurt voldoet aan de spec*. Met WireMock komt die validatie niet vanzelf —
hij moet uit het request journal of uit een validatie-extensie komen. Dat is bekend werk,
geen verrassing, maar het hoort in de begroting van dit besluit.

### Wanneer herzien

Zodra Prism een response op requestinhoud kan kiezen, of zodra het scenario uit 1.2
verdwijnt. Wie deze opzet overneemt zonder zo'n scenario, kan stap 2 tot en met 5 van 1.6
vervangen door één regel: start Prism met de spec.

### Terzijde

Twee keer nu is de nieuwste tag van een tool niet bruikbaar gebleken:
`APICURIO_STORAGE_KIND=mem` bestaat niet meer in Apicurio 3.3.1, en `prism:5.15.10` crasht
bij het starten. Vastgepinde versies zijn in deze showcase geen formaliteit.
