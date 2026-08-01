# Besluiten — de afwegingen erachter

Wat er is besloten, waarom, en wat het kost. Per besluit een datum, want een afweging is
houdbaar zolang de omstandigheden gelijk blijven en niet langer.

Het besluit zelf staat kort in `showcase-cbt.md`. Dit bestand bevat het bewijs: wat er is
geprobeerd, wat eruit kwam, en wat er is opgegeven. Zonder dat leest een keuze als een
voorkeur, en dan gaat iemand hem over een half jaar opnieuw voeren.

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
