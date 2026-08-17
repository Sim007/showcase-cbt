# Melding aan showcase-website — 0.11.0 staat, de bundel nog niet

> **Achterhaald op 2026-08-17 door `melding-showcase-website-stubbundel-0.11.0.md`.** De
> bundel doet inmiddels wel wat hieronder als "nog niet" staat. Dit bericht blijft staan
> zoals het verstuurd is — een melding die de deur uit is, wordt niet achteraf bijgewerkt,
> want dan klopt niet meer wat de ontvanger heeft gelezen.

> **Lees dit eerst:** de specs zijn er, het gereedschap nog niet. Wat hieronder beschreven
> staat, doet de stubbundel op dit moment **niet**. Dat is met opzet zo opgeleverd en het
> staat hier voorop, want specs die iets beloven wat het beschikbare gereedschap nog niet doet
> is precies de asymmetrie waar jullie eerder op stuitten.

## Wat er nu op te halen is

```
https://github.com/Sim007/showcase-cbt/releases/download/scenario-api-0.11.0/scenario-api-0.11.0.yaml
https://github.com/Sim007/showcase-cbt/releases/download/scenario-api-0.11.0/scenario-api-0.11.0.yaml.sha256

https://github.com/Sim007/showcase-cbt/releases/download/run-stream-0.11.0/run-stream-0.11.0.yaml
https://github.com/Sim007/showcase-cbt/releases/download/run-stream-0.11.0/run-stream-0.11.0.yaml.sha256
```

Wij hebben ze zelf langs deze weg opgehaald en geverifieerd, beide in dezelfde map, en
`shasum -a 256 -c` geeft tweemaal `OK`.

## Wat er in de specs verandert

**`run-stream 0.11.0` — de stream blijft open tussen runs door.** Eén verbinding per sessie,
niet per run. Een tweede scenario starten gaat over dezelfde verbinding, en **jullie sluiten
hem, niet wij**.

Bij het openen komt eerst een momentopname. Loopt er niets, dan draagt die `run: null` — en
dat is vanaf nu de normale begintoestand en geen randgeval.

**Er is een heartbeat.** Blijft het stil, dan sturen wij elke 20 seconden een
SSE-commentaarregel (`: hartslag`). Zonder dat ruimen proxies en browsers een stille
verbinding op.

**Voor jullie client verandert daar niets aan.** Een commentaarregel wordt door `EventSource`
nooit aan de applicatie afgeleverd: er komt geen `onmessage` voor. Jullie hoeven er niets
voor te bouwen en kunnen er niet over struikelen. Wie het wél moet weten is iedereen die de
ruwe stream leest — een eigen parser, een `curl -N` in een test: die ziet regels die met `:`
beginnen en moet ze overslaan.

**`scenario-api 0.11.0` — afwezigheid als betekenis staat nu bij `Stap` zelf.** Ontbreekt
`omgeving`, dan draait de stap op de code; ontbreekt `deelsysteem`, dan spant hij over de
keten. Er is geen waarde `code` en geen waarde `keten`. Dat stond al in de beschrijving van
de losse velden, maar niet op de plek waar je het leest voordat je de velden induikt — en het
is twee keer misgelezen, waarvan één keer door jullie. Geen gedragswijziging, alleen
duidelijker opgeschreven.

## Wat de bundel nu wél en niet doet

De bundel staat nog op **`stubbundel-0.10.0`** en handelt naar het oude gedrag.

| | Bundel 0.10.0 | Spec 0.11.0 |
|---|---|---|
| verbinding | sluit na `run-afgerond` | blijft open |
| volgende run | nieuwe verbinding openen | `POST /v1/runs` over dezelfde verbinding |
| momentopname bij verbinden | draagt meteen een run | `run: null` als er niets loopt |
| heartbeat | geen | elke 20 s een `:`-regel |

**Wat je er nu wél tegen kunt oefenen:** alle berichtsoorten, hun schema's, de drie verlopen
inclusief de gestopte run, de tolerantie-eisen, en de afleidregel voor een deelsysteem dat
nooit aan de beurt kwam. Dat is ongewijzigd.

**Wat je er niet tegen kunt oefenen:** de open verbinding, de idle-momentopname en de
heartbeat. Bouw je daar nu al op, doe dat dan tegen de spec en niet tegen de bundel.

**Bundel `0.11.0` volgt als eigen oplevering.** Die krijgt de vier gedragswijzigingen in één
keer, want los opgeleverd geven ze een stub die halverwege stilvalt.

## Eén ding dat wél al klopt: de drie `runId`'s

De drie opnames droegen alle drie `run-7c41a9` — drie verschillende verlopen die beweerden
dezelfde run te zijn. Dat is verkeerd oefenmateriaal, zeker als je op `runId` gaat bijhouden
welke run je volgt, en dat moet je zodra de stream open blijft.

| Opname | `runId` |
|---|---|
| `voltooid` | `run-7c41a9` |
| `gestopt` | `run-3b8e02` |
| `midden` | `run-9d15f4` |

Dat zit al in de fixtures van 0.11.0 en komt mee in bundel 0.11.0. Let op: `voltooid` houdt
het oude nummer, en dat is hetzelfde nummer dat overal in de specs als voorbeeld staat.
Verwarring daarover komt daarvandaan.

## Reageren

Wringt er iets in de nieuwe specs, dan is dit het moment. Daarna kost het een versie.
