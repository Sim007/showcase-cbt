# Showcase CBT

Een showcase die contract-based testing aantoonbaar maakt. Het contexthoofdstuk beschrijft wat overal gelijk is; elk scenario daarna is los te lezen.

**Dit document beschrijft wat er is en waarom** — de opzet zoals hij nu staat, zonder versiegeschiedenis: git houdt bij wat er is veranderd. Twee andere bestanden in deze map dragen wat hier niet in past. `besluiten.md` bevat de afwegingen achter de keuzes: wat er is geprobeerd, wat eruit kwam, wat het kost en wanneer het herzien moet worden. `security.md` doet hetzelfde voor beveiligingsbevindingen. Beide zijn gedateerd, want een afweging is houdbaar zolang de omstandigheden gelijk blijven en niet langer. Wie zich bij een keuze hieronder afvraagt *waarom dan*, vindt het antwoord daar.

---

## Context

### Contract-based testing in deze showcase

Een **grens** is elke interface waar eigenaarschap wisselt tussen deelsystemen — een organisatorisch criterium, geen technisch. Contract-based testing toetst beide kanten van zo'n grens aan één gepubliceerde specificatie, in de bouwstraat, zonder dat de deelsystemen samen hoeven te draaien.

Het contracttesten is hier **provider-driven en schema-first**: de provider bezit en publiceert het contract, en zowel provider als consumer verifiëren hun eigen conformiteit daaraan. Er is gekozen voor open source en dus geen commercieel platform om contracten uit te wisselen of te vergelijken.

Dat is een andere invulling dan **consumer-driven contracts** met Pact, en die vergelijking is de eerste die een lezer maakt. Twee verschillen zijn hier bepalend.

Bij consumer-driven contracts legt elke consumer zijn verwachting vast als apart artefact naast de specificatie. Dat werkt, en het werkt vooral goed wanneer de consumers bekend zijn en binnen dezelfde organisatie zitten. De prijs is dat er twee bronnen ontstaan die uit elkaar kunnen lopen, met de vraag welke van de twee wint bij afwijking. Deze showcase kiest voor één bron: de gepubliceerde specificatie. Dat is geen oordeel over de geschiktheid van consumer-driven contracts, maar een andere afweging over waar de waarheid ligt.

Het **bidirectionele** model — waarin een providerspecificatie en consumerverwachtingen automatisch tegen elkaar worden gehouden — lost dat probleem grotendeels op, maar zit in een commercieel platform. Pact zelf is open source; die functionaliteit is dat niet. Voor een showcase die iedereen zonder licentie moet kunnen draaien, valt hij daarmee af.

Wat overblijft is een opzet van losse open-source-onderdelen: een registry voor de contracten, een diff-tool voor compatibiliteit, en validators aan beide kanten van de grens.

Wat de showcase aantoont is één ding: **hetzelfde mechanisme werkt over vier contractvormen** — REST, async, SOAP en een frontend-grens — en over de volledige levenscyclus van een contract, van eerste publicatie tot het uitfaseren van een oude versie.

### Waarom contracttesten

**Een breuk kost het meest als hij laat blijkt.** Zonder contract komt een breaking change aan het licht op de omgeving waar twee deelsystemen elkaar voor het eerst tegenkomen, of bij een consumer die de wijziging niet zag aankomen. Op dat moment ligt er code, staat er een release klaar en is terugdraaien duur. Een gepubliceerd contract met een gate ervoor verschuift dat moment naar de wijziging zelf: nog voordat er een regel code is geschreven, staat vast of dit breekt en wat het kost. Dat is de winst — niet dat er minder breuken zijn, maar dat ze eerder en goedkoper blijken.

**En het maakt ketentesten kleiner.** Een e2e-suite groeit doordat hij de enige plek is waar blijkt of twee deelsystemen op elkaar passen. Wordt dat elders en goedkoper aangetoond, dan mag hij terug naar waar hij voor bedoeld is: doet de keten wat een gebruiker verwacht. Minder scenario's, sneller, en ze falen om een reden die te lezen is.

**Waar het naartoe werkt: releasen op testbewijs.** Een squad hoeft niet te vragen of het mag en hoeft met niemand een deployvolgorde af te spreken. Hij heeft bewijs dat zijn kant van elke grens klopt, vastgesteld op een artefact en niet op een gevoel. Dat is wat zelfstandig releasen mogelijk maakt, en alles wat hieronder staat is daar een middel voor.

**En wat daarvoor verdwijnt: de release trein.** Niet alle gewijzigde deelsystemen per sprint tegelijk naar productie, maar elk deelsysteem wanneer zijn eigen squad het klaar acht. Een trein is een afspraak die je maakt omdat niemand van zijn eigen kant zeker genoeg is; komt die zekerheid er per deelsysteem, dan is de trein alleen nog vertraging voor wie eerder klaar was — en een gedeeld risico voor wie dat niet is.

### De startsituatie

**Deze showcase begint niet bij nul.** Hij veronderstelt een werkende uitgangssituatie: deelsystemen die gebouwd en gedeployd worden, pipelines die draaien, omgevingen die er staan, en een testpiramide die zijn werk doet. Contract-based testing komt daar bovenop en vervangt niets. Zonder die aanname leest de rest als een opdracht om alles opnieuw in te richten, en dat is niet wat er staat.

Die uitgangssituatie hoort bij het fictieve systeem: hij is een gegeven van de showcase en geen weergave van hoe het ergens werkt. Wie er iets in herkent kan de vergelijking maken waar deze showcase voor bedoeld is; wie het anders heeft ingericht, verschuift de startlijn en leest verder.

**Wat verondersteld wordt.**

| | |
|---|---|
| Eigenaarschap | een deelsysteem heeft één eigenaar, die zelfstandig kan releasen |
| Pipelines | per microservice bouwen en testen, per deelsysteem deployen |
| Omgevingen | een efemere CI-omgeving, en Test en Acceptatie die blijven staan |
| Testpiramide | unit, integratie, een e2e smoke op Test, een gebruikersflow op Acceptatie |
| Grenzen | beschreven, vaak in een OpenAPI-bestand, maar niet afgedwongen |

Die piramide staat en is niet het probleem. **Wat er niet is, is het register en de contracttesten.** Het schema ligt er en de implementaties draaien aan beide kanten — maar de spec staat als bestand in een repository en niet als gepubliceerde versie, en geen enkele test toetst eraan. Daardoor bindt hij niets: hij is documentatie, geen norm waar een build op valt.

| | Er wel | Er niet |
|---|---|---|
| De grens | het schema, als bestand naast de code | het register: één plek, immutable, per versie |
| De implementatie | beide kanten, gebouwd en gedeployd | — |
| De toetsing | unit, integratie, e2e | de contracttesten: stub uit de spec, verificatie aan beide kanten, drift |

Die twee zijn precies wat de showcase toevoegt, en verder niets.

**Wat contracttesten toevoegt.**

| Toevoeging | Waar het gaat zitten |
|---|---|
| Een register waarin de spec gepubliceerd staat, immutable en per versie | naast de bestaande artefactopslag |
| Een diff-gate bij publicatie | bij de contractwijziging, niet in een pipeline |
| Een stub die uit de spec wordt gegenereerd | in de CI-omgeving, waar nu een handgeschreven stub staat — en in de integratietest, waar de buur nu met de hand wordt nagebootst |
| Contractverificatie aan beide kanten van de grens | in de integratielaag, met de spec als norm |
| Drift-check en versieconformiteit | naast de piramide, als artefact- en omgevingscontrole |

**Wat contracttesten wegneemt.** Dit is de rij die de rekening laat kloppen, want de vorige kost werk.

| Verdwijnt | Waarom |
|---|---|
| E2e-tests die de structuur van een grens aantonen | die structuur is al bewezen op een goedkopere laag; de gebruikersflow mag terug naar wat een gebruiker doet |
| Afstemming over deployvolgorde, en de release trein die daaruit volgt | de contractversie is het synchronisatiepunt; elk deelsysteem schuift op zijn eigen tempo op |
| Handgeschreven mocks van de buur | een mock die de schrijver bedacht, bevestigt wat de schrijver dacht. De stub komt uit het contract |
| De vraag "durven we te releasen" | vervangen door een oordeel dat op een artefact is vastgesteld |

**Elk scenario toont een delta, geen systeem.** De vraag die de showcase beantwoordt is niet *hoe bouw je dit* maar *wat verandert er in de opzet*. Daarom bouwt hij de bestaande praktijk niet na maar veronderstelt hem, en laat hij per scenario zien wat erbij komt en wat eraf kan.

### Waarom deze showcase

Contract-based testing laat zich slecht uitleggen en goed laten zien. Deze showcase is daarvoor gemaakt: een werkend voorbeeld per grenstype, draaiend op één laptop, om het mechanisme te tonen in plaats van te beschrijven. Elk scenario behandelt één testfeature en werkt op zichzelf.

**Eigenaarschap.** Deze showcase en de bijbehorende repository zijn in eigen tijd gebouwd, staan onder eigen naam en zijn vrij te gebruiken door iedereen. Het systeem is fictief.

**Het is een demonstratie, geen levering.** Wie zo wil gaan testen, richt dat zelf in, in eigen deelsystemen en eigen pipelines. Deze showcase laat zien wat er bedoeld wordt en is niet bedoeld om als code te worden overgenomen. Dat een map bruikbaar is als startpunt, is een prettig gevolg en geen belofte.

De showcase is tot stand gekomen in samenwerking met Claude en gebouwd met Claude Code.

Daaruit volgt waar "af" ligt: een scenario is klaar zodra het argument overkomt, niet zodra hij de kwaliteit heeft die van productiecode verwacht zou worden.

**Randvoorwaarden waaronder dit werkt.** Deze manier van contracttesten is niet universeel; ze veronderstelt zes dingen, en die verklaren de keuzes die anders willekeurig lijken.

| | Randvoorwaarde | Gevolg voor het ontwerp |
|---|---|---|
| 1 | Eigenaarschap van deelsystemen ligt bij verschillende teams | een grens is organisatorisch gedefinieerd, niet technisch |
| 2 | De consumers zijn bekend en zitten binnen dezelfde organisatie | de provider kan het contract bezitten en publiceren; consumerverwachtingen zijn overbodig |
| 3 | Teams houden vrijheid binnen hun eigen deelsysteem | afspraken gelden op grenzen, niet op de binnenkant |
| 4 | Het doel is per deelsysteem naar productie kunnen releasen | de contractversie is het synchronisatiepunt, niet de deployvolgorde |
| 5 | Het gereedschap is open source en zonder licentie te draaien | geen commercieel platform voor contractuitwisseling; losse onderdelen die elk vervangbaar zijn |
| 6 | Een rode pipeline of omgeving is eerste prioriteit van de squad | waarnemen mag voorspellen vervangen; een signaal dat mag blijven staan is geen signaal |

Valt randvoorwaarde 2 weg — publieke API's, onbekende afnemers — dan verschuift de afweging en worden consumer-driven contracts aantrekkelijker. Valt randvoorwaarde 5 weg, dan komt het bidirectionele model in beeld en wordt een deel van het handwerk hier overbodig. Contract-based testing is hier een middel voor randvoorwaarde 4, geen doel op zich.

**Autonomie heeft een prijs, en de squad betaalt hem zelf.** Randvoorwaarde 3 geeft vrijheid binnen het eigen deelsysteem. Wat daar tegenover staat is strengheid op de rand: het contract naleven, de gate accepteren, en rood meteen oppakken. Dat is de wissel — geen afstemming vooraf met andere squads, wel discipline op de eigen grens. Wie het eerste wil zonder het tweede te betalen, houdt geen autonomie over maar losse eindjes.

**Er is één ding dat telt en dat is productie.** Alles daarvoor — een groene pipeline, een werkende CI-omgeving, een goedgekeurde Test — is een tussenstand. Een squad die groen staat en niet levert, heeft niets opgeleverd.

Daaruit volgt waarom rood eerste prioriteit is, en het is een hardere reden dan collegialiteit. Zolang de pipeline of de omgeving rood staat, komt er niets van de squad naar buiten en is er dus geen resultaat. Rood repareren is daarmee geen onderbreking van het sprintwerk maar de voorwaarde ervoor: er ís geen sprintresultaat zolang het rood is. En dat de keten blijft werken is geen last van buiten maar precies wat de eigen vrijheid draagt — omdat de grenzen zijn aangetoond, hoeft niemand met een andere squad een deployvolgorde af te spreken.

### De opbouw

De showcase loopt langs drie assen. Een deel varieert het **grenstype**: hetzelfde mechanisme, een ander contractformaat. Scenario 2, 3 en 5 variëren de **levenscyclus**: dezelfde grens, een later moment in het leven van een contract. Scenario 4 varieert de **testsoort**: dezelfde grens, een andere vraag. Scenario 8 gaat over de **binnenkant** van een deelsysteem en is daarmee het enige dat geen grens beschrijft.

