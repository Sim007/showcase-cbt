# De handgeschreven stub van Payment

De stub zoals hij vóór contracttesten wordt gemaakt: met de hand, door de consumer, op
basis van wat hij denkt dat de buur doet. Scenario 0 zet deze op de CI-omgeving van Order.

**Handgeschreven is broncode.** Dit bestand hoort daarom in git — anders dan de
gegenereerde tegenhanger in `build/stub/`, die per run uit het register komt en nergens
wordt bewaard.

## Wat hij dekt

Het gelukkige pad, en verder niets. Dat is niet slordig maar gewoon hoe je een stub
schrijft als er geen norm is om hem uit af te leiden: je bootst na wat je nodig hebt voor
het geval dat je aan het testen bent.

## Wat hij niet weet

En wat niemand hem kan vertellen, want er is geen gepubliceerd contract:

| | |
|---|---|
| een bedrag boven `500.00` | levert `DECLINED` op, geen `ACCEPTED` |
| een bedrag van `0` of lager | hoort een 400 te geven |
| een onbekende valuta | hoort een 400 te geven |
| het formaat van `paymentId` | hier geraden |

**Hij is niet fout. Hij is onbewijsbaar.** Hij bevestigt wat de schrijver dacht dat Payment
doet, en blijft groen als Payment verandert.

In [scenario 1](../../../01-basis/README.md) komt hier een stub voor in de plaats die uit
de gepubliceerde spec wordt gegenereerd — en die dit alles wél weet, omdat het in het
contract staat.
