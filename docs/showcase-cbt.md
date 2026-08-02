# Showcase CBT

Versie 0.6.8

Dit is een werkdocument: elke wijziging is een patchbump, zodat er altijd naar een vorige versie terug te vallen is. De aard van de wijziging staat in de wijzigingslog, niet in het versienummer.

Een showcase die contract-based testing aantoonbaar maakt. Het contexthoofdstuk beschrijft wat overal gelijk is; elk hoofdstuk daarna is los te lezen.

**Dit document beschrijft wat er is en waarom.** Twee andere bestanden in deze map dragen wat hier niet in past. `besluiten.md` bevat de afwegingen achter de keuzes: wat er is geprobeerd, wat eruit kwam, wat het kost en wanneer het herzien moet worden. `security.md` doet hetzelfde voor beveiligingsbevindingen. Beide zijn gedateerd, want een afweging is houdbaar zolang de omstandigheden gelijk blijven en niet langer. Wie zich bij een keuze hieronder afvraagt *waarom dan*, vindt het antwoord daar.

---

## Context

### Contract-based testing in deze showcase

Een **grens** is elke interface waar eigenaarschap wisselt tussen deelsystemen — een organisatorisch criterium, geen technisch. Contract-based testing toetst beide kanten van zo'n grens aan één gepubliceerde specificatie, in de bouwstraat, zonder dat de deelsystemen samen hoeven te draaien.

Het contracttesten is hier **provider-driven en spec-first**: de provider bezit en publiceert het contract, en zowel provider als consumer verifiëren hun eigen conformiteit daaraan. Er is gekozen voor open source en dus geen commercieel platform om contracten uit te wisselen of te vergelijken.

Dat is een andere invulling dan **consumer-driven contracts** met Pact, en die vergelijking is de eerste die een lezer maakt. Twee verschillen zijn hier bepalend.

Bij consumer-driven contracts legt elke consumer zijn verwachting vast als apart artefact naast de specificatie. Dat werkt, en het werkt vooral goed wanneer de consumers bekend zijn en binnen dezelfde organisatie zitten. De prijs is dat er twee bronnen ontstaan die uit elkaar kunnen lopen, met de vraag welke van de twee wint bij afwijking. Deze showcase kiest voor één bron: de gepubliceerde specificatie. Dat is geen oordeel over de geschiktheid van consumer-driven contracts, maar een andere afweging over waar de waarheid ligt.

Het **bidirectionele** model — waarin een providerspecificatie en consumerverwachtingen automatisch tegen elkaar worden gehouden — lost dat probleem grotendeels op, maar zit in een commercieel platform. Pact zelf is open source; die functionaliteit is dat niet. Voor een showcase die iedereen zonder licentie moet kunnen draaien, valt hij daarmee af.

Wat overblijft is een opzet van losse open-source-onderdelen: een registry voor de contracten, een diff-tool voor compatibiliteit, en validators aan beide kanten van de grens.

Wat de showcase aantoont is één ding: **hetzelfde mechanisme werkt over vier contractvormen** — REST, async, SOAP en een frontend-grens — en over de volledige levenscyclus van een contract, van eerste publicatie tot het uitfaseren van een oude versie.

### Waarom deze showcase

Contract-based testing laat zich slecht uitleggen en goed laten zien. Deze showcase is daarvoor gemaakt: een werkend voorbeeld per grenstype, draaiend op één laptop, om het mechanisme te tonen in plaats van te beschrijven. Elk hoofdstuk behandelt één testfeature en werkt op zichzelf.

**Eigenaarschap.** Deze showcase en de bijbehorende repository zijn in eigen tijd gebouwd, staan onder eigen naam en zijn vrij te gebruiken door iedereen. Het systeem is fictief.

**Het is een demonstratie, geen levering.** Wie zo wil gaan testen, richt dat zelf in, in eigen deelsystemen en eigen pipelines. Deze showcase laat zien wat er bedoeld wordt en is niet bedoeld om als code te worden overgenomen. Dat een map bruikbaar is als startpunt, is een prettig gevolg en geen belofte.

De showcase is tot stand gekomen in samenwerking met Claude en gebouwd met Claude Code.

Daaruit volgt waar "af" ligt: een hoofdstuk is klaar zodra het argument overkomt, niet zodra hij de kwaliteit heeft die van productiecode verwacht zou worden.

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

De showcase loopt langs drie assen. Een deel varieert het **grenstype**: hetzelfde mechanisme, een ander contractformaat. Hoofdstuk 2, 3 en 5 variëren de **levenscyclus**: dezelfde grens, een later moment in het leven van een contract. Hoofdstuk 4 varieert de **testsoort**: dezelfde grens, een andere vraag. Hoofdstuk 8 gaat over de **binnenkant** van een deelsysteem en is daarmee het enige dat geen grens beschrijft.

| # | Hoofdstuk | As | Onderwerp | Vereist |
|---|---|---|---|---|
| 1 | CBT basis (API) | grenstype | Order → Payment, REST sync, OpenAPI | — |
| 2 | Wijziging zonder breuk | levenscyclus | additieve wijziging, v1.1.0 | 1 |
| 3 | Breaking wijziging | levenscyclus | twee majors serveren en verifiëren, v2.0.0 | 1 |
| 4 | Acceptatie | testsoort | e2e gebruikersflow over de keten | 1 |
| 5 | Sunset | levenscyclus | oude major uit de runtime | 3 |
| 6 | Async | grenstype | Payment → Notification, AsyncAPI | `ci/` en `deelsystemen/payment/` |
| 7 | SOAP | grenstype | externe betaalprovider, WSDL/XSD | `ci/` en `deelsystemen/payment/` |
| 8 | Frontend binnen een deelsysteem | binnenkant | Angular → eigen backend | `ci/` en het eigen deelsysteem |
| 9 | Frontend in shell | grenstype | shell ↔ remote, module-API | eigen model |

Hoofdstuk 1 tot en met 5 gebruiken dezelfde grens: het is één basis waar de contractlevenscyclus overheen loopt, geen vijf basissen. Hoofdstuk 1 tot en met 5 dekken de testfeatures F2 (een REST-grens), F3 (versiecontrole bij deployment) en F4 (monitoring op productie); 6 en 7 dekken F5 (async) en F6 (SOAP), en 9 gaat over een frontend-grens. Hoofdstuk 8 heeft bewust geen testfeature: de kaders gelden op grenzen, niet op de binnenkant.