| # | Scenario | As | Onderwerp | Vereist |
|---|---|---|---|---|
| 0 | Startsituatie | — | wat er draait vóór contracttesten | — |
| 1 | CBT basis (API) | grenstype | Order → Payment, REST sync, OpenAPI | 0 |
| 2 | Wijziging zonder breuk | levenscyclus | additieve wijziging, v1.1.0 | 1 |
| 3 | Breaking wijziging | levenscyclus | twee majors serveren en verifiëren, v2.0.0 | 1 |
| 4 | Acceptatie | testsoort | e2e gebruikersflow over de keten | 1 |
| 5 | Sunset | levenscyclus | oude major uit de runtime | 3 |
| 6 | Async | grenstype | Payment → Notification, AsyncAPI | `ci/` en `deelsystemen/payment/` |
| 7 | SOAP | grenstype | externe betaalprovider, WSDL/XSD | `ci/` en `deelsystemen/payment/` |
| 8 | Frontend binnen een deelsysteem | binnenkant | Angular → eigen backend | `ci/` en het eigen deelsysteem |
| 9 | Frontend in shell | grenstype | shell ↔ remote, module-API | eigen model |

Scenario 1 tot en met 5 gebruiken dezelfde grens: het is één basis waar de contractlevenscyclus overheen loopt, geen vijf basissen. Scenario 1 tot en met 5 dekken de testfeatures F2 (een REST-grens), F3 (versiecontrole bij deployment) en F4 (monitoring op productie); 6 en 7 dekken F5 (async) en F6 (SOAP), en 9 gaat over een frontend-grens. Scenario 8 heeft bewust geen testfeature: de kaders gelden op grenzen, niet op de binnenkant.

**Scenario 0 varieert niets.** Het staat er om te laten zien waar de andere scenario's vandaan komen. Zonder dat is elke "toevoeging" een bewering die niemand kan nakijken, en dat is precies het gebrek dat deze showcase op grenzen aanwijst — toegepast op zichzelf.

**De showcase is een boom, geen rij.** De kolom *Vereist* zegt wat er af moet zijn, en dat is niet altijd een scenario: 6 en 7 hebben `ci/` en het deelsysteem Payment nodig, maar niets uit de tests van scenario 1. Dat services op de hoofdmap staan in plaats van in een scenariomap, maakt zo'n afhankelijkheid pas benoembaar. De nummering is vlak gehouden omdat 1.2 in dit document al een subparagraaf aanduidt.

**De volgorde is de bouwvolgorde.** Scenario 1 draagt ruwweg de helft van al het bouwwerk; 2 tot en met 5 zijn er kleine uitbreidingen op en maken het verhaal compleet tot het einde van de contractlevenscyclus. Pas daarna wordt het contractformaat gevarieerd. De frontend staat achteraan omdat hij het model oprekt en een nog openstaande keuze raakt.

### De repository

| | |
|---|---|
| Naam | `showcase-cbt` — het voorvoegsel zegt bij de eerste blik dat dit geen productiecode is |
| Plaats | GitHub, publiek, persoonlijk account; in eigen tijd gebouwd |
| Licentie | MIT: vrij te gebruiken, zonder garantie en zonder aansprakelijkheid |
| Gebruiksmodel | referentie om te bekijken en te draaien; fork of template voor wie er zelf mee wil spelen |

**Eén uitzondering: de site.** `showcase-website` staat in een eigen repository en is niet in deze opgenomen. Hij is van een andere squad, met een eigen backlog en een eigen tempo, en wat de twee verbindt is het contract op de grens ertussen en verder niets. Dat is geen praktische keuze maar de opzet: dit is de enige grens in de showcase waar het eigenaarschap werkelijk wisselt, en hem in deze repository trekken zou precies weghalen wat hem de moeite waard maakt. De afweging staat in `docs/showcase-site.md`, de rolverdeling in `docs/context.md` deel B.

**Eén repository.** Niet negen repositories: dan ontstaan negen kopieën van dezelfde scripts die uit elkaar lopen, en toont de showcase onbedoeld aan dat het niet standaardiseerbaar is. Binnen die ene repository staat wat gedeeld is op de hoofdmap en heeft elk scenario daarnaast een eigen genummerde map.

```
showcase-cbt/
├── README.md
├── LICENSE
├── ci/                       gedeelde scripts, één exemplaar
│   ├── pipeline-*.sh         de pipelines uit 1.4, één script per soort
│   ├── get-contract.sh       de enige weg naar een spec; nooit van schijf
│   ├── publish-contract.sh   de diff-gate en de publicatie
│   ├── generate-stub.sh      stub uit de spec, plus de validatie erop
│   ├── drift.sh              biedt de service aan wat het contract belooft
│   ├── verify-contract.sh    contractverificatie, beide rollen
│   ├── versieconformiteit.sh sluit alles op deze omgeving op elkaar aan
│   ├── controle.sh           wat bij elke push draait
│   ├── controle-gates.sh     de gates over de gates: zie 1.13, O15
│   ├── toets-tolerantie.sh   weigert streng en accepteert tolerant
│   ├── bouw-stubbundel.sh    de levering aan showcase-website
│   ├── vergelijk-rapporten.sh  de aftrekking van scenario 0 en 1
│   ├── stubbundel/           wat mee de bundel in gaat, zonder netwerkpad
│   ├── fixtures/             twee rapporten als invoer voor de aftrekking
│   └── lib/                  tools.sh, en commandowoorden.awk voor de gates
├── contracts/                alle specs, per grens en versie
│   ├── payment/             de grens uit de showcase: Order → Payment
│   └── showcase-cbt/         de grens uit de realisatie: scenario-api, run-stream
├── compose/                  wat van geen enkel deelsysteem is
│   ├── registry.yml          Apicurio, gedeeld
│   └── stub.yml              de stub die in de CI-omgeving de buur vervangt
├── playwright/               config en gedeelde specs: smoke, later UI
├── deelsystemen/             één map per deelsysteem, daaronder één per service
│   ├── order/
│   │   ├── order-api/
│   │   └── order-mf/
│   ├── payment/
│   │   ├── payment-api/
│   │   └── payment-mf/
│   ├── notification/         h6
│   │   ├── notification-api/
│   │   └── notification-mf/
│   └── portal/               h9
│       └── portal-shell/
├── 00-start/                 demo en README van de startsituatie
├── 01-basis/                 compose, demo, README
├── 02-wijziging-zonder-breuk/
├── 03-breaking/
├── 04-acceptatie/
├── 05-sunset/
├── 06-async/
├── 07-soap/
├── 08-frontend-binnenkant/
└── 09-frontend-shell/
```

**Onder `contracts/` staan twee soorten grenzen, en dat is geen slordigheid.** `payment/` is de grens uit de showcase: verzonnen, tussen twee verzonnen deelsystemen, en het onderwerp van scenario 1 tot en met 5. `showcase-cbt/` is de grens uit de realisatie: `scenario-api` en `run-stream`, tussen deze repository en showcase-website, met twee squads die er werkelijk aan weerszijden zitten. Dezelfde opzet, hetzelfde register, hetzelfde gereedschap — maar de een wordt getóónd en de ander wordt geléést. Of ze in deze repository uit elkaar moeten, is O14; wat hier vastligt is dát het er twee zijn, zodat niemand `scenario-api` voor een scenariogrens aanziet.

**Wat hier nog niet staat**, is wat qua structuur nog beweegt: `omgevingen/*.env`, `deelsystemen/*/grenzen.env` en `deelsystemen/*/releases/`. Die horen bij de showcase en niet bij de realisatie, en ze worden hier opgenomen zodra de versieafspraak vaststaat — ook dat valt onder O14.

Twee regels dragen deze indeling. **Wat gedeeld is, staat op de hoofdmap en bestaat één keer**: `ci/`, `contracts/`, `playwright/` en `deelsystemen/`. Zodra een scenario een eigen kopie van `get-contract.sh` of van Payment krijgt, is de claim dat het mechanisme uniform is niet meer waar. En **de genummerde mappen bevatten geen services, maar tests**: een compose die de juiste deelsystemen samenstelt, een demoscript, scenariospecifieke specs en een README die het argument uitlegt.

Dat een deelsysteem niet in een scenariomap thuishoort, volgt uit de showcase zelf: scenario 6 breidt Payment uit met een uitgaande grens naar Notification, en scenario 8 hangt er een frontend aan. Payment groeit dus mee met meerdere scenario's en kan niet van één ervan zijn. De nummering hoort bij de tests, niet bij de code die getest wordt.

**Een deelsysteem bestaat uit services.** De deelsysteemmap is daarom een houder en zelf geen service: elke microservice en elke micro-frontend staat eronder als eigen service, met een eigen build en een eigen image. Payment wordt zo `deelsystemen/payment/payment-api/`, met `payment-mf/` ernaast in plaats van in `08-frontend-binnenkant/`. Dat is dezelfde regel een niveau dieper: een service hoort bij het deelsysteem dat hem bezit, niet bij het scenario dat hem toevallig als eerste nodig heeft. Elk deelsysteem met een gezicht naar de gebruiker heeft een eigen micro-frontend: `order-mf`, `payment-mf`, `notification-mf`. Welke daarvan scenario 8 uitwerkt, is een andere vraag (O9).

**De portal stelt samen, hij bezit niet.** De shell laadt die micro-frontends op de pagina, maar hun broncode blijft bij het deelsysteem dat ze bezit. Zou `payment-mf` onder `deelsystemen/portal/` staan, dan wisselt er bij shell ↔ remote geen eigenaarschap meer en heeft scenario 9 geen grens meer om te tonen. Samenstellen op runtime en bezitten in de repository zijn hier twee verschillende dingen — en dat verschil is nu juist wat een frontend-grens tot een grens maakt.

Er zijn vier deelsystemen. Order en Payment dragen de grens uit scenario 1. Notification komt erbij in scenario 6 — Payment → Notification is een grens, dus wisselt daar eigenaarschap, en dan is Notification geen service van Payment maar een deelsysteem naast Payment. Portal komt erbij in scenario 9, met de shell erin: die wordt door een ander team geleverd dan de remotes die erin hangen, en dat is precies wat die grens interessant maakt.

Losstaand te draaien is daarmee elke genummerde map, mits de deelsystemen die hij samenstelt gebouwd zijn.

**Testgereedschap wordt hergebruikt, niet per scenario opnieuw ingericht.** Playwright staat op de hoofdmap in `playwright/` — niet onder een naam als `e2e`, want hij bedient meerdere lagen. Eén smoke-spec wordt op een base-URL geparametriseerd, met `ci/smoke.sh <base-url>` als enige aanroeppunt. Hij draait op Test en toont dat de keten loopt. Op de CI-omgeving draait geen smoke maar de volledige contractverificatie, en op Acceptatie de gebruikersflow; de drie lagen doen elk hun eigen werk en herhalen elkaar niet. Playwright is in dit soort omgevingen doorgaans al in gebruik voor de e2e van een deelsysteem; de showcase sluit daarop aan in plaats van er een tweede werkwijze naast te zetten. Showcasespecifieke specs — bijvoorbeeld die van de UI in scenario 8 — staan in de scenariomap zelf.

**De smoke gaat niet over inhoud.** De gedeelde smoke-spec assert uitsluitend op HTTP-status en op het doorlopen van de keten — geen veldwaarden, geen businessregels. Anders draait hij groen tegen de stub en rood tegen de echte buur om een reden die niets met de grens te maken heeft, en verhuist bovendien werk van een goedkope laag naar een dure.

**Laptopbudget is een ontwerpeis.** Alles draait naast een IDE tijdens een presentatie. Daarom is elke showcase los op te starten en is er geen enkel moment waarop alles tegelijk nodig is: registry plus één showcase is de maximale opstelling. Wat daar niet in past, wordt vereenvoudigd in plaats van uitgebreid.

**Het document staat in de repository.** `docs/` bevat dit document; `CLAUDE.md` op de hoofdmap verwijst ernaar en herhaalt de regels die niet overtreden mogen worden. Een showcase zonder het waarom is een hoop code zonder argument.

**Veilige code en schone dependencies.** Zo min mogelijk libraries: elke dependency is een toekomstige kwetsbaarheid, en bij deze functionaliteit zijn er weinig nodig. Per toegevoegde library staat in de commit waarom hij nodig is. Verder: geen secrets in code, yaml of compose — alles uit environment met een `.env.example` in de repository; Actuator stelt uitsluitend `health` en `info` bloot en nooit een wildcard; foutresponses volgen het `Error`-schema uit het contract en bevatten geen stacktrace of interne paden; XML-parsers hebben externe entiteiten en DTD's uitgeschakeld; images staan op een vastgepinde tag en containers draaien als non-root; scripts gebruiken `set -euo pipefail` en geven nooit credentials op de commandoregel. Dependabot staat aan, zodat de showcase niet stilletjes veroudert tussen twee demo's door.

**Vereenvoudigingen worden benoemd.** Een register zonder authenticatie en opslag in memory zijn prima keuzes voor een demo, maar iemand die de showcase leest, moet zien dát het vereenvoudigingen zijn. Elke bewuste versimpeling krijgt een commentaarregel op de plek zelf en staat verzameld in de README. Zonder dat lever je onbedoeld een blauwdruk met gaten erin.

**Draaien.** Docker en een shell zijn de enige vereisten; op Windows via WSL2, niet via Git Bash. Extern gereedschap zoals oasdiff draait als container achter een functie in `ci/lib/tools.sh`, zodat de versie op een laptop en op een runner identiek is.

