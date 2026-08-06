# Melding aan de squad van showcase-website — de stream wordt SSE

> Verstuurd vóórdat de contracten gepubliceerd zijn. Een contractversie is onveranderlijk,
> dus als hier iets wringt is dit het moment. Daarna is het een nieuwe versie.

## Wat er verandert

De live-stream loopt straks over **Server-Sent Events**, niet over een WebSocket. De
besturing — een scenario starten en afbreken — gaat over **REST**.

| | Nu | Straks |
|---|---|---|
| Stream binnen | WebSocket `/ws` | SSE, één endpoint |
| Scenario starten | bericht over dezelfde socket | `POST` met een antwoord |
| Afbreken | bestond niet | `POST` met een antwoord |
| Reset | bericht over de socket | vervalt — al besloten dat reset lokaal is |

## Waarom

**Omdat een commando een antwoord nodig heeft.** Jullie verkenning noemt het zelf: een
tweede start tijdens een lopende run wordt nu *"stil genegeerd, geen foutmelding"*. Over
een socket is dat lastig anders — je stuurt iets en hoort niets. Over REST is het een 409
met een reden, en de knop kan terugkoppelen of het gelukt is. Dat is precies wat sectie D
van de usecases vraagt.

**En zodra de besturing daar weg is, gaat er niets meer omhoog.** Alles wat overblijft gaat
één kant op: showcase-CBT vertelt wat er gebeurt. Een WebSocket is dan een duplexkanaal
waar maar één richting van gebruikt wordt, met een handshake en een eigen
herverbindingsprotocol erbij. SSE is voor dat geval het eenvoudiger gereedschap.

## Wat het jullie oplevert

**Herverbinden zit erin.** De verkenning noemt dat de socket eenmalig wordt aangemaakt en
er bij een korte drop geen reconnect komt zonder page-reload. `EventSource` doet dat zelf,
inclusief het hervatten vanaf het laatste ontvangen bericht.

**En de verbindingsindicator wordt eerlijk.** Open vraag 2 uit de verkenning — meet
"verbonden" de eigen server of showcase-CBT — wordt scherper: `EventSource.readyState` gaat
over de verbinding met showcase-CBT, want die stream komt daar vandaan. Meet je hem, dan
meet je het goede ding.

Daarbovenop krijgen jullie bij het verbinden eerst een **momentopname** van de lopende run,
zodat een late kijker niet blind begint.

## Wat het kost

`useLiveRun.js` wisselt `WebSocket` voor `EventSource`, en de startknop doet een HTTP-
aanroep in plaats van een socketbericht. De berichtsoorten zelf en de manier waarop jullie
ze verwerken veranderen daar niet van — het blijft één plek waar geparseerd wordt.

Wat níet verandert: jullie hoeven nooit tekst te parsen om te weten waar een stap begint of
eindigt. Elke stap krijgt een expliciet begin- en eindbericht, en cli-uitvoer is een eigen
berichtsoort die naar een stapnummer verwijst en verder geen betekenis draagt.

## Eén ding waar we het niet mee eens zijn

Jullie behoeftelijst vraagt om een *signaal dat een deelsysteem-pipeline is gestopt*. Dat
komt er niet, en dat is met opzet.

Een rode stapuitkomst gevolgd door geen stappen meer voor dat deelsysteem is hetzelfde
feit, en dat afleiden is jullie kant van de afspraak — showcase-CBT meldt feiten en leidt
niets af. Zou wij die status sturen, dan verhuist een stukje redenering naar de kant die
volgens `context.md` juist niet redeneert.

Dezelfde regel geldt voor stappen die door een stop nooit gestart zijn: die leveren geen
bericht. "Niet uitgevoerd" volgt uit het uitblijven ervan.

## Reageren

Wringt dit ergens, laat het weten vóór de publicatie. Daarna staat de vorm vast tot een
volgende contractversie — en dat is niet omdat we lastig doen, maar omdat dat de afspraak
is die we met dit contract laten zien.
