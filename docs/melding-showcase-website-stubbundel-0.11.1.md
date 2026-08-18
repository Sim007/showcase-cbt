# Melding aan showcase-website — punt 5 is gerepareerd in `stubbundel-0.11.1`

Jullie punt 5: verbinden terwijl er een run loopt gaf een momentopname met `run: null`, en
daarna stapberichten die nergens meer aan te hangen waren. Dat is opgelost.

```
https://github.com/Sim007/showcase-cbt/releases/download/stubbundel-0.11.1/stubbundel-0.11.1.tgz
https://github.com/Sim007/showcase-cbt/releases/download/stubbundel-0.11.1/stubbundel-0.11.1.tgz.sha256
```

De specs zijn onveranderd: `scenario-api 0.11.0` en `run-stream 0.11.0`. Er is niets aan het
contract gewijzigd, dus dit is een patch van de bundel en van niets anders.

## Wat er nu gebeurt

Verbind je terwijl er een run loopt, dan draagt de momentopname **die run**: `runId`,
`scenarioId`, `gestartOp`, de stappen die tot dat moment zijn afgerond, en `lopendeStap` als
er een stap bezig is. Gemeten voorbeeld, aangesloten tijdens `voltooid`:

```json
{"soort":"momentopname","tijd":"2026-08-06T09:12:54Z",
 "run":{"runId":"run-7c41a9","scenarioId":"01","gestartOp":"2026-08-06T09:12:45Z"},
 "afgerondeStappen":[{"stapNummer":1,"uitkomst":"geslaagd"},
                     {"stapNummer":2,"uitkomst":"geslaagd"},
                     {"stapNummer":3,"uitkomst":"geslaagd"}]}
```

Loopt er niets, dan blijft het `run: null` met een lege `afgerondeStappen`. Dat is en blijft
de normale begintoestand van een sessie.

## Wat wij fout hadden, en waarom dat voor jullie uitmaakt

Wij hadden dit in de vorige melding als **beperking** opgeschreven: "wie midden in een run
aansluit, krijgt de opgenomen opening van die run", met "verbind dus voordat u start" als
advies. Dat was verkeerd gekwalificeerd. In `MomentopnamePayload` staat bij `run`: *"Null
wanneer er geen run loopt."* De stub stuurde `run: null` terwijl er een run liep, en sprak
daarmee de spec tegen die hij hoort voor te doen.

Dat is geen beperking maar non-conformiteit. Het verschil is niet academisch: een beperking
mag je als consumer omheen werken, een non-conformiteit hoort u niet te hoeven kennen.

**Wat er onder zit, zodat dit niet terugkomt:** `ci/toets-stubbundel.sh` verbindt nu tijdens
een lopende run en eist dat de momentopname die run draagt met de stappen die tot dan zijn
afgerond. Dat draait bij elke push. Waar eerst een zin in een README stond, staat nu een gate.

## Wat u hiermee terugkrijgt

**Het late-kijkersgeval is weer te oefenen**, en beter dan eerst. In de vorige melding stond
dat u dat kwijt was omdat de opname `midden` na een `POST` afspeelt als een run die bij stap 3
begint. Dat klopt nog steeds voor die opname — maar u kunt het geval nu zelf maken: start een
run en verbind er tijdens de run een tweede keer bij. Dan kiest u zelf het moment van
aansluiten, in plaats van het vastgelegde instappunt van een fixture.

Als u daar iets voor had ingebouwd om de vorige beperking te omzeilen, kan dat eruit.

## Hoe de stand tot stand komt

De stub verzint niets. Hij begint bij de opgenomen openingsmomentopname van de opname en werkt
die bij met elk bericht dat hij verstuurt: `run-gestart` zet de run, `stap-afgerond` vult
`afgerondeStappen`, `stap-gestart` zet `lopendeStap`. Wat u krijgt is dus een uitspraak over
berichten die u ook gekregen zou hebben als u eerder had verbonden.

Eén detail dat u kan opvallen: `Run` eist `gestartOp` en `run-gestart` draagt dat veld niet.
De stub gebruikt de `tijd` van dat bericht. In de fixtures scheelt dat een seconde met de
waarde in de opgenomen momentopname van `midden`.

## Reageren

Zit er nog iets tussen wat wij als beperking hebben opgeschreven en wat u als fout ervaart —
zeg het. Dat onderscheid hebben wij deze week aantoonbaar niet goed gemaakt.