**CI.** Er is één wrapper: `.github/workflows/controle.yml`, en die roept `ci/controle.sh` aan — de controles die bij elke push horen, niet de pipelines. De pipelines uit 1.4 draaien nu vanuit de demoscripts en niet vanuit een CI-platform; dat gat staat als O15 in 1.13.

**Een tweede wrapper voor GitLab CI is uitgesteld, niet gebouwd.** Er is geen besluit dat dit project op twee CI-systemen draait, en één wrapper schrijven die niemand tegen een echte GitLab-runner houdt, levert een bestand op dat groen lijkt omdat niemand het draait. Komt hij er, dan geldt vanaf dat moment: geen stap of conditie mag in het ene bestand staan en in het andere niet. De standaard zit hoe dan ook in de scripts en niet in het CI-platform — dat is wat zo'n migratie goedkoop houdt, en het is nu al waar: elk yaml-bestand hier is dun en roept uitsluitend `ci/` aan.

---

### Wat overal gelijk is

Dit is de standaard. Wijkt een scenario hiervan af, dan is dat een bevinding en geen variant.

| | Invulling |
|---|---|
| Contractbron | het register; nooit van schijf, nooit uit de repo van de provider |
| Scripts | `get-contract` en `publish-contract` zijn in alle showcases hetzelfde script |
| Versiebeheer | expliciete versie, immutable, consumer pint, geen "latest" |
| Publicatie | via de diff-gate; de gate hoort bij de contractwijziging, niet bij een pipeline |
| Pipelines | één per deelsysteem, volledig onafhankelijk van elkaar |
| Omgevingen | CI met stubs; Test met de echte deelsystemen en zonder buitenwereld; Acceptatie mét buitenwereld |
| Deploy | per deelsysteem, één tegelijk; de gate is de vorige omgeving groen |
| Testlagen | unit, integratie, e2e — contractverificatie is integratie met de spec als norm |
| Stub | gegenereerd uit de spec, gevalideerd bij het maken, nooit gecommit |
| Scenario's | de contractlevenscyclus uit scenario 2 tot en met 5 geldt voor elke grens |

### Het fictieve systeem en het contract

De hele showcase gebruikt hetzelfde fictieve systeem: **Order → Payment → Notification**, met Payment als centraal deelsysteem. Scenario 1 gebruikt de grens Order → Payment.

**Naamgeving in het register:** groep `payment` (de aanbieder), artifact `payment-api` (de interface). De groep is het deelsysteem dat het contract bezit en niet de grens: een grens heeft twee kanten en één eigenaar, en die eigenaar is de provider. Zo staat een tweede grens van hetzelfde deelsysteem — Payment → Notification in scenario 6 — vanzelf in dezelfde groep.

**Versie in het pad.** De provider moet bij een major twee versies naast elkaar serveren. Een padprefix maakt dat zichtbaar — in een demo zie je letterlijk twee routes draaien — waar een versieheader onzichtbaar blijft.

Dit is de spec zoals hij als v1.0.0 wordt gepubliceerd. Hij is hier met de hand ontworpen en wordt ongewijzigd overgenomen in `contracts/payment/payment-api/1.0.0/openapi.yaml`; het bestand in de repository is de werkkopie, deze tekst de herkomst.

```yaml
openapi: 3.0.3
info:
  title: Payment API
  version: 1.0.0
  description: Betaalgrens tussen Order en Payment.
paths:
  /v1/payments:
    post:
      operationId: createPayment
      summary: Betaling aanmaken voor een order
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PaymentRequest'
            example:
              orderId: ord-10231
              amount: 49.95
              currency: EUR
      responses:
        '201':
          description: Betaling aangemaakt
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Payment'
              example:
                paymentId: pay-88f21c
                orderId: ord-10231
                status: ACCEPTED
        '400':
          description: Ongeldig verzoek
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
              example:
                code: INVALID_AMOUNT
                message: amount must be greater than zero
  /v1/payments/{paymentId}:
    get:
      operationId: getPayment
      summary: Betaling opvragen
      parameters:
        - name: paymentId
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Betaling gevonden
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Payment'
              example:
                paymentId: pay-88f21c
                orderId: ord-10231
                status: DECLINED
        '404':
          description: Betaling niet gevonden
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
              example:
                code: PAYMENT_NOT_FOUND
                message: no payment with id pay-000000
components:
  schemas:
    PaymentRequest:
      type: object
      required: [orderId, amount, currency]
      additionalProperties: false
      properties:
        orderId:
          type: string
        amount:
          type: number
          format: double
          minimum: 0
          exclusiveMinimum: true
          maximum: 999999999.99
        currency:
          type: string
          enum: [EUR, USD, GBP]
    Payment:
      type: object
      required: [paymentId, orderId, status]
      additionalProperties: false
      properties:
        paymentId:
          type: string
        orderId:
          type: string
        status:
          type: string
          enum: [ACCEPTED, DECLINED]
    Error:
      type: object
      required: [code, message]
      additionalProperties: false
      properties:
        code:
          type: string
        message:
          type: string
```

**Drie dingen zitten er bewust in.** Beide voorbeeldresponses tonen een andere `status`, zodat de stub niet alleen het happy path laat zien. `additionalProperties: false` maakt een niet-gedeclareerd veld een contractschending in plaats van iets dat stilzwijgend meelift. En de wijzigingen voor de latere demo's liggen vast: scenario A voegt `paymentMethod` optioneel toe (v1.1.0), scenario B maakt van `amount` een object met `value` en `currency` en haalt `currency` uit de root (v2.0.0). Het tegenvoorbeeld bij scenario A ligt daarmee ook vast: `merchantId` verplicht toevoegen. Dezelfde beweging als `paymentMethod` — er komt een veld bij — en één woord verschil.

**Het schema draagt zoveel semantiek als het kan.** Dat een bedrag groter dan nul moet zijn en onder een grens moet blijven, kan JSON Schema uitdrukken: `minimum`, `exclusiveMinimum`, `maximum`. Welke valuta's worden aangenomen ook: een `enum`. Wat in de spec staat, kan een consumer controleren voordat hij verstuurt — een unittest bij de provider kan dat niet.

De implementatie houdt dezelfde regels aan en accepteert niet meer dan hij belooft. Zou Payment elke ISO 4217-code aannemen terwijl de spec er drie noemt, dan is de spec een onwaarheid over wat er gebeurt en weet een consumer die erop afgaat minder dan hij denkt. Dat die twee met de hand gelijk blijven, wordt maar half afgedwongen: accepteert de code mínder dan de spec belooft, dan valt de contractverificatie erover — die stuurt immers alles wat het contract toestaat. Accepteert hij méér, dan ziet niemand het, want niemand stuurt wat de spec verbiedt. Die kant blijft ontwerpwerk.

**Wat er dan aan semantiek overblijft** is één ding: dat een bedrag boven 500,00 wordt afgewezen. En dat is geen invoercontrole maar een businessuitkomst — 201 met `DECLINED`, geen 400. Daarmee staat het onderscheid uit 1.2 er scherper: alles wat over de *geldigheid* van een verzoek gaat, staat in het contract; wat over de *uitkomst* gaat, niet.

> Dit is een correctie op de baseline en geen contractwijziging: v1.0.0 was nog niet uitgeleverd. Was hij dat wel geweest, dan was `minimum`, `exclusiveMinimum`, `maximum` of `enum` toevoegen breaking geweest — de diff-gate meldt dat ook zo — en had het een major gekost. Een grens die je meteen in het schema had kunnen zetten, is later duur om er alsnog in te krijgen.

---

### Leeswijzer

Elk scenario is los te lezen en volgt dezelfde indeling: waar de showcase over gaat, wat hij toevoegt ten opzichte van deze context, de opzet met uitsluitend de afwijkingen, de demo, en de openstaande punten.

Scenario 1 is de uitzondering: die schrijft de gedeelde opzet volledig uit en dient daarmee als referentie voor de andere acht.

Niemand leest negen scenario's. Vijf leespaden:

| Vraag | Lees |
|---|---|
| Hoe werkt het mechanisme? | 1 |
| Hoe worden breaking changes gestopt? | 1 en 3 |
| Hoe verloopt de levenscyclus van een contract? | 1 tot en met 5 |
| Werkt dit ook buiten REST? | 1 en 6, of 1 en 7 |
| Geldt dit ook voor de frontend? | 8 voor binnen een deelsysteem, 1 en 9 voor de grens tussen shell en remote |

---

## 0. Startsituatie

> Vereist: niets. Scenario 1 vereist dit scenario.

Dit scenario toont wat er draait vóórdat contracttesten bestaan. Wat er wel en niet is, staat in *De startsituatie* hierboven; hier wordt het gedraaid in plaats van beschreven.

**Het staat apart om één reden.** Zat de startsituatie in hetzelfde script als scenario 1, dan hield niets tegen dat hij het register aanraakt, en rustte de bewering "hier speelt het schema geen rol" op discipline. Een eigen map die alleen de scripts van vóór CBT aanroept, maakt er een eigenschap van de indeling van. Dat is dezelfde zet als "de omgeving ís het netwerk".

### 0.1 Eén doorloop, twee deelsystemen

Elk deelsysteem loopt zijn eigen weg af, van code tot Acceptatie: eerst Payment, dan Order.

| Stap | Wat er gebeurt |
|---|---|
| bouwen en testen | unit, integratie, een image per microservice |
| naar de CI-omgeving | het deelsysteem alleen neerzetten, de buren als **handgeschreven** stub, en e2e binnen het deelsysteem draaien |
| naar Test | deployen, healthcheck, de smoke van dat deelsysteem |
| naar Acceptatie | deployen, healthcheck |
| daarna, één keer | de gebruikersflow over de complete keten |

**De CI-omgeving bestaat hier al.** Wat er niet is, is de herkomst van wat erin staat: de stub is met de hand geschreven door degene die hem gebruikt, niet gegenereerd uit een gepubliceerd contract. Hij dekt wat de schrijver nodig had, en niets meer — zo schrijf je een stub als er geen norm is om hem uit af te leiden.

**De gebruikersflow hangt aan geen enkele deploy.** Hij spant over de keten en kan dus niet van één squad zijn; hij draait één keer, nadat beide deelsystemen er staan. In scenario 0 valt dat samen met de volgorde en levert het geen spanning op — daar deployt de tribe toch samen. In scenario 1 is het het verschil tussen zelfstandig releasen en op elkaar wachten.

**Scenario 1 doet exact hetzelfde.** Dezelfde twee deelsystemen, dezelfde versies, dezelfde omgevingen — alleen mét contracttesten. Er verandert geen enkel versienummer tussen de twee scenario's, en dat is opzet: zo is er precies één variabele.

> **Het werk dat contracttesten toevoegt = wat scenario 1 doet − wat scenario 0 doet.**

Die aftrekking is alleen zuiver als al het andere gelijk blijft. Vandaar geen bugfix, geen versiebump en geen extra deelsysteem aan één van beide kanten. Wat overblijft in het verschil is het register, de stub, de verificatie aan beide kanten, de drift-check en de versieconformiteit — en niets anders.

**Wat er niet gebeurt weegt even zwaar als wat er wel gebeurt.** In geen enkele stap komt het schema van de grens voor. Het ligt in `contracts/`, het wordt niet gelezen, en niets valt erop. Dat is "schema-first is er wel, maar niet afdwingbaar" aangetoond in plaats van beweerd.

**Dit scenario is de makkelijkste om verkeerd te lezen.** Alles wordt groen, en terecht. Het risico is dat het publiek concludeert dat er niets aan de hand is. Het punt is niet dat er iets misgaat; het punt is dat je aan deze uitkomst niet kunt zien óf er iets misgaat aan de grens.

### 0.2 Wat er is en wat er niet is

Er wordt getest, en niet zuinig. Wat ontbreekt is niet de test maar de **norm buiten de
test**.

| | In de startsituatie |
|---|---|
| Schema-first werken | **wel** — er ligt een OpenAPI-bestand en de grens is er eerst |
| De grens wordt geraakt | **wel** — de smoke op Test loopt er doorheen |
| De grens is onderwerp van een test | **niet** |
| Een centraal register | **niet** |
| Een gate op een wijziging van de spec | **niet** |
| Een stub die uit het contract komt | **niet** |
| Een providertest tegen het contract | **niet** |
| Een consumertest tegen het contract | **niet** |
| Een drift-check tussen belofte en implementatie | **niet** |
| Versieconformiteit over de omgeving | **niet** |

**De grens wordt geraakt, niet getest.** Er is geen enkele test wiens onderwerp de grens is;
hij komt langs omdat een smoke er doorheen loopt. Valt hij om, dan is de uitslag een rode
smoke op Test en begint het zoeken — de test wees niet naar de grens, dus de uitkomst ook
niet.

**Alles wat er is, toetst tegen een norm die de schrijver zelf heeft bedacht.** Unit,
integratie, de mock van de buur, de smoke: allemaal geschreven door de partij die ook de
code schrijft. Dat is niet fout, het is alleen niet **onafhankelijk**: je kunt de norm
bijstellen tot je test groen is, in hetzelfde bestand en in dezelfde commit, en niemand
merkt het.