**De showcase is een boom, geen rij.** De kolom *Vereist* zegt wat er af moet zijn, en dat is niet altijd een hoofdstuk: 6 en 7 hebben `ci/` en het deelsysteem Payment nodig, maar niets uit de tests van hoofdstuk 1. Dat services op de hoofdmap staan in plaats van in een hoofdstukmap, maakt zo'n afhankelijkheid pas benoembaar. De nummering is vlak gehouden omdat 1.2 in dit document al een subparagraaf aanduidt.

**De volgorde is de bouwvolgorde.** Hoofdstuk 1 draagt ruwweg de helft van al het bouwwerk; 2 tot en met 5 zijn er kleine uitbreidingen op en maken het verhaal compleet tot het einde van de contractlevenscyclus. Pas daarna wordt het contractformaat gevarieerd. De frontend staat achteraan omdat hij het model oprekt en een nog openstaande keuze raakt.

### De repository

| | |
|---|---|
| Naam | `showcase-cbt` — het voorvoegsel zegt bij de eerste blik dat dit geen productiecode is |
| Plaats | GitHub, publiek, persoonlijk account; in eigen tijd gebouwd |
| Licentie | MIT: vrij te gebruiken, zonder garantie en zonder aansprakelijkheid |
| Gebruiksmodel | referentie om te bekijken en te draaien; fork of template voor wie er zelf mee wil spelen |

**Eén repository.** Niet negen repositories: dan ontstaan negen kopieën van dezelfde scripts die uit elkaar lopen, en toont de showcase onbedoeld aan dat het niet standaardiseerbaar is. Binnen die ene repository staat wat gedeeld is op de hoofdmap en heeft elk hoofdstuk daarnaast een eigen genummerde map.

