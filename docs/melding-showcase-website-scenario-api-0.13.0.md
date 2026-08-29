# Melding aan showcase-website — `scenario-api 0.13.0`: `GET /v1/info`

Nieuw endpoint, geen wijziging aan wat er al was. Additief gepubliceerd, door de diff-gate:
geen breaking wijziging.

```
https://github.com/Sim007/showcase-cbt/releases/download/scenario-api-0.13.0/scenario-api-0.13.0.yaml
https://github.com/Sim007/showcase-cbt/releases/download/scenario-api-0.13.0/scenario-api-0.13.0.yaml.sha256
```

## Waarom dit er is

Op 27 augustus stond er vijf dagen een stub op de poort waar normaal de echte provider
luistert. Niemand — wij niet, jullie niet — kon dat aan een antwoord zien. Wat het uiteindelijk
verried was de klok in de berichten, niet de API zelf. Dat is precies het gat dat dit endpoint
dicht.

## Wat het teruggeeft

```json
GET /v1/info

{
  "naam": "provider van showcase-CBT",
  "versie": "0.3.0",
  "bron": "pipeline",
  "serveert": [
    { "artifact": "scenario-api", "versie": "0.13.0" },
    { "artifact": "run-stream", "versie": "0.11.0" }
  ]
}
```

**`bron` is het veld waar het om gaat**, en het is de enige plek in dit contract die bewust een
implementatie beschrijft in plaats van een grens:

| Waarde | Betekent |
|---|---|
| `pipeline` | de berichten ontstaan terwijl er werkelijk iets draait |
| `opname` | er wordt vastgelegd materiaal afgespeeld |

De stubbundel meldt `opname`, de echte provider `pipeline`. Getest naast elkaar op wat we nu
hebben uitgegeven:

```json
provider 0.3.0:  {"naam":"provider van showcase-CBT","versie":"0.3.0","bron":"pipeline", ...}
bundel 0.16.0:   {"naam":"stubbundel van showcase-CBT","versie":"0.16.0","bron":"opname", ...}
```

## Waarom dit in het contract staat en niet in een conventie ernaast

Eerder redeneerden we dat identificatie ernaast hoorde — een bedieningsafspraak, geen
interfacevraag. Dat argument ging voorbij aan wie de lezer is: hier is dat jullie, aan de enige
grens in deze showcase waar het eigenaarschap echt wisselt. Een afhankelijkheid tussen squads
die nergens gedeclareerd staat, is precies de fout die deze maand herhaaldelijk is teruggekomen.
Vandaar het contract, met `bron` als enum en niet als vrije tekst — juist omdat het bedoeld is
om getoond en op gereageerd te worden.

## Wat er niet in staat, met opzet

Geen lijst van wat een implementatie wél en niet ondersteunt. `POST /v1/runs/{runId}/afbreken`
ontbreekt in de provider vandaag (zie O22), en toch meldt hij `bron: pipeline` — een operatie
die ontbreekt verandert de herkomst niet. Zou dit endpoint capaciteiten gaan opsommen, dan
ontstaat er een tweede contract naast het eerste.

## Wat jullie moeten doen

Niets, tenzij jullie willen. Additief betekent: jullie pin blijft op `0.12.0` werken zolang
jullie niet migreren. Willen jullie `bron` gebruiken om te tonen met wie de pagina praat — dat
is precies waarvoor het gebouwd is — dan pinnen naar `0.13.0`.

## Reageren

Wringt er iets, dan is dit het moment.