`OrderIntegratieTest` mockt `PaymentClient` en schrijft het antwoord van de buur zelf voor.
Die mock is niet fout — hij is **onbewijsbaar**. Hij bevestigt wat de schrijver dacht dat
Payment doet, en blijft groen als Payment verandert.

Daarmee is wat scenario 1 toevoegt niet *meer* testen, maar één ding waaruit de rest volgt:
een norm die buiten de test ligt. Elk "niet" in de tabel hierboven is in scenario 1 een
"wel", en telkens is het register de bron.

**Eén ervan is geen test.** De gate op een schemawijziging vergelijkt twee artefacten en
draait op een ander moment — bij de wijziging van de spec, niet bij een build. Dezelfde
familie als een linter, en de reden dat hij een eigen pipeline heeft (1.4).

### 0.3 Wat het oplevert

Een eigen rapport, `00-start/rapport/rapport-cbt-00`, naast dat van scenario 1. Twee rapporten naast elkaar tonen het verschil beter dan één rapport met een knip erin — en omdat de dekking gelijk is, is dat verschil af te lezen in plaats van te geloven.

| | Scenario 0 | Scenario 1 |
|---|---|---|
| Deelsystemen | order en payment | order en payment |
| Versies | alle 1.0.0 | alle 1.0.0 |
| Omgevingen | CI, Test, Acceptatie | CI, Test, Acceptatie |
| Pipelines | 4 per deelsysteem | 4 per deelsysteem, plus die van het contract |
| Regels in het rapport | 28 | 37 |

**Vier en niet vijf.** 1.4 beschrijft er zes: één voor het contract, één voor de microservice, en vier voor het deelsysteem onderweg naar productie. De laatste daarvan — pipeline 6, naar Productie — is bewust niet gebouwd, want een vierde omgeving op een laptop toont hetzelfde als Acceptatie zonder de koppelingen (1.12). Wat er per deelsysteem draait is dus: microservice, CI, Test, Acceptatie.

**Negen regels verschil, en ze zijn met naam te noemen:**

| Waar | Wat erbij komt |
|---|---|
| het contract | de diff-gate met de publicatie, het terughalen ter controle, en het oordeel daarover |
| CI van de consumer | de stub wordt gegenereerd in plaats van geschreven, en de consumerverificatie |
| CI van de provider | de drift-check en de providerverificatie |
| Test | de versieconformiteit, per deelsysteem |

Dat is het antwoord op "wat kost contracttesten en wat levert het op", uitgedrukt in wat er werkelijk draait in plaats van in een belofte. Het is ook een ondergrens: in een bestaande omgeving komt daar eenmalig het werk bij om te repareren wat de eerste verificatie aan het licht brengt (zie 1.11).

**Die aftrekking wordt afgedwongen en niet aangenomen.** `ci/vergelijk-rapporten.sh` toetst dat elke stap uit scenario 0 in dezelfde volgorde terugkomt in scenario 1, en leidt het verschil daaruit af. Dat is nodig omdat de koppeling tussen de twee scenario's anders stilletjes breekt: voegt een later scenario een deelsysteem toe aan één van beide, of loopt de volgorde uiteen, dan blijven allebei gewoon groen en wordt alleen de conclusie onwaar. Een bewering die nergens door wordt afgedwongen is precies wat deze showcase aanvalt — ook wanneer de showcase hem zelf doet.

Wat níet in het verschil zit, is even belangrijk. De CI-omgeving stond er al, de stub stond er al, de smoke en de gebruikersflow stonden er al. Contracttesten voegt geen laag toe aan de piramide en geen omgeving aan de straat — het verandert waar de norm vandaan komt.

---

## 1. Basis (API)

Twee deelsystemen, één grens: Order (consumer) → Payment (provider), REST, schema-first, contract in Apicurio. Dit scenario is de referentie-implementatie: het beschrijft de opzet die de andere showcases alleen nog aanvullen.

> Hieronder staat wat er is en waarom. **Hoe je het draait** staat in `01-basis/README.md`.

### 1.1 Rationale

**Eén contract, twee kanten.** De provider bezit en publiceert het contract. Beide kanten verifiëren hun eigen conformiteit tegen diezelfde gepubliceerde spec. Geen consumer-expectations, geen n×m-verificatie, geen tweede contractstore.

**De contractversie is het synchronisatiepunt, niet de deployvolgorde.** Twee pipelines die elkaar nooit zien, komen via één contract tot hetzelfde oordeel. Daarom is er geen release train: compatibiliteit is vastgesteld op Build, niet afgestemd bij de deploy.

**Voorspellen is een verwachting, waarnemen is een feit.** Een `can-i-deploy`-vraag bevraagt vastgelegde verificatieresultaten en zegt daarmee dat de contracten zijn geverifieerd — niet dat het werkt. Configuratie, data en alles wat buiten het contract valt, ziet hij niet, en dat moet je alsnog met een correctie opvangen. Die capaciteit heb je dus hoe dan ook nodig. Daarom deployt hier één deelsysteem tegelijk en is een rode controle op de omgeving het signaal.

Dat werkt op één voorwaarde: de controles moeten de fout kunnen zien. De smoke gaat niet over inhoud en herkent geen verkeerde versiecombinatie — de versieconformiteitscheck doet dat, en die draagt daarmee deze keuze. Extra zekerheid is goedkoop: draai de controle nog een keer. Waarnemen mag je herhalen, een voorspelling wordt er niet beter van.

**Contract is geen testlaag maar een norm.** De piramide houdt drie lagen — unit, integratie, e2e. Wat verandert is niet de laag maar de bron van de waarheid: bij unit en integratie ligt de norm in de test, bij contractverificatie ligt hij buiten de test, in een artefact dat elders wordt beheerd. Contractverificatie is daarmee integratie: één deelsysteem, buren gestubd.

**Schema-first minimaliseert geen breuken maar verplaatst ze.** Een noodzakelijke breuk blijft noodzakelijk. Wat verandert is het moment: bij schema-first is de breuk een besluit vóórdat er code ligt, bij code-first een ontdekking als terugdraaien al duur is. De contractverificatie dwingt die belofte af; de drift-check vult het ene gat dat zij niet kan zien.

**Drie omgevingen, drie vragen.** In de CI-omgeving wordt aangetoond dat een deelsysteem volledig werkt zónder zijn buren. Op Test dat de samenstelling die op dat moment draait, klopt en loopt. Op Acceptatie dat de keten doet wat een gebruiker verwacht, mét de koppelingen naar buiten.

**Transparantie is een deel van het mechanisme, geen bijproduct.** De uitkomst van de controles is per deelsysteem zichtbaar op één dashboard, groen of rood. Zonder dat beeld is "waarnemen in plaats van voorspellen" een belofte die niemand kan controleren, en blijft rood staan omdat niemand hem ziet.

**Er zijn twee versies, en ze bewegen los van elkaar.** De contractversie is die van de grens: hij staat in het register, de provider bepaalt hem via de diff-gate, en hij beweegt alleen als de grens verandert. De serviceversie is die van het deelsysteem: hij komt uit de build en beweegt bij elke release. Payment kan naar serviceversie 1.4.0 zonder dat de contractversie meebeweegt — en dat is precies waarom Order niets merkt, want die pint op het contract en niet op de service.

De relatie is niet één-op-één. Vanaf scenario 3 serveert één serviceversie twee contractversies naast elkaar; aan de providerkant is het dus een verzameling. Aan de consumerkant blijft het één pin.

**Onveranderlijkheid geldt voor elk artefact, niet alleen voor contracten.** Eén build levert één versie op, en die image gaat ongewijzigd door alle omgevingen. Geen hertagging, geen `-rc`-achtervoegsel dat later verdwijnt: dan is wat je getest hebt niet meer hetzelfde artefact als wat je uitlevert. Release candidate is een status, geen naam. Zakt een versie, dan komt er een volgende — net als in het register, waar ook geen rollback bestaat maar alleen een nieuwe versie.

**Het register is de distributievorm, niet de randvoorwaarde.** De showcase gebruikt Apicurio omdat dat het eindbeeld is. Het contracttesten hangt er niet van af: een provider die zijn spec als getagd build-artefact publiceert en consumers die daarop pinnen, levert dezelfde verificatie op. Alleen `get-contract` verandert dan.

**Effort naar rato van risico.** Niet elk risico krijgt een test. Een risico wordt belegd bij de goedkoopste maatregel die het kan zien: een gate op een artefact, een controle op de omgeving, of menselijk ontwerpwerk.

---

### 1.2 Wat de deelsystemen doen

Het gedrag is bewust minimaal en volledig deterministisch: een demo mag niet afhangen van toeval of van de tijd.

**Payment** neemt een betaling aan, slaat hem op en geeft hem terug.

| Situatie | Uitkomst |
|---|---|
| `orderId` is `null` | 400, `INVALID_REQUEST` |
| `amount` ontbreekt of is `<= 0` | 400, `INVALID_AMOUNT` |
| `amount > 999999999.99` | 400, `INVALID_AMOUNT` |
| onbekende valutacode | 400, `UNKNOWN_CURRENCY` |
| `amount > 500.00` | 201, `status: DECLINED` |
| overige | 201, `status: ACCEPTED` |
| GET op onbekend id | 404, `PAYMENT_NOT_FOUND` |

**De eerste drie regels zijn niet bedacht maar overgeschreven uit het schema.** `orderId` is `type: string`, en JSON-`null` voldoet wel aan `required` en niet aan het type; zonder die controle lift een `null` mee tot in de response, die daarmee zijn eigen schema schendt. `maximum: 999999999.99` staat in de spec omdat een bedrag daarboven niet op te slaan is — zonder die grens werd dat een 500 op een verzoek dat volgens de spec geldig was. Beide zijn door de contractverificatie gevonden en niet door een eigen test: die stuurt alles wat het contract toestaat, en dat is meer dan iemand met de hand bedenkt.

Ze staan hier omdat een consumer erop stukloopt. Ongeschreven gedrag aan een grens is precies wat een contract hoort weg te nemen, en gedrag dat wél in het schema staat maar niet in de beschrijving ernaast, is de helft van dat werk.

**Order** neemt een bestelling aan, roept Payment aan en verwerkt de uitkomst: `ACCEPTED` wordt `CONFIRMED`, `DECLINED` wordt `CANCELLED`. Order heeft een eigen minimale API (`POST /orders`, `GET /orders/{id}`) die geen grens is — daar wisselt geen eigenaarschap — en die dus niet in het register staat.

Beide deelsystemen gebruiken een eigen H2-database in memory, met een repository ertussen, zodat de integratielaag iets te integreren heeft. Er is geen gedeelde database.

**Het onderscheid tussen 400 en `DECLINED` is de kern van dit scenario.** Een ongeldig bedrag is een contractschending: het verzoek voldoet niet aan de specificatie, dus 400. Een afgewezen betaling is een geldig verzoek met een negatieve uitkomst: 201 met een status. Wie die twee door elkaar haalt, dwingt de consumer om businessuitkomsten uit HTTP-statuscodes af te leiden.

De drempel van 500,00 is willekeurig maar vast. Ze levert twee scenario's op die niet uit de specificatie volgen en daarom als scenario-mapping in de stub terechtkomen (zie 1.6).

---

### 1.3 Drie omgevingen

Vier scopes, elk met een eigen plek en een eigen vraag. De trap loopt van één stuk code naar de hele keten, en bij elke trede is er minder vervangen.

| Scope | Waar het draait | Wat er echt is | Wat vervangen is | Testlaag |
|---|---|---|---|---|
| microservice | de build, geen omgeving | de eigen code | de buur, als mock **binnen** de test | unit, integratie |
| deelsysteem | efemere CI-omgeving | alle services van het deelsysteem | elke grens naar buiten, als stub uit het register | contractverificatie, e2e binnen het deelsysteem |
| systeem | Test | alle deelsystemen | alleen nog de buitenwereld | e2e over het systeem |
| systeem + externe interfaces | Acceptatie | ook de externe koppelingen | niets | e2e over de keten |

**Eén regel eronder:** een omgeving vervangt precies wat hij niet bevat, en de vervanging komt uit het contract van die grens. Elke trede maakt de vervanging kleiner, tot er niets meer te vervangen valt.

**Stubs bestaan op één niveau.** Eronder is het geen stub maar een mock in code: in hetzelfde proces, zonder deploy, en met de norm binnen de test. Erboven valt er niets te stubben, want de buren staan er echt. Wie op Test een stub van een buurdeelsysteem tegenkomt, kijkt naar een fout — niet naar een keuze.

**Waarom Test én Acceptatie.** Het verschil is eigenaarschap, niet volledigheid. Test is de laatste omgeving die je volledig bezit: alles erin is te resetten, te versiebeheren en af te dwingen. Acceptatie is de eerste waar dat niet meer geldt — een externe partij heeft zijn eigen releasekalender, zijn eigen storingen en zijn eigen testdata, en die zet jij niet terug.

