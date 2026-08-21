# Vooraankondiging aan showcase-website — `stubbundel-0.12.0`

Dit gaat vooruit op de oplevering, want er verandert iets aan **aantallen** en jullie hebben
toetsen die daarop kunnen leunen. Lees dit voordat de bundel er is.

## De opnames worden vier keer zo lang

De stamdata van scenario 01 had zes stappen; zijn rapport telt er 27. Zes stappen kunnen de
acht die het verschil met scenario 00 maken niet dragen, dus wat jullie zagen was een
dashboard dat werkt en geen testproces dat iets vangt. Dat is opgelost door de stamdata op de
granulariteit van het rapport te brengen — en de opnames volgen daaruit.

| Opname | 0.11.1 | 0.12.0 |
|---|---|---|
| `voltooid` | 21 berichten | **84** |
| `gestopt` | 12 berichten | **30** |
| `midden` | 14 berichten | **77** |

**Wat dat voor jullie betekent, concreet:**

- Een volledige run duurt nu **ruim een halve minuut** in plaats van acht seconden — de stub
  speelt op 400 ms per bericht. Een toets met een korte tijdslimiet valt daarop om.
- Toetsen die op een **aantal** rusten ("verwacht 21 berichten") worden onwaar. Lees liever
  tot `run-afgerond`, met een tijdslimiet als vangnet en niet als meetlat; dat is wat wij aan
  onze kant ook hebben moeten veranderen.
- `GET /v1/scenarios/01` levert nu **27 stappen** in plaats van 6, en `00` levert er **19**.

## Twee dingen die beter worden

**Elke `scenarioId` krijgt zijn eigen inhoud.** Tot nu gaf elk id scenario 01 terug: er was
één example in de spec en dus één body. Nu komt de inhoud uit stamdata per scenario, en een
id dat niet bestaat geeft **404 `SCENARIO_ONBEKEND`** in plaats van 200 met het verkeerde
scenario.

**De gestopte run vertelt weer iets.** Hij stopt op stap 9, `contractverificatie, provider`:
acht stappen zijn zichtbaar geslaagd, de contractgate houdt het tegen, en **stap 10 tot en
met 27 krijgt geen enkel bericht** — de rest van Payment, heel Order, en de keten. Dat is het
geval waar jullie afleidregel op moet passen, en het is nu veel scherper dan met zes stappen.

## Eén ding dat nog niet werkt — zet de tegel van 00 nog niet op "werkt"

**Scenario 00 openen werkt, scenario 00 starten niet.** `GET /v1/scenarios/00` geeft zijn
eigen 19 stappen met zijn eigen titel. Maar `POST /v1/runs` met `{"scenarioId":"00"}` speelt
de opname van **01**, en antwoordt zelfs met `"scenarioId":"01"`.

De reden: de stamdata is per id gesplitst, de opnames zijn dat nog niet — er is één set en
die is van scenario 01.

Wij hebben dat bewust **niet half gerepareerd**. De 201 het gevraagde id laten teruggeven zou
het geloofwaardiger maken en niet beter: dan claimt het antwoord 00 terwijl de stream 27
stappen van 01 stuurt. Zichtbaar kapot is hier veiliger dan bijna goed.

Het staat als O17 in onze openstaande punten. Zolang dat niet af is: **de tegel van 00 hoort
niet op "werkt"** — half werkend is voor een tegel erger dan niet werkend.

## Waarom dit een vooraankondiging is

Omdat aantallen veranderen en jullie toetsen daarop kunnen staan. Wij hebben deze maand drie
keer een belofte geleverd waar geen gate onder stond; dit is de tegenovergestelde beweging —
het getal komt vóór de levering, zodat het bij jullie kan omvallen op een moment dat het niets
kost.

Reageren kan tot de oplevering. Daarna is het een bundelversie erbij.