```
showcase-cbt/
├── README.md
├── LICENSE
├── ci/                       gedeelde scripts, één exemplaar
├── contracts/                alle specs, per grens en versie
├── compose/registry.yml      Apicurio, gedeeld
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

Twee regels dragen deze indeling. **Wat gedeeld is, staat op de hoofdmap en bestaat één keer**: `ci/`, `contracts/`, `playwright/` en `deelsystemen/`. Zodra een hoofdstuk een eigen kopie van `get-contract.sh` of van Payment krijgt, is de claim dat het mechanisme uniform is niet meer waar. En **de genummerde mappen bevatten geen services, maar tests**: een compose die de juiste deelsystemen samenstelt, een demoscript, hoofdstukspecifieke specs en een README die het argument uitlegt.

Dat een deelsysteem niet in een hoofdstukmap thuishoort, volgt uit de showcase zelf: hoofdstuk 6 breidt Payment uit met een uitgaande grens naar Notification, en hoofdstuk 8 hangt er een frontend aan. Payment groeit dus mee met meerdere hoofdstukken en kan niet van één ervan zijn. De nummering hoort bij de tests, niet bij de code die getest wordt.

**Een deelsysteem bestaat uit services.** De deelsysteemmap is daarom een houder en zelf geen service: elke microservice en elke micro-frontend staat eronder als eigen service, met een eigen build en een eigen image. Payment wordt zo `deelsystemen/payment/payment-api/`, met `payment-mf/` ernaast in plaats van in `08-frontend-binnenkant/`. Dat is dezelfde regel een niveau dieper: een service hoort bij het deelsysteem dat hem bezit, niet bij het hoofdstuk dat hem toevallig als eerste nodig heeft. Elk deelsysteem met een gezicht naar de gebruiker heeft een eigen micro-frontend: `order-mf`, `payment-mf`, `notification-mf`. Welke daarvan hoofdstuk 8 uitwerkt, is een andere vraag (O9).

**De portal stelt samen, hij bezit niet.** De shell laadt die micro-frontends op de pagina, maar hun broncode blijft bij het deelsysteem dat ze bezit. Zou `payment-mf` onder `deelsystemen/portal/` staan, dan wisselt er bij shell ↔ remote geen eigenaarschap meer en heeft hoofdstuk 9 geen grens meer om te tonen. Samenstellen op runtime en bezitten in de repository zijn hier twee verschillende dingen — en dat verschil is nu juist wat een frontend-grens tot een grens maakt.

Er zijn vier deelsystemen. Order en Payment dragen de grens uit hoofdstuk 1. Notification komt erbij in hoofdstuk 6 — Payment → Notification is een grens, dus wisselt daar eigenaarschap, en dan is Notification geen service van Payment maar een deelsysteem naast Payment. Portal komt erbij in hoofdstuk 9, met de shell erin: die wordt door een ander team geleverd dan de remotes die erin hangen, en dat is precies wat die grens interessant maakt.

Losstaand te draaien is daarmee elke genummerde map, mits de deelsystemen die hij samenstelt gebouwd zijn.

**Testgereedschap wordt hergebruikt, niet per hoofdstuk opnieuw ingericht.** Playwright staat op de hoofdmap in `playwright/` — niet onder een naam als `e2e`, want hij bedient meerdere lagen. Eén smoke-spec wordt op een base-URL geparametriseerd, met `ci/smoke.sh <base-url>` als enige aanroeppunt. Hij draait op Test en toont dat de keten loopt. Op de CI-omgeving draait geen smoke maar de volledige contractverificatie, en op Acceptatie de gebruikersflow; de drie lagen doen elk hun eigen werk en herhalen elkaar niet. Playwright is in dit soort omgevingen doorgaans al in gebruik voor de e2e van een deelsysteem; de showcase sluit daarop aan in plaats van er een tweede werkwijze naast te zetten. Showcasespecifieke specs — bijvoorbeeld die van de UI in hoofdstuk 8 — staan in de hoofdstukmap zelf.

**De smoke gaat niet over inhoud.** De gedeelde smoke-spec assert uitsluitend op HTTP-status en op het doorlopen van de keten — geen veldwaarden, geen businessregels. Anders draait hij groen tegen de stub en rood tegen de echte buur om een reden die niets met de grens te maken heeft, en verhuist bovendien werk van een goedkope laag naar een dure.

**Laptopbudget is een ontwerpeis.** Alles draait naast een IDE tijdens een presentatie. Daarom is elke showcase los op te starten en is er geen enkel moment waarop alles tegelijk nodig is: registry plus één showcase is de maximale opstelling. Wat daar niet in past, wordt vereenvoudigd in plaats van uitgebreid.

**Het document staat in de repository.** `docs/` bevat dit document; `CLAUDE.md` op de hoofdmap verwijst ernaar en herhaalt de regels die niet overtreden mogen worden. Een showcase zonder het waarom is een hoop code zonder argument.

**Veilige code en schone dependencies.** Zo min mogelijk libraries: elke dependency is een toekomstige kwetsbaarheid, en bij deze functionaliteit zijn er weinig nodig. Per toegevoegde library staat in de commit waarom hij nodig is. Verder: geen secrets in code, yaml of compose — alles uit environment met een `.env.example` in de repository; Actuator stelt uitsluitend `health` en `info` bloot en nooit een wildcard; foutresponses volgen het `Error`-schema uit het contract en bevatten geen stacktrace of interne paden; XML-parsers hebben externe entiteiten en DTD's uitgeschakeld; images staan op een vastgepinde tag en containers draaien als non-root; scripts gebruiken `set -euo pipefail` en geven nooit credentials op de commandoregel. Dependabot staat aan, zodat de showcase niet stilletjes veroudert tussen twee demo's door.

**Vereenvoudigingen worden benoemd.** Een register zonder authenticatie en opslag in memory zijn prima keuzes voor een demo, maar iemand die de showcase leest, moet zien dát het vereenvoudigingen zijn. Elke bewuste versimpeling krijgt een commentaarregel op de plek zelf en staat verzameld in de README. Zonder dat lever je onbedoeld een blauwdruk met gaten erin.

**Draaien.** Docker en een shell zijn de enige vereisten; op Windows via WSL2, niet via Git Bash. Extern gereedschap zoals oasdiff draait als container achter een functie in `ci/lib/tools.sh`, zodat de versie op een laptop en op een runner identiek is.

**CI.** Er zijn twee wrappers — GitLab CI en GitHub Actions — die uitsluitend `ci/pipeline-provider.sh` en `ci/pipeline-consumer.sh` aanroepen. Geen stap of conditie mag in één van de twee bestanden staan en in het andere niet. De standaard zit in de scripts, niet in het CI-platform; dat is ook het argument voor een team dat ooit naar een ander platform migreert.

---

### Wat overal gelijk is

Dit is de standaard. Wijkt een hoofdstuk hiervan af, dan is dat een bevinding en geen variant.

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
| Scenario's | de contractlevenscyclus uit hoofdstuk 2 tot en met 5 geldt voor elke grens |

### Het fictieve systeem en het contract

De hele showcase gebruikt hetzelfde fictieve systeem: **Order → Payment → Notification**, met Payment als centraal deelsysteem. Hoofdstuk 1 gebruikt de grens Order → Payment.

**Naamgeving in het register:** groep `order-payment` (de grens), artifact `payment-api` (de spec).

**Versie in het pad.** De provider moet bij een major twee versies naast elkaar serveren. Een padprefix maakt dat zichtbaar — in een demo zie je letterlijk twee routes draaien — waar een versieheader onzichtbaar blijft.

Dit is de spec zoals hij als v1.0.0 wordt gepubliceerd. Hij is hier met de hand ontworpen en wordt ongewijzigd overgenomen in `contracts/order-payment/v1.0.0/openapi.yaml`; het bestand in de repository is de werkkopie, deze tekst de herkomst.

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

De implementatie houdt dezelfde regels aan en accepteert niet meer dan hij belooft. Zou Payment elke ISO 4217-code aannemen terwijl de spec er drie noemt, dan is de spec een onwaarheid over wat er gebeurt en weet een consumer die erop afgaat minder dan hij denkt. Dat die twee met de hand gelijk blijven, is precies waarvoor de drift-check bestaat.

**Wat er dan aan semantiek overblijft** is één ding: dat een bedrag boven 500,00 wordt afgewezen. En dat is geen invoercontrole maar een businessuitkomst — 201 met `DECLINED`, geen 400. Daarmee staat het onderscheid uit 1.2 er scherper: alles wat over de *geldigheid* van een verzoek gaat, staat in het contract; wat over de *uitkomst* gaat, niet.

> Dit is een correctie op de baseline en geen contractwijziging: v1.0.0 was nog niet uitgeleverd. Was hij dat wel geweest, dan was `pattern` toevoegen breaking geweest — de diff-gate meldt dat ook zo — en had het een major gekost. Een regel die je in het schema had kunnen zetten, is later duur om er alsnog in te krijgen.

---

### Leeswijzer

Elk hoofdstuk is los te lezen en volgt dezelfde indeling: waar de showcase over gaat, wat hij toevoegt ten opzichte van deze context, de opzet met uitsluitend de afwijkingen, de demo, en de openstaande punten.

Hoofdstuk 1 is de uitzondering: die schrijft de gedeelde opzet volledig uit en dient daarmee als referentie voor de andere acht.

Niemand leest negen hoofdstukken. Vijf leespaden:

| Vraag | Lees |
|---|---|
| Hoe werkt het mechanisme? | 1 |
| Hoe worden breaking changes gestopt? | 1 en 3 |
| Hoe verloopt de levenscyclus van een contract? | 1 tot en met 5 |
| Werkt dit ook buiten REST? | 1 en 6, of 1 en 7 |
| Geldt dit ook voor de frontend? | 8 voor binnen een deelsysteem, 1 en 9 voor de grens tussen shell en remote |

---

## 1. Basis (API)

Twee deelsystemen, één grens: Order (consumer) → Payment (provider), REST, spec-first, contract in Apicurio. Dit hoofdstuk is de referentie-implementatie: het beschrijft de opzet die de andere showcases alleen nog aanvullen.

> Hieronder staat wat er is en waarom. **Hoe je het draait** staat in `01-basis/README.md`.

### 1.1 Rationale

**Eén contract, twee kanten.** De provider bezit en publiceert het contract. Beide kanten verifiëren hun eigen conformiteit tegen diezelfde gepubliceerde spec. Geen consumer-expectations, geen n×m-verificatie, geen tweede contractstore.

**De contractversie is het synchronisatiepunt, niet de deployvolgorde.** Twee pipelines die elkaar nooit zien, komen via één contract tot hetzelfde oordeel. Daarom is er geen release train: compatibiliteit is vastgesteld op Build, niet afgestemd bij de deploy.

**Voorspellen is een verwachting, waarnemen is een feit.** Een `can-i-deploy`-vraag bevraagt vastgelegde verificatieresultaten en zegt daarmee dat de contracten zijn geverifieerd — niet dat het werkt. Configuratie, data en alles wat buiten het contract valt, ziet hij niet, en dat moet je alsnog met een correctie opvangen. Die capaciteit heb je dus hoe dan ook nodig. Daarom deployt hier één deelsysteem tegelijk en is een rode controle op de omgeving het signaal.

Dat werkt op één voorwaarde: de controles moeten de fout kunnen zien. De smoke gaat niet over inhoud en herkent geen verkeerde versiecombinatie — de versieconformiteitscheck doet dat, en die draagt daarmee deze keuze. Extra zekerheid is goedkoop: draai de controle nog een keer. Waarnemen mag je herhalen, een voorspelling wordt er niet beter van.

**Contract is geen testlaag maar een norm.** De piramide houdt drie lagen — unit, integratie, e2e. Wat verandert is niet de laag maar de bron van de waarheid: bij unit en integratie ligt de norm in de test, bij contractverificatie ligt hij buiten de test, in een artefact dat elders wordt beheerd. Contractverificatie is daarmee integratie: één deelsysteem, buren gestubd.

**Spec-first minimaliseert geen breuken maar verplaatst ze.** Een noodzakelijke breuk blijft noodzakelijk. Wat verandert is het moment: bij spec-first is de breuk een besluit vóórdat er code ligt, bij code-first een ontdekking als terugdraaien al duur is. De drift-check is wat die belofte afdwingt.

**Drie omgevingen, drie vragen.** In de CI-omgeving wordt aangetoond dat een deelsysteem volledig werkt zónder zijn buren. Op Test dat de samenstelling die op dat moment draait, klopt en loopt. Op Acceptatie dat de keten doet wat een gebruiker verwacht, mét de koppelingen naar buiten.

**Transparantie is een deel van het mechanisme, geen bijproduct.** De uitkomst van de controles is per deelsysteem zichtbaar op één dashboard, groen of rood. Zonder dat beeld is "waarnemen in plaats van voorspellen" een belofte die niemand kan controleren, en blijft rood staan omdat niemand hem ziet.

**Er zijn twee versies, en ze bewegen los van elkaar.** De contractversie is die van de grens: hij staat in het register, de provider bepaalt hem via de diff-gate, en hij beweegt alleen als de grens verandert. De serviceversie is die van het deelsysteem: hij komt uit de build en beweegt bij elke release. Payment kan naar serviceversie 1.4.0 zonder dat de contractversie meebeweegt — en dat is precies waarom Order niets merkt, want die pint op het contract en niet op de service.

De relatie is niet één-op-één. Vanaf hoofdstuk 3 serveert één serviceversie twee contractversies naast elkaar; aan de providerkant is het dus een verzameling. Aan de consumerkant blijft het één pin.

**Onveranderlijkheid geldt voor elk artefact, niet alleen voor contracten.** Eén build levert één versie op, en die image gaat ongewijzigd door alle omgevingen. Geen hertagging, geen `-rc`-achtervoegsel dat later verdwijnt: dan is wat je getest hebt niet meer hetzelfde artefact als wat je uitlevert. Release candidate is een status, geen naam. Zakt een versie, dan komt er een volgende — net als in het register, waar ook geen rollback bestaat maar alleen een nieuwe versie.

**Het register is de distributievorm, niet de randvoorwaarde.** De showcase gebruikt Apicurio omdat dat het eindbeeld is. Het contracttesten hangt er niet van af: een provider die zijn spec als getagd build-artefact publiceert en consumers die daarop pinnen, levert dezelfde verificatie op. Alleen `get-contract` verandert dan.

**Effort naar rato van risico.** Niet elk risico krijgt een test. Een risico wordt belegd bij de goedkoopste maatregel die het kan zien: een gate op een artefact, een controle op de omgeving, of menselijk ontwerpwerk.

---

### 1.2 Wat de deelsystemen doen

Het gedrag is bewust minimaal en volledig deterministisch: een demo mag niet afhangen van toeval of van de tijd.

**Payment** neemt een betaling aan, slaat hem op en geeft hem terug.

| Situatie | Uitkomst |
|---|---|
| `amount <= 0` | 400, `INVALID_AMOUNT` |
| onbekende valutacode | 400, `UNKNOWN_CURRENCY` |
| `amount > 500.00` | 201, `status: DECLINED` |
| overige | 201, `status: ACCEPTED` |
| GET op onbekend id | 404, `PAYMENT_NOT_FOUND` |

**Order** neemt een bestelling aan, roept Payment aan en verwerkt de uitkomst: `ACCEPTED` wordt `CONFIRMED`, `DECLINED` wordt `CANCELLED`. Order heeft een eigen minimale API (`POST /orders`, `GET /orders/{id}`) die geen grens is — daar wisselt geen eigenaarschap — en die dus niet in het register staat.

Beide deelsystemen gebruiken een eigen H2-database in memory, met een repository ertussen, zodat de integratielaag iets te integreren heeft. Er is geen gedeelde database.

**Het onderscheid tussen 400 en `DECLINED` is de kern van dit hoofdstuk.** Een ongeldig bedrag is een contractschending: het verzoek voldoet niet aan de specificatie, dus 400. Een afgewezen betaling is een geldig verzoek met een negatieve uitkomst: 201 met een status. Wie die twee door elkaar haalt, dwingt de consumer om businessuitkomsten uit HTTP-statuscodes af te leiden.

De drempel van 500,00 is willekeurig maar vast. Ze levert twee scenario's op die niet uit de specificatie volgen en daarom als scenario-mapping in de stub terechtkomen (zie 1.6).

---

### 1.3 Drie omgevingen

| | CI-omgeving | Test | Acceptatie |
|---|---|---|---|
| Samenstelling | het deelsysteem + `stub.yml` | alle deelsystemen | alle deelsystemen + `extern.yml` |
| Buren | WireMock-stub uit de spec | de echte deelsystemen | de echte deelsystemen |
| Buitenwereld | — | **geen** koppeling; externe partijen staan als stub | **wel** koppeling |
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

Wat per omgeving verschilt, staat niet in een tweede servicedefinitie maar in environment: welke versie er draait, en waar de buur te vinden is. De stub (`compose/stub.yml`) en de externe koppelingen (`compose/extern.yml`) komen erbij als losse bestanden, niet als variant van het deelsysteem zelf.

**Er is geen moment waarop alles tegelijk verhuist.** Elk deelsysteem schuift op zijn eigen tempo op en de gate is telkens de vorige omgeving die groen staat. Dat is randvoorwaarde 4 in de praktijk.

**Acceptatie is de enige omgeving met koppelingen naar buiten**, en dat is wat hem onderscheidt van Test. Op Test staat een externe partij als stub — voor hoofdstuk 7, waar de buur een externe betaalprovider is, betekent dat concreet dat "echte buren" geldt voor de eigen deelsystemen en niet daarbuiten. Waarom Acceptatie er überhaupt is, staat in bijlage A.

---

### 1.4 Pipeline Payment (provider)

| # | Stap | Laag | Tegen | Norm |
|---|---|---|---|---|
| 1 | build per service | — | code | — |
| 2 | unit (`-Dgroups=unit`) | unit | code | test |
| 3 | integratie (`-Dgroups=integratie`) | integratie | code + eigen DB | test |
| 4 | `get-contract v1` uit register | — | register | — |
| 5 | drift: runtime-spec vs gepubliceerde spec | geen | artefact | **spec** |
| 6 | docker build per service; image krijgt zijn eigen versie en een label met de contractversies die hij serveert | — | — | — |
| 7 | up: het deelsysteem, zonder stubs | — | draaiend | — |
| 8 | healthcheck | — | draaiend | — |
| 9 | contractverificatie (`-Dgroups=contract`) | integratie | **draaiend deelsysteem** | **spec** |

Payment heeft binnen deze scope geen buren; zijn CI-omgeving bevat daarom geen stubs.

**Stap 9 is volledig, niet een steekproef:** elke operatie uit de spec, elke responsecode, happy en unhappy, als regressie. Dat is de plek waar de diepte zit — daar staat het deelsysteem alleen, zijn de scenario's beheersbaar en is een run goedkoop. Wat op Test en Acceptatie draait, mag daardoor klein blijven.

**Twee stijlen, en de pipeline kiest.** De testgevallen komen uit de spec — gegenereerd — of ze zijn met de hand geschreven. De showcase houdt ze allebei, omdat het verschil ertoe doet en zichtbaar hoort te zijn.

| | Gegenereerd | Geschreven |
|---|---|---|
| Herkomst | uit de spec, geen code | met de hand, JUnit met tag `contract` |
| Dekking | wat het contract toestaat | wat de schrijver bedacht |
| Norm | de spec | de spec, via een validator — niet de verwachting in de test |
| Leesbaar | een rapport | testnamen naast unit en integratie |

De handgeschreven variant is niet de mindere: hij is leesbaar, staat in dezelfde toolchain en documenteert de paden die ertoe doen. Maar hij dekt per definitie wat iemand heeft bedacht. In hoofdstuk 1 vond de gegenereerde variant zes gebreken in een implementatie met vijftien groene tests — zie `besluiten.md`. Dat verschil is geen detail maar het argument om te genereren waar dat kan.

Voor unit en integratie speelt die keuze niet: daar ligt de norm in de test, en dan is met de hand schrijven het enige dat betekenis heeft.

**Waarom na de deploy en niet tegen de code.** Een contract is een belofte van een draaiend systeem. Configuratie, serialisatie en foutafhandeling in de echte container horen erbij, en die vallen buiten beeld als je alleen de broncode toetst. De prijs is een trager signaal dan een unittest; daarom staan unit en integratie eronder en vangen die af wat ze goedkoop kunnen vangen.

---

### 1.5 Pipeline Order (consumer)

| # | Stap | Laag | Tegen | Norm |
|---|---|---|---|---|
| 1 | build per service | — | code | — |
| 2 | unit (`-Dgroups=unit`) | unit | code | test |
| 3 | integratie (`-Dgroups=integratie`) | integratie | code + eigen DB | test |
| 4 | `get-contract <pin>` uit register | — | register | — |
| 5 | stub genereren + valideren | — | artefact | **spec** |
| 6 | docker build per service; image krijgt zijn eigen versie en een label met de contractversie waarop hij pint | — | — | — |
| 7 | up: het deelsysteem + `stub.yml`, geen Payment | — | draaiend | — |
| 8 | healthcheck | — | draaiend | — |
| 9 | contractverificatie (`-Dgroups=contract`) | integratie | **draaiend deelsysteem + stub** | **spec, beide richtingen** |

De consumer heeft geen drift-stap: hij bezit het contract niet, dus er valt aan zijn kant niets van af te wijken.

**Beide richtingen** betekent bij de consumer twee dingen tegelijk: wat Order naar de stub stuurt voldoet aan de spec, én wat Order doet met de responses die de stub uit die spec teruggeeft, klopt. De eerste richting is wat een provider-driven opzet toevoegt aan een gewone integratietest met een mock — die mock zou je zelf verzinnen, deze stub komt uit het contract.

Er is één stub, gegenereerd uit de spec uit het register, gevalideerd bij het maken en daarna gebruikt in stap 7 en 9. De mappings worden nooit gecommit.

---

### 1.6 Stubgeneratie

De stub wordt elke run opnieuw gegenereerd uit de spec uit het register en wordt nooit gecommit. Hij draait mee in de CI-omgeving, als de buur die daar niet staat.

Op Test en Acceptatie staan de eigen deelsystemen echt. Eén uitzondering: partijen buiten de organisatie draaien op Test als stub, want die omgeving heeft geen koppeling naar buiten. Dat raakt hoofdstuk 7 en verder niets in hoofdstuk 1.

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

Elk deelsysteem meldt op zijn info-endpoint **beide** versies: zijn eigen serviceversie, en de contractversies waar hij aan hangt — bij de provider de versies die hij serveert, bij de consumer zijn pin. Dat onderscheid moet zichtbaar zijn, anders leest niemand af of `1.1.0` over het deelsysteem of over de grens gaat. De versieconformiteitscheck kijkt naar de contractversies en vergelijkt die samenstelling met de verwachte.

Die check is niet zomaar een van de drie. Hij is degene die het afzien van een `can-i-deploy`-gate verdedigbaar maakt: de smoke gaat niet over inhoud en komt groen door een verkeerde versiecombinatie heen, de versieconformiteitscheck niet.

**Acceptatie — doet de keten wat een gebruiker verwacht?**

Dezelfde deelsystemen, dezelfde RC-versies, plus de koppelingen naar buiten. Eén volledige gebruikersflow; de structuur van de grenzen is al aangetoond op de CI-omgeving en hoeft hier niet nog eens.

**Transparantie.** De uitkomst per deelsysteem staat op één dashboard, groen of rood. Dat is geen rapportage achteraf maar onderdeel van het mechanisme: waarnemen in plaats van voorspellen werkt alleen als de waarneming zichtbaar is. Een rood vlak dat niemand ziet, is geen signaal.

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

Hiermee dekt dit hoofdstuk alle drie de detectiemomenten in de bouwstraat: breaking change op de schemawijziging, non-conforme provider-implementatie, non-conforme consumeraanroep. In hoofdstuk 1 heeft de gate nog niets te vergelijken — er is één versie. Vanaf hoofdstuk 2 doet hij werk.

De aanroep van `publish-contract` is een aansluitpunt, net als bij `get-contract`: hier handmatig, later vanuit een pipeline. Dat verandert wie het script start, niet wat het doet.

---

### 1.10 De contractlevenscyclus in overzicht

Hoofdstuk 1 kent één contractversie en dus geen wijziging. De vier scenario's die daarna komen, staan hier in overzicht; elk is uitgewerkt in een eigen hoofdstuk.

| Scenario | Wat er gebeurt | Risico | Gezien door | Hoofdstuk |
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

De basisdemo toont uitsluitend het mechanisme: contract uit het register, stub eruit gegenereerd, beide pipelines groen, Test omhoog. Dit is de demo die het mechanisme in één keer uitlegt; scenariomateriaal blijft er bewust buiten.

| # | Scène | Zichtbaar |
|---|---|---|
| 1 | Order's pipeline draait volledig groen terwijl Payment nergens draait | onafhankelijkheid van de consumer |
| 2 | Payment's pipeline draait groen, met de volledige contractverificatie op zijn CI-omgeving | conformiteit van de provider |
| 3 | Test omhoog, versieconformiteit, dashboard groen | welke contractversies samen draaien |
| 4 | smoke groen tegen de echte keten | de samenstelling loopt |

Scène 1 en 2 zijn in willekeurige volgorde te draaien; begin bewust met Payment, omdat het publiek verwacht dat de consumer als laatste moet.

De demo's uit hoofdstuk 2 tot en met 5 zijn scripts (`demo/<naam>.sh`), geen branches: een branch per scenario moet worden bijgewerkt bij elke wijziging in de basis. Elk script past de wijziging toe, draait de betrokken pipelines en eindigt met een reset naar de uitgangssituatie.

---

### 1.12 Bewust buiten dit hoofdstuk

| Onderdeel | Waar |
|---|---|
| Contractwijziging, breaking change, deprecation | hoofdstuk 2, 3 en 5 |
| De gebruikersflow en de koppelingen naar buiten op Acceptatie | hoofdstuk 4 |
| Het dashboard bouwen; hier alleen beschreven | hoofdstuk 4 of 5; zie O11 |
| Async, SOAP, derde deelsysteem | hoofdstuk 6 en 7 |
| Angular UI | hoofdstuk 8 |
| Publicatie vanuit een pipeline | hier handmatig; O5 |
| Monitoring op Productie (F4) | vereist een productielaag; O8 |

---

### 1.13 Besluiten en openstaande punten

**Besloten.** De naamgeving van de testlagen volgt één begrippenlijst en wijkt daar nergens van af; waar dit document "contractverificatie" schrijft, geldt die term consequent in scriptnamen, JUnit-tags en pipeline-uitvoer. Betekenisvolle `example`-waarden zijn een norm voor elke spec: zonder example faalt de stubgeneratie (zie 1.6).

De stub wordt zelf gegenereerd en draait op WireMock (O7, gesloten). Prism van Stoplight is geprobeerd en doet padtemplates, `example`-waarden en requestvalidatie native, maar kan geen response kiezen op basis van de requestinhoud — en dat heeft het scenario uit 1.2 nodig. De reden staat in 1.6.

De **waarden** van `code` in het `Error`-schema zijn geen onderdeel van het contract. Het schema legt vast dat er een `code` en een `message` zijn; welke codes voorkomen niet. Een consumer reageert op de HTTP-status, niet op een codestring — anders wordt elke nieuwe foutsituatie bij de provider een contractwijziging. De implementatie gebruikt daardoor ook codes die niet in de spec als voorbeeld staan, zoals `INVALID_REQUEST` bij een niet-gedeclareerd veld.

| # | Openstaand punt |
|---|---|
| O2 | Verwachte samenstelling voor de versieconformiteitscheck: bestand in de repo of afgeleid uit de pins van de deelnemende pipelines |
| O3 | Eigenaarschap: wie bewaakt de versieconformiteit en wie voert de rollback uit |
| O4 | Version state voor deprecated versies in Apicurio 3.x — naamgeving verifiëren |
| O5 | Eigenaarschap van de spec: in de provider-repo of in een aparte spec-repo met review door de architect. Technisch afgedekt via het aansluitpunt in 1.9; dit is een vraag voor de werkwijze, niet voor deze showcase |
| O8 | Pins op info-endpoints als surrogaat voor monitoring (F4): tijdelijk voor de showcase of blijvend naast monitoring |
| O9 | Welke micro-frontend hoofdstuk 8 uitwerkt. Order ligt voor de hand — een gebruiker plaatst een bestelling — maar Payment is het centrale deelsysteem en heeft de interessantere spec. Alle drie bestaan hoe dan ook, want hoofdstuk 9 heeft meerdere remotes nodig |
| O10 | Wat de micro-frontend van Notification laat zien. Hoofdstuk 6 gaat over de async grens en heeft geen UI nodig; hoofdstuk 9 heeft hem wel nodig, want één remote maakt geen shell-grens. Zijn inhoud is daarmee nog nergens belegd |
| O11 | Waar het dashboard uit 1.7 gebouwd wordt en waaruit hij zijn gegevens haalt. De info-endpoints leveren de contractversies (zie O8); health en de laatste smoke-uitslag komen ergens anders vandaan |
| O12 | Hoe wat tijdens het bouwen wordt gewijzigd of ontdekt, terugkomt in dit document. Nu gebeurt dat per geval en met de hand; het moet een vaste stap worden, anders loopt de showcase stilzwijgend voor op zijn eigen ontwerp |

---

## 2. Wijziging zonder breuk

> Vereist hoofdstuk 1. Nog niet uitgewerkt.

Scenario A uit de contractlevenscyclus, plus het governance-scenario: technisch dezelfde beweging, andere aanleiding. Additief blijft additief, ongeacht wie erom vroeg.

| | |
|---|---|
| Wijziging | `paymentMethod` optioneel toevoegen → v1.1.0 |
| Register | v1.1.0 naast v1.0.0 |
| Provider | verifieert tegen v1.1.0 |
| Consumer | ongewijzigd, pin blijft op v1.0.0 |
| Klaar als | de publicatie geslaagd is; de consumer hoeft niets |

**Wat hier structureel nieuw is:** de diff-gate heeft voor het eerst iets te vergelijken. In hoofdstuk 1 draait hij tegen een leeg register.

**Demo:** publiceer v1.1.0, draai daarna Order's pipeline ongewijzigd. Groen, op v1.0.0, zonder dat iemand iets heeft aangeraakt. Draai daarna het tegenvoorbeeld onder hetzelfde minor-nummer: `merchantId` verplicht toevoegen. De gate weigert (`new-required-request-property`), en het register weigert als tweede net. De demo zet de twee naast elkaar: één veld erbij is veilig of breaking afhankelijk van één woord, en dat verschil is precies waar de gate voor bestaat.

**Governance-variant:** de consumer opent een verzoek op de spec, de provider besluit en publiceert. Dat de provider besluit, is de grens met consumer-driven. Er verandert niets aan de pipelines.

---

## 3. Breaking wijziging

> Vereist hoofdstuk 1. Nog niet uitgewerkt.

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

> Vereist hoofdstuk 1. Nog niet uitgewerkt.

| | |
|---|---|
| Toevoeging | de e2e gebruikersflow over de keten, op Acceptatie |
| Onderscheid | de enige omgeving mét koppelingen naar buiten; op Test staan externe partijen als stub |
| Vraag | doet de keten wat een gebruiker verwacht |

Contractverificatie dekt de structuur van een grens: velden, typen, statuscodes, foutmodellen. Wat het niet dekt is betekenis — een veld dat blijft bestaan maar iets anders gaat betekenen, of een uitkomst die per deelsysteem klopt en samen toch niet. Dat is de residue waarvoor de gebruikersflow bestaat.

Dit hoofdstuk is daarmee het tegenwicht bij de rest van de showcase. Contractverificatie maakt ketentesten niet overbodig; het maakt ze **kleiner en gerichter**, omdat de structuur elders al is aangetoond en de flow zich kan beperken tot wat een gebruiker daadwerkelijk doet.

**Demo:** één volledige gebruikersflow over Order en Payment op Acceptatie — bestelling plaatsen, betaling geaccepteerd, bevestiging zichtbaar — en daarnaast de constatering dat deze suite één scenario telt in plaats van tien, omdat de grens al is aangetoond in hoofdstuk 1.

---

## 5. Sunset

> Vereist hoofdstuk 3. Nog niet uitgewerkt.

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

Deze showcase toont aan dat hetzelfde mechanisme bruikbaar is binnen een deelsysteem, met een uitdrukkelijk andere boodschap dan de rest van de showcase: het mag, het werkt, en het wordt niet voorgeschreven. Hij levert ook de UI die hoofdstuk 1 bewust niet heeft.

De frontend is een service van een deelsysteem en staat dus in `deelsystemen/`, niet in de hoofdstukmap; `08-frontend-binnenkant/` bevat alleen de tests eromheen. Wélk deelsysteem de UI krijgt, is nog niet besloten (O9).

---

## 9. Frontend in shell

> Eigen model. Wordt pas gebouwd als de andere hoofdstukken staan; de opzet wijkt te veel af om er nu aan te beginnen.

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

Acceptatie staat in deze showcase omdat de business en de tribe een stabiele plek willen om de gebruikersflow te doorlopen, en omdat het vertrouwen dat die flow ook automatisch en gepland kan draaien er nog niet is. Dat is een organisatorische stand van zaken, geen technische noodzaak.

De showcase neemt hem daarom op zoals hij is, en laat tegelijk zien wat hem overbodig zou maken. **Hoofdstuk 4 draait de gebruikersflow geautomatiseerd** — dat is precies de reden dat Acceptatie bestaat, en meteen het bewijs dat het gepland kan. **Hoofdstuk 7 legt de externe grens onder een contract** — dat is de tweede reden, en die valt daarmee grotendeels weg. Wie beide heeft staan, houdt van de technische onderbouwing van een derde omgeving weinig over.

Wat er dan overblijft is niet-technisch: mensen willen er met eigen ogen naar kijken voordat het naar buiten gaat. Dat is vertrouwen en geen bewijs, en dat argumenteer je niet weg met gereedschap. Wie doet alsof dat hetzelfde probleem is, verliest het gesprek.

Deze bijlage staat er niet om een omgeving af te schaffen, maar om te voorkomen dat hij onbesproken blijft. Een concessie die niemand benoemt, wordt vanzelf een uitgangspunt.

---

## Wijzigingslog

| Versie | Wijziging |
|---|---|
| 0.6.8 | Verwijzing bovenaan hoofdstuk 1 naar `01-basis/README.md`. Dit document houdt het wat en waarom; het hoe staat in de README van elk hoofdstuk, naast de code die het beschrijft. |
| 0.6.7 | In 1.4 vastgelegd dat contractverificatie in twee stijlen bestaat: gegenereerd uit de spec en met de hand geschreven. De showcase houdt allebei, een pipeline kiest er een. Met de reden erbij: geschreven tests dekken wat de schrijver bedacht, en dat is meetbaar minder. Voor unit en integratie speelt de keuze niet, want daar ligt de norm in de test. |
| 0.6.6 | `currency` van een `pattern` naar een `enum` van EUR, USD en GBP, en `maximum` op `amount`. Daarmee staat elke geldigheidsregel in het contract en blijft als semantiek alleen de drempel van 500,00 over — een businessuitkomst, geen invoercontrole. Gemeten met oasdiff: een valuta toevoegen is niet breaking (scenario A), een valuta weghalen wel. De implementatie volgt de enum en accepteert niet meer dan de spec belooft. |
| 0.6.5 | Semantiek naar het schema waar het schema hem kan dragen: `minimum: 0` met `exclusiveMinimum: true` op `amount`, en een `pattern` op `currency`. Gevonden doordat Schemathesis meldde dat een schema-geldig verzoek werd geweigerd — het schema liet toe wat de implementatie verbood. Correctie op de baseline, want v1.0.0 was nog niet uitgeleverd; na release was `pattern` toevoegen breaking geweest. Wat overblijft is echte semantiek: dat een valutacode bestaat, en de drempel van 500,00. |
| 0.6.4 | Inleiding verwijst naar `besluiten.md` en `security.md`, zodat de onderbouwing van een keuze vindbaar is vanaf de plek waar de keuze staat. |
| 0.6.3 | O7 gesloten door het te proberen in plaats van te vergelijken: de stub wordt zelf gegenereerd en draait op WireMock. Prism doet padtemplates, examples en requestvalidatie native, maar kiest per status altijd hetzelfde voorbeeld en kan de afgewezen betaling uit 1.2 dus niet opleveren. Reden opgenomen in 1.6, inclusief wat de opzet daarmee laat liggen. |
| 0.6.2 | Eén compose per deelsysteem, in alle drie de omgevingen dezelfde; een omgeving is een samenstelling van die bestanden en geen eigen beschrijving. Anders staat een deelsysteem drie keer beschreven en lopen die drie uit elkaar. Twee versies uit elkaar gehaald: die van het contract en die van de service, met beide op het info-endpoint. Onveranderlijkheid uitgebreid naar images: geen hertagging, geen `-rc`-achtervoegsel, RC is een status en geen naam. In 1.1 vastgelegd dat productie het enige is dat telt, als de harde reden achter randvoorwaarde 6. Bijlage A toegevoegd over Acceptatie als concessie. O12 erbij. |
| 0.6.1 | Vastgelegd in 1.13 dat de waarden van `code` in het `Error`-schema geen onderdeel van het contract zijn: het schema legt de structuur vast, niet de verzameling codes. Anders wordt elke nieuwe foutsituatie bij de provider een contractwijziging. |
| 0.6.0 | Testopzet uitgeschreven. Drie omgevingen in plaats van twee: CI, Test zonder koppeling naar buiten, Acceptatie mét. Deploy per deelsysteem, gate is telkens de vorige omgeving groen. Contractverificatie draait na de deploy op de CI-omgeving en is daar volledig — elke operatie, happy en unhappy. De piramide houdt drie lagen: contracttesten voegt er geen toe maar verlegt de norm in de integratielaag en verkleint de top. `can-i-deploy` vervangen door waarnemen boven voorspellen, gedragen door de versieconformiteitscheck. Randvoorwaarde 6 erbij: rood is eerste prioriteit. Dashboard als onderdeel van het mechanisme. Geen patch, want de opzet verandert wezenlijk. |
| 0.5.6 | O10 toegevoegd: wat de micro-frontend van Notification laat zien. Hij is nodig als remote voor hoofdstuk 9, maar hoofdstuk 6 heeft geen UI nodig, dus zijn inhoud is nergens belegd. |
| 0.5.5 | Micro-frontends in het repositoryoverzicht: Order, Payment en Notification krijgen er elk een. Vastgelegd dat de portal samenstelt maar niet bezit — de remotes blijven bij hun eigen deelsysteem staan, anders wisselt er bij shell ↔ remote geen eigenaarschap meer en heeft hoofdstuk 9 geen grens meer te tonen. O9 gaat daarmee over welke micro-frontend hoofdstuk 8 uitwerkt, niet over welke bestaat. |
| 0.5.4 | Wat 0.5.3 een *component* noemde heet nu een **service**; er is één woord voor het ding onder een deelsysteem. Notification en Portal vastgelegd als de derde en vierde deelsysteem, met hun services in het repositoryoverzicht. |
| 0.5.3 | Een deelsysteem bestaat uit microservices: de deelsysteemmap is een houder, elke microservice en micro-frontend staat eronder als eigen component. De frontend van hoofdstuk 8 komt daarmee in `deelsystemen/<naam>/<naam>-mf/` en niet in de hoofdstukmap; de portal-shell van hoofdstuk 9 wordt een eigen deelsysteem. O9 toegevoegd: welk deelsysteem de UI van hoofdstuk 8 krijgt. |
| 0.5.2 | Kolom *Vereist* voor hoofdstuk 6 en 7 noemt nu `ci/` en `deelsystemen/payment/` in plaats van "de scripts uit hoofdstuk 1". Die formulering hoorde bij de oude indeling, waarin Payment onder `01-basis/` stond. |
| 0.5.1 | Services verplaatst naar `deelsystemen/` op de hoofdmap; genummerde mappen bevatten alleen nog tests. Tegenvoorbeeld bij scenario A vervangen: `merchantId` verplicht toevoegen in plaats van `currency` uit de required-lijst halen. Dat laatste is geen breaking wijziging — een verzoek wordt er minder streng van — en werd door gate noch register geweigerd. Contractpad naar `contracts/order-payment/v1.0.0/`. In 1.9 vastgelegd dat het tweede net in Apicurio 3.3.1 ook voor OPENAPI werkt, en wat de gate niet ziet. |
| 0.5.0 | Startversie |