Samenvoegen koopt twee problemen tegelijk: een storing bij een ander maakt jouw Test rood, en een reset van Test vraagt om iets terug te zetten wat niet van jou is. Daarom loopt de knip precies op de grens van wat je bezit. Dat is de technische reden voor een plek waar externe koppelingen echt zijn; of dat een blijvende omgeving moet zijn waar mensen met eigen ogen naar kijken, is een andere vraag — zie bijlage A.

| | CI-omgeving | Test | Acceptatie |
|---|---|---|---|
| Samenstelling | het deelsysteem + `stub.yml` | alle deelsystemen | alle deelsystemen + `extern.yml` *(nog niet)* |
| Buren | WireMock-stub uit de spec | de echte deelsystemen | de echte deelsystemen |
| Buitenwereld | gestubd, net als de buren | **geen** koppeling; wat buiten staat is gestubd | **wel** koppeling, niets gestubd |
| Deploy | het deelsysteem uit deze pipeline | één deelsysteem tegelijk | één deelsysteem tegelijk |
| Gate | de eigen tests staan groen | de controles op Test staan groen voor dat deelsysteem | — |
| Testlaag | integratie | e2e | e2e |
| Toont aan | het deelsysteem werkt volledig, buur niet nodig | de samenstelling klopt en loopt | de keten doet wat een gebruiker verwacht |

**De eenheid van deploy is het deelsysteem.** Bouwen en testen gebeurt per service — `payment-api` en `payment-mf` zijn elk een eigen image — maar wat een omgeving in gaat, is het deelsysteem als geheel.

**Eén compose per deelsysteem, in alle drie de omgevingen dezelfde.** Een deelsysteem staat één keer beschreven, in `deelsystemen/<naam>/docker-compose.yml`. Een omgeving is geen eigen bestand maar een samenstelling van die bestanden:

```sh
# Test
docker compose -f deelsystemen/order/docker-compose.yml \
               -f deelsystemen/payment/docker-compose.yml up -d
```

Dat is dezelfde regel als bij de scripts: wat gedeeld is, bestaat één keer. Zou Payment apart beschreven staan voor CI, voor Test en voor Acceptatie, dan lopen die drie uit elkaar zodra `payment-mf` erbij komt — en dan toont de CI-omgeving iets aan over een deelsysteem dat elders anders draait. Nu is wat op Test staat per definitie hetzelfde als wat op CI is aangetoond.

Wat per omgeving verschilt, staat niet in een tweede servicedefinitie maar in environment: welke versie er draait, en waar de buur te vinden is. De stub (`compose/stub.yml`) komt erbij als los bestand, niet als variant van het deelsysteem zelf.

**`compose/extern.yml` bestaat nog niet.** Hij hoort bij scenario 7, waar de externe betaalprovider erbij komt; tot dat moment heeft geen enkele omgeving een koppeling naar buiten en valt er niets samen te stellen. De vorm ligt wel vast: hetzelfde patroon als `stub.yml`, een los bestand dat met `-f` wordt meegegeven en dat het deelsysteem zelf niet verandert.

**Er is geen moment waarop alles tegelijk verhuist.** Elk deelsysteem schuift op zijn eigen tempo op en de gate is telkens de vorige omgeving die groen staat. Dat is randvoorwaarde 4 in de praktijk.

**Acceptatie is de enige omgeving met koppelingen naar buiten**, en dat is wat hem onderscheidt van Test. Op Test staat een externe partij als stub — voor scenario 7, waar de buur een externe betaalprovider is, betekent dat concreet dat "echte buren" geldt voor de eigen deelsystemen en niet daarbuiten. Waarom Acceptatie er überhaupt is, staat in bijlage A.

---

### 1.4 De pipelines

Een pipeline hoort bij één artefact en bij één eigenaar. Dat levert zes soorten op: één
voor het contract, één voor de microservice, en vier voor het deelsysteem onderweg naar
productie.

| # | Pipeline | Per | Draait als | Stappen |
|---|---|---|---|---|
| 1 | schema → register | grens | de spec wijzigt | diff-gate · publiceren met expliciete versie |
| 2 | microservice | microservice | de code wijzigt | build · `unit` · `integratie` · image met eigen versie |
| 3 | deelsysteem → CI | deelsysteem | 2 groen | efemere omgeving · stub uit het register · contractverificatie · e2e binnen het deelsysteem · opruimen |
| 4 | deelsysteem → Test | deelsysteem | 3 groen | deploy · healthcheck · versieconformiteit · smoke van dat deelsysteem |
| 5 | deelsysteem → Acceptatie | deelsysteem | 4 groen | deploy · healthcheck · de eigen koppelingen naar buiten |
| 6 | deelsysteem → Productie | deelsysteem | 5 groen | deploy · **check**: health, versies, monitoring |

**Hiermee brengt een squad zijn deelsysteem zelf naar productie.** Geen enkele stap vraagt
om een ander team, en de gate is telkens de vorige omgeving groen. Er is geen moment waarop
alles tegelijk verhuist.

**Het contract heeft een eigen pipeline omdat het een eigen levenscyclus heeft.** Een grens
wijzigt op een ander moment dan de code die hem implementeert, en de contractversie beweegt
los van de microserviceversie. Zou publiceren een stap in pipeline 2 zijn, dan zou elke
codewijziging aan de spec komen en zou een spec zonder implementatie niet te publiceren
zijn — terwijl schema-first juist vraagt dat het contract er eerder is.

**Op productie staat "check" en niet "test".** Daar wordt niet meer aangetoond dat het werkt;
daar wordt waargenomen dat het werkt. Health, welke versies er staan, en monitoring — dat is
testfeature F4. Wie op productie test, heeft de vorige omgevingen niet vertrouwd.

**Daarnaast pipelines die over het geheel gaan.** De lijst is open; wat erbij komt voldoet
aan dezelfde twee eisen.

| Pipeline | Wat hij vaststelt |
|---|---|
| alle grenzen | elke pin die op de omgeving staat, wordt daar ook geserveerd |
| alle smokes | de samenstelling loopt nog, ook als er niets is gedeployd |
| alle gebruikersflows | de keten doet wat een gebruiker verwacht |

**Het verschil tussen de twee groepen is waar ze aan hangen.** Pipeline 1 tot en met 6
hangen aan een artefact: er is iets gewijzigd, en dit is het bewijs dat het mag doorschuiven.
De gedeelde pipelines hangen aan een moment: de samenstelling verandert ook als niemand iets
deployt, want de buurman deployt wel. Ze draaien daarom gepland.

**Een gedeelde pipeline is nooit een gate voor één squad.** Zou een squad moeten wachten tot
de tribe-brede run groen is, dan is de afstemming terug die contracttesten juist wegneemt —
alleen nu in gereedschap gegoten. Ze stellen vast en ze houden niemand tegen; wie ze rood
maakt, hoort het als eerste.

**Wat op Test en Acceptatie draait, mag klein blijven.** De diepte zit in pipeline 3: daar
staat het deelsysteem alleen, met stubs waar zijn buren horen, en daar is een run goedkoop.
Op Test volstaat dat het loopt, op Acceptatie dat de keten doet wat een gebruiker
verwacht. Geen smoke op Acceptatie — de laag eronder heeft dat al aangetoond, en herhalen
verplaatst werk naar de duurste plek.

**Een gebruikersflow kan niet van één squad zijn.** Hij volgt wat een gebruiker doet, en
die merkt niets van de indeling in deelsystemen — de flow spant er dus overheen en heeft de
hele keten nodig. Zou hij aan pipeline 5 hangen, dan blokkeert de afwezigheid van de buur
de release van dit deelsysteem, en wacht de ene squad op de andere. Dat is de afstemming
die contracttesten wegneemt, alleen in gereedschap gegoten.

Hij hoort daarom bij de gedeelde pipelines: gepland, over de keten, en geen gate. Valt hij
om omdat een deelsysteem ontbreekt, dan is dat een juiste uitkomst met een juiste boodschap
— *deze omgeving is niet compleet* — en een signaal voor de tribe in plaats van een
blokkade voor een squad.

Dat er dan iets faalt, is geen tekort van contracttesten maar het bewijs dat ze werken: de
verificatie op de CI-omgeving heeft al vastgesteld dat de kant van dít deelsysteem klopt,
zonder dat de buur ergens draaide. Wat overblijft om te falen gaat over de samenstelling en
niet over de grens.

---

### 1.5 Wat de rol bepaalt

Pipeline 2 doet niet overal hetzelfde, en dat verschil volgt uit de **grens** en niet uit
het deelsysteem. Een deelsysteem kan contracten serveren, contracten pinnen, of allebei —
Payment doet in scenario 1 het eerste, in scenario 6 het eerste tweemaal, en in
scenario 7 ook het tweede. Daarom is de rol een eigenschap die de pipeline afleidt, en
geen parameter die je meegeeft.

**Serveert het deelsysteem een contract?** Dan hoort daarbij:

| Stap | Laag | Tegen | Norm |
|---|---|---|---|
| `get-contract` van elke versie die hij serveert | — | register | — |
| drift: welke operaties biedt hij aan | geen | artefact | **spec** |
| contractverificatie | integratie | **draaiend deelsysteem** | **spec** |

Die verificatie is volledig, geen steekproef: elke operatie uit de spec, elke responsecode,
happy en unhappy, als regressie.

**De drift-check vergelijkt operaties, niet schema's.** Hij houdt de paden en methoden die
de draaiende service aanbiedt tegen die van het contract. Dat is smal met opzet: de
contractverificatie dekt de inhoud al en doet dat beter, want die toetst gedrag in plaats
van een beschrijving.

Wat drift toevoegt is het zien van een **schaduw-API**: een operatie die de service
aanbiedt en die het contract niet noemt. Een debug-endpoint dat bleef staan, een interne
route voor een migratie. Het gevaar is niet dat hij bestaat maar dat hij buiten het
mechanisme valt — geen versie, geen gate, geen consumer die erop pint.

De grens tussen de twee controles ligt preciezer dan je zou denken, en is gemeten:

| Schaduw | Drift | Contractverificatie |
|---|---|---|
| een nieuwe **methode** op een pad dat het contract kent | ziet het | ziet het ook — een generator probeert methoden uit die de spec niet noemt en verwacht 405 |
| een **pad** dat nergens in de spec staat | ziet het | ziet het niet — er is geen aanknopingspunt om dat pad te raden |

Alleen die tweede rij is van drift alleen. Dat is genoeg reden om hem te hebben, en te
weinig om hem breder te maken; waarom niet, staat in `besluiten.md`.

**Pint het deelsysteem een contract?** Dan hoort daarbij:

| Stap | Laag | Tegen | Norm |
|---|---|---|---|
| `get-contract <pin>` | — | register | — |
| stub genereren en valideren | geen | artefact | **spec** |
| contractverificatie | integratie | **draaiend deelsysteem + stub** | **spec, beide richtingen** |

**Beide richtingen** betekent twee dingen tegelijk: wat de consumer verstuurt voldoet aan de
spec, én wat hij doet met de responses die uit die spec komen klopt. De eerste richting is
wat een provider-driven opzet toevoegt aan een integratietest met een mock — die mock zou
je zelf verzinnen, deze stub komt uit het contract.

Een consumer heeft geen drift-stap: hij bezit het contract niet, dus er valt aan zijn kant
niets van af te wijken.

**Twee stijlen voor de providerkant, en de pipeline kiest.** De testgevallen komen uit de
spec — gegenereerd — of ze zijn met de hand geschreven. De showcase houdt ze allebei,
omdat het verschil ertoe doet en zichtbaar hoort te zijn.

| | Gegenereerd | Geschreven |
|---|---|---|
| Herkomst | uit de spec, geen code | met de hand, JUnit met tag `contract` |
| Dekking | wat het contract toestaat | wat de schrijver bedacht |
| Norm | de spec | de spec, via een validator — niet de verwachting in de test |
| Leesbaar | een rapport | testnamen naast unit en integratie |

De handgeschreven variant is niet de mindere: hij is leesbaar, staat in dezelfde toolchain
en documenteert de paden die ertoe doen. Maar hij dekt per definitie wat iemand heeft
bedacht. In scenario 1 vond de gegenereerde variant zes gebreken in een implementatie met
vijftien groene tests — zie `besluiten.md`. Dat verschil is het argument om te genereren
waar dat kan.

De consumerkant kent die keuze niet. Een generator toetst een server aan zijn spec; er is
niets vergelijkbaars dat een cliënt uitoefent. Wat een consumer verstuurt is alleen te zien
door hem te laten draaien en achteraf in het journaal van de stub te kijken.

Voor unit en integratie speelt de keuze evenmin: daar ligt de norm in de test, en dan is
met de hand schrijven het enige dat betekenis heeft.

**Waarom contractverificatie na de deploy en niet tegen de code.** Een contract is een
belofte van een draaiend systeem. Configuratie, serialisatie en foutafhandeling in de echte
container horen erbij, en die vallen buiten beeld als je alleen de broncode toetst. De prijs
is een trager signaal dan een unittest; daarom staan unit en integratie eronder en vangen
die af wat ze goedkoop kunnen vangen.

---

### 1.6 Stubgeneratie

De stub wordt elke run opnieuw gegenereerd uit de spec uit het register en wordt nooit gecommit. Hij draait mee in de CI-omgeving, als de buur die daar niet staat.

