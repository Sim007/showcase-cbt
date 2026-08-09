# Melding aan de squad van showcase-website — de stream wordt SSE

> Dit gaat naar jullie toe voordat er iets van jullie kant wordt verwacht, en niet als
> mededeling achteraf bij een publicatie. Showcase-CBT bepaalt het contract, maar dat is
> geen reden om jullie het als voldongen feit te laten vinden.
>
> `run-stream` en `scenario-api` liggen er als voorstel, met het nummer 1.0.0 erop, en er is
> een stub die beide serveert. **Vastgezet is er nog niets** — ze staan alleen in het
> register op onze eigen machine, en dat is er morgen weer leeg.
>
> Dat is met opzet: zodra jullie erop bouwen wordt 1.0.0 onveranderlijk, en dan is elke
> wijziging een nieuwe versie met alles wat daarbij hoort. Wringt er iets, dan is dit dus het
> moment — daarna wordt het duur.

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

**Herverbinden zit erin — dat is de vierde onvolkomenheid uit jullie eigen verkenning.**
Daar staat dat de socket eenmalig wordt aangemaakt, met een lege dependency-array, en dat
er bij een korte drop geen reconnect komt zonder page-reload. Met `EventSource` hoeft daar
geen code voor: de browser herstelt de verbinding zelf, met een oplopende wachttijd, en
stuurt `Last-Event-ID` mee zodat hervatten kan. Dat punt kunnen jullie afstrepen zonder er
iets voor te bouwen.

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

## De uitkomst heet geen kleur

`uitkomst` is `geslaagd` of `mislukt`, niet `groen` of `rood`. Kleur is presentatie, en
presentatie leiden jullie af — dus die bepalen jullie zelf. Zouden wij "groen" sturen, dan
beslisten wij mee over jullie beeld, en dat is precies de verdeling die `context.md`
tegenhoudt.

## De stub serveert ook een mislukte run

De verkenning wijst erop dat de simulator nooit een mislukt pad heeft gelopen: alles stond
op geslaagd omdat het bronbestand dat zei. Juist wat jullie moeten afleiden hangt daaraan.
De stub geeft daarom drie situaties, om en om bij elke nieuwe verbinding:

| | Wat je krijgt |
|---|---|
| 1 | een run die voltooit |
| 2 | een run die stopt op een mislukte stap — **de stappen erna krijgen geen enkel bericht** |
| 3 | een momentopname midden in een lopende run |

Situatie 2 is degene waar jullie afleidlogica op moet passen: `reden: gestopt`, en "niet
uitgevoerd" volgt uit het uitblijven van berichten.

Situatie 3 heeft een gevolg dat bedoeld is en geen bug: **een late kijker heeft een leeg
CLI-paneel.** De uitvoer van stappen die al af zijn komt niet opnieuw — die draagt geen
betekenis en zou de kijker eerst een inhaalslag laten afwachten. Wat hij wél krijgt is welke
stappen geslaagd zijn en welke loopt, en vanaf dat moment loopt de uitvoer mee.

## Eén ding waar we het niet mee eens zijn

Jullie behoeftelijst vraagt om een *signaal dat een deelsysteem-pipeline is gestopt*. Dat
komt er niet, en dat is met opzet: showcase-CBT meldt feiten en leidt niets af. Zouden wij
die status sturen, dan verhuist een stukje redenering naar de kant die volgens `context.md`
juist niet redeneert.

**Maar de regel die wij erbij gaven, klopte niet.** Er stond dat een mislukte stapuitkomst
gevolgd door stilte hetzelfde feit is. Jullie hebben aangetoond dat dat te weinig is, en de
regel die jullie ervoor in de plaats zetten is de juiste — we nemen hem over:

> Zodra `run-afgerond` binnenkomt met reden `gestopt` of `afgebroken`, geldt voor **elk**
> deelsysteem met stappen die geen afronding hebben gekregen — inclusief een deelsysteem dat
> nooit begonnen is — dat er niets meer komt.

De reden dat onze regel te kort schoot: stappen staan in **één doorlopende lijst over het
hele scenario**, niet als parallelle pipelines per deelsysteem. Mislukt stap 3 bij Payment,
dan krijgt Order voor stap 4 nooit een bericht — zonder dat Order iets fout deed. Onze regel
liet Order dan als "nog niet gestart" staan, en dat is na `run-afgerond` misleidend.

Dat het geval bestond en niemand het zag, kwam doordat ons eigen scenario-example geen
enkele Order-stap had terwijl het Order wel als deelsysteem noemde. Dat is gerepareerd; de
opgenomen runs bevatten nu een deelsysteem dat nooit aan de beurt kwam, zodat jullie er
tegen kunnen testen.

Wat wél blijft: een stap die door een stop nooit gestart is, levert geen bericht. "Niet
uitgevoerd" volgt uit het uitblijven ervan.

## Reageren

Wringt dit ergens, laat het weten vóór de publicatie. Daarna staat de vorm vast tot een
volgende contractversie — en dat is niet omdat we lastig doen, maar omdat dat de afspraak
is die we met dit contract laten zien.
