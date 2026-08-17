# Melding aan showcase-website — de bundel heeft de specs ingehaald

Vervolg op `melding-showcase-website-0.11.0.md`. Daar stond vooraan dat de specs iets
beloofden wat het gereedschap nog niet deed. Dat is nu weg: **`stubbundel-0.11.0` doet het
gedrag van `run-stream 0.11.0`.**

```
https://github.com/Sim007/showcase-cbt/releases/download/stubbundel-0.11.0/stubbundel-0.11.0.tgz
https://github.com/Sim007/showcase-cbt/releases/download/stubbundel-0.11.0/stubbundel-0.11.0.tgz.sha256
```

De specversies die erin zitten staan in `manifest.json`, met de checksum van elk. Haal je de
specs los uit hun eigen release, dan is dat te vergelijken.

## Wat er verandert ten opzichte van bundel 0.10.0

| | 0.10.0 | 0.11.0 |
|---|---|---|
| verbinding | sluit na `run-afgerond` | blijft open; **jullie sluiten hem** |
| volgende run | nieuwe verbinding openen | `POST /v1/runs` over dezelfde verbinding |
| momentopname bij verbinden | draagt meteen een run | `run: null` als er niets loopt |
| heartbeat | geen | elke 20 s een `: hartslag` bij stilte |
| `runId` in de 201 | altijd `run-7c41a9` | dat van de opname die dan begint |
| tweede start tijdens een run | 201 | **409**, met het `runId` van de lopende run |

De onderste twee stonden niet in de vorige melding. Ze volgen uit dezelfde wijziging: een
stub die zijn verbinding openhoudt weet dat er een run loopt, en dan is `POST /v1/runs` een
tweede keer beantwoorden met 201 niet meer een versimpeling maar een grens die ruimer is dan
de echte. In de spec staat het al: er kan één run tegelijk lopen.

**Let op de 201.** Die draagt nu per start een ander nummer — `run-7c41a9`, dan `run-3b8e02`,
dan `run-9d15f4` — en dat is hetzelfde nummer als op de berichten die erna binnenkomen. Wie
in 0.10.0 op het antwoord van de POST vertrouwde om te weten welke run hij volgt, kreeg altijd
`run-7c41a9`; dat klopte toevallig bij de eerste run en bij geen enkele daarna.

## Wat u kwijtraakt, en dat is echt

**Het late-kijkersgeval is tegen de bundel niet meer te oefenen.** De opname `midden` was
er voor iemand die verbindt terwijl er al een run loopt. Dat geval hoort vanaf 0.11.0 bij
het verbinden en niet bij het starten, en de stub kan het niet nabootsen zonder zelf een
momentopname samen te stellen uit de replaypositie. Dat doet hij niet: dan wijst hij een
toestand aan die nergens is vastgelegd, en oefent u tegen iets wat wij nooit verstuurd hebben.

Speelt u `midden` af met een `POST`, dan ziet u een run die bij stap 3 begint zonder
`run-gestart`. De momentopname erbij klopt — `afgerondeStappen` en `lopendeStap` staan erin,
dus uw plaat is meteen correct — maar het is niet meer het geval waarvoor die opname bestond.

Wij hebben liever een fixture die minder toont dan een stub die iets aanwijst wat niet is
vastgelegd. Loopt uw werk hierop vast, zeg het: dan is het een gesprek over de fixtures en
niet over een instelling.

**Verbinden midden in een run** geeft om dezelfde reden de opgenomen opening van die run en
niet de stand van dat moment. Verbind dus voordat u start — zo is de grens ook bedoeld.

## Twee schakelaars die geen contractgedrag zijn

| | |
|---|---|
| `TOLERANTIE=ja` | de stream stuurt wat een volgende contractversie zou kunnen sturen |
| `HARTSLAG_MS=1000` | de hartslag komt na een seconde stilte in plaats van na twintig |

Allebei zijn ze gereedschap om een belofte uit het contract te kúnnen aantonen, en geen
gedrag dat het contract beschrijft. In de spec staat 20 seconden, en dat is wat de bundel
doet als u niets instelt. Wij gebruiken de tweede in onze eigen gate, omdat een run acht
seconden duurt en een hartslag die na twintig komt anders door geen enkele toets gezien wordt
— dan was "er is een heartbeat" een bewering gebleven.

## Wat er onder deze regels staat

`ci/toets-stubbundel.sh` pakt de bundel uit, draait hem, en toetst elk van deze punten bij
elke push: de momentopname met `run: null`, de 201 met het runId van de opname, de 409 bij
een tweede start, lezen tot `run-afgerond`, het aantal berichten tegen de opname zelf, de
hartslag op een stille verbinding, en dat de verbinding daarna nog openstaat.

Dat schrijven we erbij omdat de vorige versie van deze zin er niet stond. De README beloofde
gedrag dat één keer met de hand was nagekeken, en dat leest hetzelfde als gedrag dat elke dag
wordt gecontroleerd.

## Reageren

Wringt er iets, dan is dit het moment — aan de bundel kunnen we draaien, aan een gepubliceerde
spec niet meer zonder versie.