Op Test en Acceptatie staan de eigen deelsystemen echt. Eén uitzondering: partijen buiten de organisatie draaien op Test als stub, want die omgeving heeft geen koppeling naar buiten. Dat raakt scenario 7 en verder niets in scenario 1.

**Waarom zelf genereren en geen kant-en-klare mockserver.** Prism van Stoplight doet twee dingen die hieronder als eigen werk staan al native: hij matcht padtemplates, en hij gebruikt de `example`-waarden uit de spec. Hij valideert bovendien binnenkomende requests tegen de spec, inclusief `additionalProperties: false` — dat is winst die deze opzet niet gratis krijgt.

Waar hij op afknapt is het scenario uit 1.2: een bedrag boven 500,00 hoort `DECLINED` op te leveren. Dat is een responsekeuze op basis van de requestinhoud, en Prism kiest per status altijd hetzelfde voorbeeld. De consumertest van Order zou daarmee de afgewezen betaling nooit kunnen doorlopen. WireMock kan het wel, met een matcher op de body en een prioriteit erboven.

Dat is de reden en de enige: niet dat een eigen generator beter is, maar dat de showcase een responsekeuze nodig heeft die een spec-gedreven mockserver principieel niet kan maken. Wie dat scenario niet heeft, kan hieronder stap 2 tot en met 5 vervangen door één regel.

| # | Stap | Uitvoer |
|---|---|---|
| 1 | `get-contract <naam> <pin>` | spec op vast pad, uit het register |
| 2 | spec parsen: operations en responses uitlezen | werklijst |
| 3 | per operation een matcher bouwen: method, pad, content-type | request-kant van de mapping |
| 4 | per response een body bepalen | response-kant van de mapping |
| 5 | mappings wegschrijven naar `build/stub/mappings/` | artefact |
| 6 | scenario-mappings toevoegen | extra mappings |
| 7 | validatie: elke body tegen zijn responseschema | pass/fail |
| 8 | dekkingscheck: elke operation minstens één mapping | pass/fail |

**Stap 4 — bron van de body.** Een body die uit het schema wordt gegenereerd levert typegeldige maar betekenisloze waarden op, waarmee de consumertest zijn waarde verliest. Norm is daarom dat elke response in de spec een betekenisvolle `example` bevat en dat de generatie faalt als die ontbreekt of leeg is. De spec is daarmee niet alleen de bron van de structuur maar ook van de stubdata, en een spec-review krijgt daarmee een concreet onderwerp.

**Stap 3 — padparameters.** OpenAPI-paden zijn templates (`/payments/{id}`); WireMock matcht daar niet vanzelf op. Dit is het onderdeel waarop generatoren stukgaan en het wordt daarom aangetoond met minstens één pad met parameter.

**Stap 6 — scenario-mappings.** Een spec beschrijft per status één response; een consumertest heeft ook een afgewezen betaling nodig. De scheidslijn tussen geaccepteerd en afgewezen is semantiek en volgt niet uit de spec. Handgeschreven scenario-mappings zijn daarom toegestaan in een aparte map, mits ze door dezelfde validatie in stap 7 gaan. Wat niet is toegestaan: een test die zijn eigen mapping definieert.

**Stap 7 en 8 zijn geen test maar een artefactcontrole**, in dezelfde familie als de drift-check.

---

### 1.7 Test en Acceptatie

Geen van beide is een pipelinestap. De controles draaien na **elke** deploy, ongeacht welk deelsysteem is gedeployd.

**Test — loopt de samenstelling?**

| Controle | Toont aan |
|---|---|
| healthcheck | de deelsystemen komen omhoog |
| versieconformiteit | welke contractversies draaien samen |
| smoke over de echte keten | de technische integratie werkt |

**De check vergelijkt niet met een verwachte samenstelling, maar met zichzelf** (O2, gesloten). De vraag is tweeledig: staat elke pin die op deze omgeving voorkomt als gepubliceerde versie in het register, en wordt hij op deze omgeving ook geserveerd? Dat is uit de omgeving zelf af te leiden — de consumers melden hun pins, de providers melden wat ze serveren — en er is dus geen bestand dat bijgehouden moet worden.

Dat is niet de goedkoopste oplossing maar de enige juiste, want een *verwachte* samenstelling bestaat hier niet: elk deelsysteem schuift op zijn eigen tempo op, dus er is geen moment waarop een bepaalde combinatie de bedoelde is. Een lijst met verwachte versies zou randvoorwaarde 4 tegenspreken en zou bij elke release van iemand anders verouderen. De vraag "draait hier de bedoelde combinatie" is daarmee de verkeerde vraag; "sluit alles hier op elkaar aan" is de goede.

Die eerste voorwaarde is geen formaliteit maar de reden dat deze check bij contracttesten hoort en niet bij de startsituatie. Zonder register zijn de versies op de info-endpoints twee handgeschreven beweringen die met elkaar vergeleken worden; pas als ze allebei naar een gepubliceerd artefact wijzen, stelt de vergelijking iets vast. In scenario 0 is de check daarom niet van toepassing — niet uitgezet, maar zonder grond.

In scenario 5 doet hij zijn werk: een consumer die gepind staat op een versie die niemand meer serveert, wordt rood zonder dat iemand een lijst hoefde bij te houden.

Die check is niet zomaar een van de drie. Hij is degene die het afzien van een `can-i-deploy`-gate verdedigbaar maakt: de smoke gaat niet over inhoud en komt groen door een verkeerde versiecombinatie heen, de versieconformiteitscheck niet.

**Acceptatie — doet de keten wat een gebruiker verwacht?**

Dezelfde deelsystemen, dezelfde RC-versies, plus de koppelingen naar buiten. Eén volledige gebruikersflow; de structuur van de grenzen is al aangetoond op de CI-omgeving en hoeft hier niet nog eens.

**Transparantie.** De uitkomst per deelsysteem staat op één dashboard, groen of rood. Dat is geen rapportage achteraf maar onderdeel van het mechanisme: waarnemen in plaats van voorspellen werkt alleen als de waarneming zichtbaar is. Een rood vlak dat niemand ziet, is geen signaal.

Dat dashboard beantwoordt drie vragen, en de derde is er niet bij gekomen om te testen (O11, gesloten):

| Vraag | Waar het antwoord vandaan komt |
|---|---|
| Wat draait er waar? | de info-endpoints: deelsysteem-, microservice- en contractversie per omgeving |
| Welke gates zijn gepasseerd, en wanneer? | het rapport dat de pipelines schrijven |
| Welke grenzen zijn er, wie serveert ze en wie hangt eraan? | het register |

**De derde vraag is de tribe-vraag.** Vraag een squad welke interfaces zijn deelsysteem aanbiedt, en het antwoord komt traag, incompleet of niet. Dat is geen onwil en geen gebrek aan overzicht bij de mensen: er is geen plek waar het staat. Eén register maakt er een opzoekvraag van, en pas dan is een tribe-breed beeld mogelijk zonder dat iemand het bij elkaar hoeft te vragen. Autonomie zonder dat beeld is geen autonomie maar onzichtbaarheid — en dat is een reden voor het register die losstaat van testen.

**Het dashboard leest echte toestand.** Versies uit draaiende info-endpoints, grenzen uit het register, gates uit het rapport. Geen enkel gegeven komt uit een demoscript, want dan toont het dashboard wat iemand bedoelde in plaats van wat er is. Dat is dezelfde regel als bij de stub, om dezelfde reden.

**Voorlopig één pagina.** De stip op de horizon is een site: per deelsysteem een pagina, per grens een pagina, en de testsoorten als kolommen zodat er later een UI-test bij kan zonder verbouwing. Voor dit scenario is één pagina genoeg — bovenaan wat er nu draait, eronder wat er in deze run is gebeurd. Wat er voor die site hoe dan ook geldt, staat in `docs/showcase-site.md`.

**Rood: eerst weer draaiend, dan pas de vraag hoe het kwam.** Op Test en Acceptatie draaien release candidates, en dan is vooruit meestal sneller dan terug: een kapotte RC is een signaal om snel een nieuwe te leveren. Rollback is het antwoord wanneer vooruit niet snel kan. Bij een afwijkende versiesamenstelling is roll-forward vrijwel altijd juist — het ontbrekende deelsysteem alsnog deployen in plaats van het geslaagde terugtrekken. Rollback geldt voor deployments; het register kent geen rollback, daar is alleen een nieuwe versie.

Voordat een controle een correctie in gang zet, mag hij nog een keer draaien. Herhalen is goedkoop en scheidt een echte fout van een toevallige — dat is de winst van waarnemen boven voorspellen.

Een gedwongen deployvolgorde is geen normale gang van zaken maar een signaal: de provider serveerde niet twee versies naast elkaar.

---

### 1.8 Testlagen en normen

De piramide houdt drie lagen. Contracttesten voegt er geen vierde aan toe.

```
        ╱╲          e2e          Test: smoke  ·  Acceptatie: gebruikersflow
       ╱  ╲
      ╱────╲        integratie   eigen database        → norm = de test
     ╱      ╲                    contractverificatie   → norm = de spec
    ╱────────╲      unit         semantiek             → norm = de test
   ╱__________╲

   ernaast: diff-gate · drift · stubvalidatie   (artefacten, geen runtime)
```

| | tegen code | tegen een draaiend deelsysteem |
|---|---|---|
| **unit** | unit tests — norm in de test | — |
| **integratie** | integratietest met eigen DB — norm in de test | healthcheck<br>contractverificatie op de CI-omgeving — norm = **spec** |
| **e2e** | — | smoke op Test · gebruikersflow op Acceptatie |

**e2e is relatief aan wat de omgeving bevat.** Dezelfde laag loopt op drie scopes: op de CI-omgeving door het deelsysteem heen met de buren gestubd, op Test door het systeem, op Acceptatie door de keten met de buitenwereld erbij. Dat is geen drie lagen maar één laag op drie treden van de trap uit 1.3. Zolang Payment uit één service bestaat valt e2e binnen het deelsysteem samen met de contractverificatie; vanaf scenario 8, als `payment-mf` erbij komt, wordt het onderscheid zichtbaar.

**De as is scope, niet snelheid.** Contractverificatie draait tegen een gedeployde container en is daarmee trager dan de smoke op Test, die een handvol aanroepen doet — en staat er toch onder. Wat de lagen ordent is hoeveel er tegelijk in beeld is: één klasse, één deelsysteem, de hele keten.

**De integratielaag draagt twee ongelijksoortige dingen.** Snelle tests in hetzelfde proces tegen de eigen database, en contractverificatie tegen een gedeployd deelsysteem met stubs. Zelfde scope, andere orde van grootte in doorlooptijd. De tag `contract` houdt ze uit elkaar in de pipeline-uitvoer, zodat een rode build meteen zegt welke van de twee viel.

**Wat contracttesten per laag verandert:**

| Laag | Zonder | Met |
|---|---|---|
| unit | semantiek die geen schema dekt | ongewijzigd |
| integratie | eigen database; de buur nagebootst met een zelfbedachte mock | de norm ligt buiten de test, in de spec uit het register; de stub wordt eruit gegenereerd in plaats van bedacht; volledig doorlopen |
| e2e | veel scenario's, want de structuur van elke grens moet hier blijken | weinig scenario's: smoke toont dat het loopt, één gebruikersflow toont de betekenis |

Daar zit het hele argument. Contracttesten maakt de middenlaag niet dikker maar strenger, en maakt de top kleiner omdat de structuur eronder al is aangetoond.

Buiten de piramide: diff-gate, drift-check en stubvalidatie. Dat zijn vergelijkingen van artefacten, geen runtime-gedrag — dezelfde familie als een linter.

Teamautonomie geldt voor unit en integratie. De gezamenlijke standaard geldt voor contractverificatie.

---

### 1.9 Publicatieroute

Een contract komt niet in het register omdat iemand het erin zet, maar omdat het door een gate is gekomen. `ci/publish-contract.sh` doet drie dingen:

| # | Stap | Faalt op |
|---|---|---|
| 1 | hoogste gepubliceerde versie ophalen | register onbereikbaar |
| 2 | oasdiff tegen de nieuwe spec | breaking wijziging zonder major-bump |
| 3 | publiceren met expliciete versie | versie bestaat al |

De diff-gate hoort bij de contractwijziging, niet bij de pipeline van Payment of Order: het is een vergelijking van twee artefacten, geen runtime-gedrag. Bij het aanmaken van het artifact wordt de compatibility rule op BACKWARD gezet, zodat het register een tweede net vormt als de gate wordt overgeslagen. Dat tweede net doet in Apicurio 3.3.1 ook voor artifact type `OPENAPI` inhoudelijk werk: een breuk die de gate omzeilt, krijgt HTTP 400 met een `RuleViolationException`.

**Wat de gate niet ziet.** oasdiff redeneert over de spec en niet over de implementatie, en kent de gevolgen van `additionalProperties: false` niet. Een veld uit een requestschema verwijderen levert daarom een warning op en geen error, terwijl bestaande consumers die het veld nog meesturen een 400 krijgen. Dezelfde soort grens als bij het schema zelf: de gate dekt de structuur, niet de betekenis.

Hiermee dekt dit scenario alle drie de detectiemomenten in de bouwstraat: breaking change op de schemawijziging, non-conforme provider-implementatie, non-conforme consumeraanroep. In scenario 1 heeft de gate nog niets te vergelijken — er is één versie. Vanaf scenario 2 doet hij werk.

Deze drie stappen zijn pipeline 1 uit 1.4: het contract heeft een eigen pipeline omdat het een eigen levenscyclus heeft. Wie hem start is een vraag voor de werkwijze en niet voor de techniek — de spec kan in de repository van de provider staan of in een eigen spec-repository met review door de architect (O5). Dat verandert wie het script aanroept, niet wat het doet.

---

### 1.10 De contractlevenscyclus in overzicht

Scenario 1 kent één contractversie en dus geen wijziging. De vier scenario's die daarna komen, staan hier in overzicht; elk is uitgewerkt in een eigen scenario.

| Scenario | Wat er gebeurt | Risico | Gezien door | Scenario |
|---|---|---|---|---|
| A. Geen breaking change | additief, minor | "minor" was stiekem breaking | diff-gate | 2 |
| Governance | consumer vraagt om uitbreiding | consumer bouwt een workaround | niets automatisch | 2 |
| B. Breaking change | major, twee versies naast elkaar | oude major verrot in CI | contractverificatie per major | 3 |
| — | versiecombinatie op een omgeving | verkeerde combinatie draait | versieconformiteit | 1.7 |
| B-sunset | oude major uit de runtime | pin staat er nog op | versieconformiteit | 5 |
| Alle | veld blijft, betekenis verandert | niets automatisch | ontwerp en review | — |

Twee dingen die uit dit overzicht volgen. **De meeste maatregelen zijn geen test:** een gate op een artefact, een controle op een omgeving, en menselijk ontwerpwerk. En de laatste rij is de residue waarvoor ketentesten overblijven — gelijk schema, andere betekenis — en daarmee het eerlijke antwoord op de vraag waarom die niet naar nul gaan.

---

### 1.11 Demo

De demo begint waar scenario 0 ophoudt: beide deelsystemen draaien, er is net een release doorheen gegaan, en er is geen register. Wat hier gebeurt is de toevoeging — dezelfde deelsystemen, nu met contracttesten.

**Aan het artefact verandert niets.** Geen image wordt herbouwd, geen samenstelling wijzigt, geen versienummer beweegt. Het contract krijgt voor het eerst een gepubliceerde versie, maar de spec zelf is dezelfde die er in scenario 0 ongelezen lag.

| Versieniveau | Na scenario 0 | Na scenario 1 |
|---|---|---|
| deelsysteem `payment` | 1.0.0 | 1.0.0 |
| microservice `payment-api` | 1.0.0 | 1.0.0 |
| contract `payment-api` | niet gepubliceerd | 1.0.0 |

**Wat verandert is het oordeel.** Dezelfde payment 1.0.0 die in scenario 0 groen door de pipeline kwam, gaat hier langs de contractlaag. Dat is een strengere norm op een ongewijzigd artefact — en daarmee is scenario 1 in de eerste plaats geen nieuwe manier van werken vooruit, maar een uitspraak over wat er al staat.

Dat is ook wat een squad als eerste meemaakt die dit invoert: de eerste run gaat niet over de volgende release maar over de huidige. Gaat hij rood, dan heeft de pipeline niets kapotgemaakt — **hij heeft zichtbaar gemaakt wat al niet klopte.** Het artefact was nooit conform; er keek alleen niemand.

**In deze showcase is die eerste run groen, en dat is met opzet.** Order en Payment zijn gebouwd om aan hun contract te voldoen, dus er valt niets te ontdekken. Een demo die struikelt over migratiewerk toont het mechanisme niet maar de rommel eromheen.

**In werkelijkheid is die eerste run een werklijst.** Dat is het echte werk van invoeren, en het is werk voor de squad — geen knop. De lijst heeft twee soorten regels:

| Bevinding | Wat je doet |
|---|---|
| de implementatie doet iets anders dan de spec belooft | de implementatie aanpassen |
| de spec beschrijft iets anders dan er altijd al gebeurde | de spec corrigeren en als nieuwe versie publiceren |

De tweede is in een bestaande omgeving vaak de grootste categorie: specs die één keer geschreven zijn en daarna zijn achtergebleven. Dat is geen tegenvaller maar de eerste opbrengst — vanaf dat moment klopt de beschrijving weer, en is hij afdwingbaar.

En dat is het verschil met wat er nu gebeurt als er iets misgaat aan een grens: **de lijst is eindig en precies.** Per grens, per operatie, per responsecode, met de spec ernaast. Dat is iets anders dan een rode ketentest en de mededeling dat er ergens iets fout zit.

Zou de deelsysteemversie hier wél oplopen, dan zou dat suggereren dat er iets aan het deelsysteem is veranderd. Er is niets veranderd. Er wordt alleen scherper gekeken, en dat is een eigenschap van de pipeline en niet van wat erdoorheen gaat.

**De volgorde is die van scenario 0**, en dat is geen detail: alleen dan staan de twee rapporten regel voor regel naast elkaar en is het verschil af te lezen in plaats van bij elkaar te zoeken.

| # | Scène | Zichtbaar |
|---|---|---|
| 1 | het contract gepubliceerd in het register, immutable en per versie | het schema is een artefact geworden |
| 2 | Payment van code naar Acceptatie, met drift en de volledige contractverificatie | conformiteit van de provider |
| 3 | Order dezelfde gang, met een stub uit het register in plaats van Payment | onafhankelijkheid van de consumer |
| 4 | de gebruikersflows over de keten, als gedeelde run | de keten doet wat een gebruiker verwacht |

**Scène 3 vervangt de handgeschreven stub uit 0.1.** Wat Order in zijn CI-omgeving tegenkomt is geen zelfgeschreven dubbelganger meer maar een stub uit het register. Dezelfde plek, dezelfde servicenaam, andere herkomst — en dat is de hele wijziging.

**Scène 3 gaat niet over de afwezigheid van Payment.** Payment is er net langsgekomen en draait op Test en op Acceptatie. Wat de scène toont is dat Order's *CI-omgeving* hem niet bevat: de pipeline komt tot een oordeel zonder dat er ergens met iemand hoeft te worden afgestemd. Dat Payment toevallig al klaar is, doet er niet toe — was hij het niet geweest, dan was de uitkomst dezelfde.

**Scène 4 hangt aan geen enkele deploy.** Beide Acceptatie-pipelines zijn er in scène 2 en 3 al langsgekomen, en geen van beide wachtte op de ander. Wat hier draait gaat over de samenstelling en niet over een grens.

De demo eindigt met het beeld uit 1.7: bovenaan wat er nu draait, eronder elke stap met tijdstip en uitkomst. Dat is hetzelfde testbewijs dat een pipeline oplevert en niet iets wat voor de demo apart wordt gemaakt.

De demo's uit scenario 2 tot en met 5 zijn scripts (`demo/<naam>.sh`), geen branches: een branch per scenario moet worden bijgewerkt bij elke wijziging in de basis. Elk script past de wijziging toe, draait de betrokken pipelines en eindigt met een reset naar de uitgangssituatie.

---

### 1.12 Bewust buiten dit scenario

| Onderdeel | Waar |
|---|---|
| Contractwijziging, breaking change, deprecation | scenario 2, 3 en 5 |
| De gebruikersflow en de koppelingen naar buiten op Acceptatie | scenario 4 |
| De site: per deelsysteem en per grens een pagina | later; hier één pagina, zie 1.7 |
| Async, SOAP, derde deelsysteem | scenario 6 en 7 |
| Angular UI | scenario 8 |
| Publicatie vanuit een pipeline | hier handmatig; O5 |
| Monitoring op Productie (F4) | vereist een productielaag; O8 |
| Pipeline 6, naar Productie | beschreven in 1.4, niet gebouwd: een vierde omgeving op een laptop toont hetzelfde als Acceptatie zonder de koppelingen |

---

### 1.13 Besluiten en openstaande punten

**Besloten.** De naamgeving van de testlagen volgt één begrippenlijst en wijkt daar nergens van af; waar dit document "contractverificatie" schrijft, geldt die term consequent in scriptnamen, JUnit-tags en pipeline-uitvoer. Betekenisvolle `example`-waarden zijn een norm voor elke spec: zonder example faalt de stubgeneratie (zie 1.6).

**Dit document is de spec en de code de implementatie** (O12, gesloten). Wat hier staat gaat vooruit op wat er gebouwd wordt, en loopt de bouw ergens tegen iets aan, dan gaat dat eerst terug hierheen — niet stilzwijgend het andere pad op. Dat is dezelfde regel die de showcase op contracten toepast: schema-first, en een drift-check die afdwingt dat de belofte en de werkelijkheid niet uit elkaar lopen.

`docs/besluiten.md` is daarmee ook de driftlog: elke gedateerde afweging is een moment waarop de bouw het ontwerp weersprak en het ontwerp is bijgesteld.

De stub wordt zelf gegenereerd en draait op WireMock (O7, gesloten). Prism van Stoplight is geprobeerd en doet padtemplates, `example`-waarden en requestvalidatie native, maar kan geen response kiezen op basis van de requestinhoud — en dat heeft het scenario uit 1.2 nodig. De reden staat in 1.6.

De **versieconformiteitscheck vergelijkt de omgeving met zichzelf** (O2, gesloten). Er is geen verwachte samenstelling omdat er geen bedoelde combinatie bestaat: elk deelsysteem schuift op zijn eigen tempo op. De check stelt vast dat elke pin op de omgeving daar ook geserveerd wordt; zie 1.7.

De **waarden** van `code` in het `Error`-schema zijn geen onderdeel van het contract. Het schema legt vast dat er een `code` en een `message` zijn; welke codes voorkomen niet. Een consumer reageert op de HTTP-status, niet op een codestring — anders wordt elke nieuwe foutsituatie bij de provider een contractwijziging. De implementatie gebruikt daardoor ook codes die niet in de spec als voorbeeld staan, zoals `INVALID_REQUEST` bij een niet-gedeclareerd veld.

| # | Openstaand punt |
|---|---|
| O3 | Eigenaarschap: wie bewaakt de versieconformiteit en wie voert de rollback uit |
| O4 | Version state voor deprecated versies in Apicurio 3.x — naamgeving verifiëren |
| O5 | Eigenaarschap van de spec: in de provider-repo of in een aparte spec-repo met review door de architect. Technisch afgedekt via het aansluitpunt in 1.9; dit is een vraag voor de werkwijze, niet voor deze showcase |
| O8 | Pins op info-endpoints als surrogaat voor monitoring (F4): tijdelijk voor de showcase of blijvend naast monitoring |
| O9 | Welke micro-frontend scenario 8 uitwerkt. Order ligt voor de hand — een gebruiker plaatst een bestelling — maar Payment is het centrale deelsysteem en heeft de interessantere spec. Alle drie bestaan hoe dan ook, want scenario 9 heeft meerdere remotes nodig |
| O10 | Wat de micro-frontend van Notification laat zien. Scenario 6 gaat over de async grens en heeft geen UI nodig; scenario 9 heeft hem wel nodig, want één remote maakt geen shell-grens. Zijn inhoud is daarmee nog nergens belegd |
| O13 | **De diff-gate werkt niet op AsyncAPI.** oasdiff leest OpenAPI en niets anders, dus voor `run-stream` valt de gate uit 1.9 weg. Bij 0.9.0 merk je dat niet — er is niets om mee te vergelijken — maar bij de eerste wijziging wel. Tot dat moment leunt die grens op de compatibility rule van het register alleen, en dat is één net in plaats van twee. Op te lossen in scenario 6, dat toch een AsyncAPI-grens uitwerkt; te overwegen valt een tweede vergelijker naast oasdiff of de gate expliciet als niet-van-toepassing markeren in plaats van hem stil over te slaan |
| O14 | **De repo-indeling is ontworpen voor één product, en er staan er twee in.** Het ordenende principe is er wel en het is consistent: wat gedeeld is staat één keer op de hoofdmap, services staan in `deelsystemen/`, genummerde mappen bevatten alleen tests. Dat principe ordent langs **wat iets is** — script, service, test, spec — en is nooit ontworpen om te ordenen langs **voor wie iets is**. Toen de realisatie erbij kwam (`scenario-api`, `run-stream`, de stubbundel, `controle.sh`) is die vraag niet gesteld, en staat Deel B nu op de plek die zijn soort aanwijst en niet zijn bestemming: contracten bij de contracten, scripts bij de scripts. Voor het meeste is dat juist — het gereedschap ís gedeeld, en dat is de stelling van de showcase. Voor drie dingen niet: `controle.sh` heeft de geleefde grens hard in zich, `verify-contract.sh` heeft de modulepaden van de showcase hard in zich, en `ci/stubbundel/` is een levering en geen script. Te bepalen: (a) die twee scripts parametriseren, (b) de levering een eigen plek buiten `ci/` geven. Een splitsing in `showcase/` en `gereedschap/` is onderzocht en afgewezen: 26 scripts berekenen hun wortel als `dirname/..`, er zijn 133 padverwijzingen naar `ci/<script>`, en `ci/` in tweeën knippen zou de claim ondergraven dat het mechanisme er één is. Wat níét met verplaatsen op te lossen was, is het versieprobleem waar dit punt mee begon: één repository-tag dekt beide producten. Dat is opgelost met een eigen tagreeks per contract, niet met mappen — zie `besluiten.md`, 2026-08-13. Geparkeerd op 2026-08-07, herzien op 2026-08-13 |
| O15 | **De demo's van scenario 0 en 1 draaien nergens automatisch.** Van de 28 scripts in `ci/` en de demomappen draaien er 10 mee bij elke push; de andere 18 vragen gebouwde images, gedeployde containers of een omgeving en worden alleen gedraaid als iemand een demo start. Voor die 18 is de enige verificatie dat een mens kijkt. Dat is geen theoretisch gat: het hield een exitcode 127 in `vergelijk-rapporten.sh` maandenlang onzichtbaar — het script wérd aangeroepen, alleen door een demo, en een demo draait niet in CI. De pipelines uit 1.4 hangen daarmee aan een demoscript in plaats van aan een CI-platform. Oplossen betekent Maven, `docker build`, deploys en Playwright bij elke push, en dat vraagt een eigen afweging over wat een push mag kosten — laptopbudget is een ontwerpeis. Tot die tijd staan de 18 met reden en herzieningsdatum in `vrijstelling_uitvoering` in `ci/controle-gates.sh`. De afweging staat in `besluiten.md`, 2026-08-13. **Het geval, om de herzieningsdatum niet abstract te laten worden:** `verify-contract.sh` staat op die lijst omdat hij een gedeployd deelsysteem vraagt — een terechte reden. Op 2026-08-14 bleek dat commit `5975384` er weken eerder een stille beëindiging in had gezet: de consumerverificatie viel om terwijl de test zelf groen was, en de providerkant ontsnapte alleen doordat zijn testgereedschap een ander woord in de uitvoer gebruikt. Scenario 01 draaide daardoor half. Gevonden bij een handmatige doorloop, niet door een gate — want het enige dat dit script draait is de demo, en die draait niet in CI |

---

## 2. Wijziging zonder breuk

> Vereist scenario 1. Nog niet uitgewerkt.

Scenario A uit de contractlevenscyclus, plus het governance-scenario: technisch dezelfde beweging, andere aanleiding. Additief blijft additief, ongeacht wie erom vroeg.

| | |
|---|---|
| Wijziging | `paymentMethod` optioneel toevoegen → v1.1.0 |
| Register | v1.1.0 naast v1.0.0 |
| Provider | verifieert tegen v1.1.0 |
| Consumer | ongewijzigd, pin blijft op v1.0.0 |
| Klaar als | de publicatie geslaagd is; de consumer hoeft niets |

**Wat hier structureel nieuw is:** de diff-gate heeft voor het eerst iets te vergelijken. In scenario 1 draait hij tegen een leeg register.

**Demo:** publiceer v1.1.0, draai daarna Order's pipeline ongewijzigd. Groen, op v1.0.0, zonder dat iemand iets heeft aangeraakt. Draai daarna het tegenvoorbeeld onder hetzelfde minor-nummer: `merchantId` verplicht toevoegen. De gate weigert (`new-required-request-property`), en het register weigert als tweede net. De demo zet de twee naast elkaar: één veld erbij is veilig of breaking afhankelijk van één woord, en dat verschil is precies waar de gate voor bestaat.

**Governance-variant:** de consumer opent een verzoek op de spec, de provider besluit en publiceert. Dat de provider besluit, is de grens met consumer-driven. Er verandert niets aan de pipelines.

---

## 3. Breaking wijziging

> Vereist scenario 1. Nog niet uitgewerkt.

Scenario B. Een grens breekt niet: een breuk wordt een nieuwe major náást de bestaande, met een deprecation-termijn die bij publicatie wordt vastgelegd.

| | |
|---|---|
| Wijziging | `amount` wordt een object met `value` en `currency`; `currency` verdwijnt uit de root → v2.0.0 |
| Register | v2.0.0 naast v1.x |
| Provider | serveert `/v1/` en `/v2/`, verifieert tegen **beide** majors |
| Consumer | ongewijzigd tot hij zelf migreert |
| Klaar als | alle pins van v1 af zijn |

**Wat hier structureel nieuw is:** `get-contract` en de contractverificatie draaien per major. Zonder dat blijft v1 wel geserveerd maar niet meer getoetst, en verrot hij stilzwijgend terwijl er nog consumers op zitten.

**Demo:** dien de wijziging in onder v1.2.0 — de gate weigert. Dien hem in als v2.0.0 — de publicatie slaagt. Payment's pipeline toont twee contractverificaties, één per major. Order blijft op v1 en draait groen.

---

## 4. Acceptatie

> Vereist scenario 1. Nog niet uitgewerkt.

| | |
|---|---|
| Toevoeging | de e2e gebruikersflow over de keten, op Acceptatie |
| Onderscheid | de enige omgeving mét koppelingen naar buiten; op Test staan externe partijen als stub |
| Vraag | doet de keten wat een gebruiker verwacht |

Contractverificatie dekt de structuur van een grens: velden, typen, statuscodes, foutmodellen. Wat het niet dekt is betekenis — een veld dat blijft bestaan maar iets anders gaat betekenen, of een uitkomst die per deelsysteem klopt en samen toch niet. Dat is de residue waarvoor de gebruikersflow bestaat.

Dit scenario is daarmee het tegenwicht bij de rest van de showcase. Contractverificatie maakt ketentesten niet overbodig; het maakt ze **kleiner en gerichter**, omdat de structuur elders al is aangetoond en de flow zich kan beperken tot wat een gebruiker daadwerkelijk doet.

**Demo:** één volledige gebruikersflow over Order en Payment op Acceptatie — bestelling plaatsen, betaling geaccepteerd, bevestiging zichtbaar — en daarnaast de constatering dat deze suite één scenario telt in plaats van tien, omdat de grens al is aangetoond in scenario 1.

---

## 5. Sunset

> Vereist scenario 3. Nog niet uitgewerkt.

| | |
|---|---|
| Toevoeging | einde van de levenscyclus: deprecation, laatste consumer van een major af, route uit de runtime |
| Testfeature | F4, monitoring op productie |

Het contract wordt niet verwijderd — het register is immutable. Wat verdwijnt is dat de provider de oude major nog serveert; de versie krijgt in het register de bijbehorende state.

**Dit is het enige scenario dat Build principieel niet kan zien.** De consumer haalt v1 uit het register, die bestaat nog, genereert zijn stub en draait groen, terwijl niemand v1 meer serveert. *Wordt deze versie nog geserveerd* is geen eigenschap van een spec maar van een omgeving.

**Demo — de sluitsteen van de showcase:** haal v1 uit de runtime terwijl Order er nog op gepind staat. Order's pipeline draait volledig groen; de versieconformiteitscheck op Test wordt rood en noemt de consumer die nog op v1 zit. Een groene pipeline naast een rode omgeving toont in één beeld waar de grens van schemagebaseerd testen ligt.

> **Afwijking.** Normaal volgt sunset pas als monitoring op productie nul verkeer aantoont (F4). De showcase heeft geen productielaag; de pins op de info-endpoints zijn een surrogaat binnen de showcase, geen alternatief voor die monitoring (O8).

**Governance:** de deprecation-termijn wordt vastgelegd op het moment dat de nieuwe major wordt gepubliceerd, niet als de oude lastig begint te worden.

---

## 6. Async

> Vereist `ci/` en `deelsystemen/payment/`. Nog niet uitgewerkt.

| | |
|---|---|
| Grens | Payment → Notification, queue of topic |
| Contract | AsyncAPI |
| Toevoeging | geen response: provider-verificatie wordt *valideer wat ik publiceer*, consumer-verificatie *valideer wat ik consumeer*; de stub is een producer in plaats van een antwoordende server |
| Valkuil | verificatie beperken tot het emitteren van een bericht, waarmee de consumerkant onbewezen blijft |
| Testfeature | F5, async grenzen |

De kleinste stap van de drie grenstypen: Apicurio is van origine een schema registry.

---

## 7. SOAP

> Vereist `ci/` en `deelsystemen/payment/`. Nog niet uitgewerkt.

| | |
|---|---|
| Grens | Payment → externe betaalprovider |
| Contract | WSDL/XSD, niet in eigen bezit |
| Toevoeging | publiceren vervalt: de externe partij levert het contract en de organisatie pint erop. De diff-gate draait op wijzigingen van een ander, versiebeheer is onderhandeling in plaats van beleid, een deprecation-termijn is niet af te dwingen |
| Valkuil | pinnen zonder route waarlangs wijzigingen van de externe partij binnenkomen |
| Testfeature | F6, externe grenzen |

Dit is het antwoord op de vraag of contracttesten ook buiten de eigen organisatie werkt.

---

## 8. Frontend binnen een deelsysteem

> Vereist `ci/` en het eigen deelsysteem. Nog niet uitgewerkt.

| | |
|---|---|
| Grens | **geen** — Angular en backend zijn van hetzelfde team, er wisselt geen eigenaarschap |
| Plaats | `deelsystemen/<naam>/<naam>-mf/`, naast de backend van hetzelfde deelsysteem |
| Contract | de eigen OpenAPI van het deelsysteem; publicatie in het register is hier optioneel |
| Toevoeging | de frontend als consumer: pinnen, stub genereren, schemavalidatie in de browser; dit is de plek voor Playwright en ajv |
| Status | teamkeuze, geen gezamenlijk kader — afspraken gelden op grenzen, niet op de binnenkant |

Deze showcase toont aan dat hetzelfde mechanisme bruikbaar is binnen een deelsysteem, met een uitdrukkelijk andere boodschap dan de rest van de showcase: het mag, het werkt, en het wordt niet voorgeschreven. Hij levert ook de UI die scenario 1 bewust niet heeft.

De frontend is een service van een deelsysteem en staat dus in `deelsystemen/`, niet in de scenariomap; `08-frontend-binnenkant/` bevat alleen de tests eromheen. Wélk deelsysteem de UI krijgt, is nog niet besloten (O9).

---

## 9. Frontend in shell

> Eigen model. Wordt pas gebouwd als de andere scenario's staan; de opzet wijkt te veel af om er nu aan te beginnen.

| | |
|---|---|
| Grens | shell ↔ remote: een ander team levert de remote |
| Plaats | de shell is een service van het deelsysteem Portal: `deelsystemen/portal/portal-shell/`. De remotes zijn de micro-frontends van de andere deelsystemen en blijven daar ook staan: de shell stelt samen, hij bezit niet |
| Contract | exposed module-API: componenten, props, events |
| Toevoeging | het contract is geen spec: versiebeheer loopt via een package in plaats van het register, en verificatie is deels een typecheck in plaats van runtime-validatie |
| Open vraag | schemavalidatie in de browser op Test: het enige dat een contractafwijking bij de echte buur zichtbaar maakt |
| Testfeature | frontend-grens |

---

## Bijlage A — Acceptatie is een concessie, geen ontwerpkeuze

Er is één ding dat telt en dat is productie. Elke omgeving daarvoor is een plaatsvervanger: hij kost doorlooptijd, hij loopt uit de pas met productie, en hij geeft een zekerheid die alleen productie echt kan geven. Twee omgevingen is al een keuze die verantwoording vraagt; drie vraagt een goed verhaal.

Acceptatie staat in deze showcase omdat er behoefte is aan een stabiele plek om de gebruikersflow te doorlopen, en omdat het vertrouwen dat die flow ook automatisch en gepland kan draaien er nog niet is. Dat is een organisatorische stand van zaken, geen technische noodzaak.

De showcase neemt hem daarom op zoals hij is, en laat tegelijk zien wat hem overbodig zou maken. **Scenario 4 draait de gebruikersflow geautomatiseerd** — dat is precies de reden dat Acceptatie bestaat, en meteen het bewijs dat het gepland kan. **Scenario 7 legt de externe grens onder een contract** — dat is de tweede reden, en die valt daarmee grotendeels weg. Wie beide heeft staan, houdt van de technische onderbouwing van een derde omgeving weinig over.

Wat er dan overblijft is niet-technisch: mensen willen er met eigen ogen naar kijken voordat het naar buiten gaat. Dat is vertrouwen en geen bewijs, en dat argumenteer je niet weg met gereedschap. Wie doet alsof dat hetzelfde probleem is, verliest het gesprek.

**Dit spreekt de eigenaarschapsgrens uit 1.3 niet tegen.** Er is een echte technische knip tussen "alles wat ik bezit is er" en "alles is er": externe partijen zijn niet te resetten en niet af te dwingen, en dat hoort niet in Test. Wat een concessie is, is de vorm — een blijvende omgeving waar mensen met eigen ogen naar kijken voordat het naar buiten gaat. De knip blijft; de vraag is of hij een derde omgeving met vaste bewoners hoeft te zijn.

Deze bijlage staat er niet om een omgeving af te schaffen, maar om te voorkomen dat hij onbesproken blijft. Een concessie die niemand benoemt, wordt vanzelf een uitgangspunt.

