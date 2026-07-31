# Showcase CBT

Versie 0.5.1

Dit is een werkdocument: elke wijziging is een patchbump, zodat er altijd naar een vorige versie terug te vallen is. De aard van de wijziging staat in de wijzigingslog, niet in het versienummer.

Een showcase die contract-based testing aantoonbaar maakt. Het contexthoofdstuk beschrijft wat overal gelijk is; elk hoofdstuk daarna is los te lezen.

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

**Randvoorwaarden waaronder dit werkt.** Deze manier van contracttesten is niet universeel; ze veronderstelt vijf dingen, en die verklaren de keuzes die anders willekeurig lijken.

| | Randvoorwaarde | Gevolg voor het ontwerp |
|---|---|---|
| 1 | Eigenaarschap van deelsystemen ligt bij verschillende teams | een grens is organisatorisch gedefinieerd, niet technisch |
| 2 | De consumers zijn bekend en zitten binnen dezelfde organisatie | de provider kan het contract bezitten en publiceren; consumerverwachtingen zijn overbodig |
| 3 | Teams houden vrijheid binnen hun eigen deelsysteem | afspraken gelden op grenzen, niet op de binnenkant |
| 4 | Het doel is per deelsysteem naar productie kunnen releasen | de contractversie is het synchronisatiepunt, niet de deployvolgorde |
| 5 | Het gereedschap is open source en zonder licentie te draaien | geen commercieel platform voor contractuitwisseling; losse onderdelen die elk vervangbaar zijn |

Valt randvoorwaarde 2 weg — publieke API's, onbekende afnemers — dan verschuift de afweging en worden consumer-driven contracts aantrekkelijker. Valt randvoorwaarde 5 weg, dan komt het bidirectionele model in beeld en wordt een deel van het handwerk hier overbodig. Contract-based testing is hier een middel voor randvoorwaarde 4, geen doel op zich.

### De opbouw

De showcase loopt langs drie assen. Een deel varieert het **grenstype**: hetzelfde mechanisme, een ander contractformaat. Hoofdstuk 2, 3 en 5 variëren de **levenscyclus**: dezelfde grens, een later moment in het leven van een contract. Hoofdstuk 4 varieert de **testsoort**: dezelfde grens, een andere vraag. Hoofdstuk 8 gaat over de **binnenkant** van een deelsysteem en is daarmee het enige dat geen grens beschrijft.

| # | Hoofdstuk | As | Onderwerp | Vereist |
|---|---|---|---|---|
| 1 | CBT basis (API) | grenstype | Order → Payment, REST sync, OpenAPI | — |
| 2 | Wijziging zonder breuk | levenscyclus | additieve wijziging, v1.1.0 | 1 |
| 3 | Breaking wijziging | levenscyclus | twee majors serveren en verifiëren, v2.0.0 | 1 |
| 4 | Acceptatie | testsoort | e2e gebruikersflow over de keten | 1 |
| 5 | Sunset | levenscyclus | oude major uit de runtime | 3 |
| 6 | Async | grenstype | Payment → Notification, AsyncAPI | scripts uit 1 |
| 7 | SOAP | grenstype | externe betaalprovider, WSDL/XSD | scripts uit 1 |
| 8 | Frontend binnen een deelsysteem | binnenkant | Angular → eigen backend | 1 |
| 9 | Frontend in shell | grenstype | shell ↔ remote, module-API | eigen model |

Hoofdstuk 1 tot en met 5 gebruiken dezelfde grens: het is één basis waar de contractlevenscyclus overheen loopt, geen vijf basissen. Hoofdstuk 1 tot en met 5 dekken de testfeatures F2 (een REST-grens), F3 (versiecontrole bij deployment) en F4 (monitoring op productie); 6 en 7 dekken F5 (async) en F6 (SOAP), en 9 gaat over een frontend-grens. Hoofdstuk 8 heeft bewust geen testfeature: de kaders gelden op grenzen, niet op de binnenkant.

**De showcase is een boom, geen rij.** De kolom *Vereist* zegt wat er af moet zijn; 6 en 7 hebben alleen de scripts uit hoofdstuk 1 nodig en niet de volledige basis. De nummering is vlak gehouden omdat 1.2 in dit document al een subparagraaf aanduidt.

**De volgorde is de bouwvolgorde.** Hoofdstuk 1 draagt ruwweg de helft van al het bouwwerk; 2 tot en met 5 zijn er kleine uitbreidingen op en maken het verhaal compleet tot het einde van de contractlevenscyclus. Pas daarna wordt het contractformaat gevarieerd. De frontend staat achteraan omdat hij het model oprekt en een nog openstaande keuze raakt.

### De repository

| | |
|---|---|
| Naam | `showcase-cbt` — het voorvoegsel zegt bij de eerste blik dat dit geen productiecode is |
| Plaats | GitHub, publiek, persoonlijk account; in eigen tijd gebouwd |
| Licentie | MIT: vrij te gebruiken, zonder garantie en zonder aansprakelijkheid |
| Gebruiksmodel | referentie om te bekijken en te draaien; fork of template voor wie er zelf mee wil spelen |

**Eén repository met een map per hoofdstuk.** Niet negen repositories: dan ontstaan negen kopieën van dezelfde scripts die uit elkaar lopen, en toont de showcase onbedoeld aan dat het niet standaardiseerbaar is.

```
showcase-cbt/
├── README.md
├── LICENSE
├── ci/                       gedeelde scripts, één exemplaar
├── contracts/                alle specs, per grens en versie
├── compose/registry.yml      Apicurio, gedeeld
├── playwright/               config en gedeelde specs: smoke, later UI
├── 01-basis/                 payment, order, compose, demo
├── 02-wijziging-zonder-breuk/
├── 03-breaking/
├── 04-acceptatie/
├── 05-sunset/
├── 06-async/
├── 07-soap/
├── 08-frontend-binnenkant/
└── 09-frontend-shell/
```

Twee regels dragen deze indeling. **`ci/`, `contracts/` en `playwright/` staan uitsluitend op de wortel**: zodra een showcase een eigen kopie van `get-contract.sh` krijgt, is de claim dat het mechanisme uniform is niet meer waar. En **hoofdstuk 2 tot en met 5 bevatten geen services**; die gebruiken de deelsystemen uit `01-basis/` en voegen alleen een spec en een demoscript toe. Losstaand te draaien zijn daarmee de mappen met services: 01, 06, 07, 08 en 09.

**Testgereedschap wordt hergebruikt, niet per hoofdstuk opnieuw ingericht.** Playwright staat op de wortel in `playwright/` — niet onder een naam als `e2e`, want hij bedient meerdere lagen. Eén smoke-spec wordt op een base-URL geparametriseerd: dezelfde spec draait in de CI-omgeving tegen de stub, op Test tegen de echte buur en op Acceptatie tegen de samenstelling. `ci/smoke.sh <base-url>` is het enige aanroeppunt. Playwright is in dit soort omgevingen doorgaans al in gebruik voor de e2e van een deelsysteem; de showcase sluit daarop aan in plaats van er een tweede werkwijze naast te zetten. Showcasespecifieke specs — bijvoorbeeld die van de UI in hoofdstuk 8 — staan in de hoofdstukmap zelf.

**De smoke gaat niet over inhoud.** De gedeelde smoke-spec assert uitsluitend op HTTP-status en op het doorlopen van de keten — geen veldwaarden, geen businessregels. Anders draait hij groen tegen de stub en rood tegen de echte buur om een reden die niets met de grens te maken heeft, en verhuist bovendien werk van een goedkope laag naar een dure.

**Laptopbudget is een ontwerpeis.** Alles draait naast een IDE tijdens een presentatie. Daarom is elke showcase los op te starten en is er geen enkel moment waarop alles tegelijk nodig is: registry plus één showcase is de maximale opstelling. Wat daar niet in past, wordt vereenvoudigd in plaats van uitgebreid.

**Het document staat in de repository.** `docs/` bevat dit document; `CLAUDE.md` op de wortel verwijst ernaar en herhaalt de regels die niet overtreden mogen worden. Een showcase zonder het waarom is een hoop code zonder argument.

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
| Pipelines | twee, één per team, volledig onafhankelijk van elkaar |
| Omgevingen | CI-omgeving per deelsysteem met stubs; Test met echte buren |
| Testlagen | unit, integratie, contractverificatie, e2e smoke test |
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
        currency:
          type: string
          minLength: 3
          maxLength: 3
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

**Wat het schema niet dekt** is de semantiek: dat een bedrag groter dan nul moet zijn en de valutacode moet bestaan. Dat blijven de twee unittests uit 1.4.

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

### 1.1 Rationale

**Eén contract, twee kanten.** De provider bezit en publiceert het contract. Beide kanten verifiëren hun eigen conformiteit tegen diezelfde gepubliceerde spec. Geen consumer-expectations, geen n×m-verificatie, geen tweede contractstore.

**De contractversie is het synchronisatiepunt, niet de deployvolgorde.** Twee pipelines die elkaar nooit zien, komen via één contract tot hetzelfde oordeel. Daarom is er geen release train en is `can-i-deploy` niet nodig: compatibiliteit is al vastgesteld op Build, niet opgevraagd bij de deploy.

**Contract is geen testlaag maar een norm.** Op de bestaande lagen van de piramide verandert niet de laag maar de bron van de waarheid: bij unit en integratie ligt de norm in de test, bij contractverificatie ligt hij buiten de test in een artefact dat elders wordt beheerd.

**Spec-first minimaliseert geen breuken maar verplaatst ze.** Een noodzakelijke breuk blijft noodzakelijk. Wat verandert is het moment: bij spec-first is de breuk een besluit vóórdat er code ligt, bij code-first een ontdekking als terugdraaien al duur is. De drift-check is wat die belofte afdwingt.

**Twee omgevingen, twee bewijzen.** In de CI-omgeving toont het team aan dat zijn deelsysteem werkt zónder zijn buur. Op Test wordt aangetoond dat de samenstelling die op dat moment draait, klopt en loopt.

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

### 1.3 Twee omgevingen

| | CI-omgeving | Test |
|---|---|---|
| Compose | `docker-compose.ci-<deelsysteem>.yml` | `docker-compose.test.yml` |
| Buren | WireMock-stub uit de spec | echte deelsystemen |
| Scope | één deelsysteem in isolatie | de samenstelling |
| Toont aan | deployment werkt, buur niet nodig | de combinatie klopt en loopt |
| Eigenaar | het team | gezamenlijk |

---

### 1.4 Pipeline Payment (provider)

| # | Stap | Laag | Tegen | Norm |
|---|---|---|---|---|
| 1 | build | — | code | — |
| 2 | unit (`-Dgroups=unit`) | unit | code | test |
| 3 | integratie (`-Dgroups=integratie`) | integratie | code + eigen DB | test |
| 4 | `get-contract v1` uit register | — | register | — |
| 5 | contractverificatie (`-Dgroups=contract`) | integratie | code | **spec** |
| 6 | drift: runtime-spec vs gepubliceerde spec | geen | artefact | **spec** |
| 7 | docker build + label contractversie | — | — | — |
| 8 | up `docker-compose.ci-payment.yml` | — | draaiend | — |
| 9 | healthcheck | — | draaiend | — |
| 10 | smoke | e2e smoke test | draaiend | test |

Payment heeft binnen deze scope geen buren; zijn CI-omgeving bevat daarom geen stubs.

---

### 1.5 Pipeline Order (consumer)

| # | Stap | Laag | Tegen | Norm |
|---|---|---|---|---|
| 1 | build | — | code | — |
| 2 | unit (`-Dgroups=unit`) | unit | code | test |
| 3 | integratie (`-Dgroups=integratie`) | integratie | code + eigen DB | test |
| 4 | `get-contract <pin>` uit register | — | register | — |
| 5 | stub genereren + valideren | — | artefact | **spec** |
| 6 | contractverificatie (`-Dgroups=contract`) | integratie | code + in-process stub | **spec, beide richtingen** |
| 7 | docker build + label contractversie | — | — | — |
| 8 | up `docker-compose.ci-order.yml` (stub, geen Payment) | — | draaiend | — |
| 9 | healthcheck | — | draaiend | — |
| 10 | smoke tegen stub | e2e smoke test | draaiend | test |

De consumer heeft geen drift-stap: hij bezit het contract niet, dus er valt aan zijn kant niets van af te wijken.

Er is één stub, gegenereerd uit de spec uit het register, gevalideerd bij het maken en daarna gebruikt in stap 6, 8 en 10. De mappings worden nooit gecommit.

---

### 1.6 Stubgeneratie

De stub bestaat uitsluitend op Build, wordt elke run opnieuw gegenereerd uit de spec uit het register en wordt nooit gecommit.

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

### 1.7 Test-omgeving

Geen pipelinestap. Draait na **elke** deploy naar Test, ongeacht welk deelsysteem is gedeployd.

| Controle | Toont aan |
|---|---|
| healthcheck | deelsystemen komen omhoog |
| versieconformiteit | welke contractversies draaien samen |
| smoke over de echte keten | technische integratie werkt |

Elk deelsysteem meldt zijn contractversie op zijn info-endpoint (provider: gepubliceerde versie, consumer: zijn pin). De versieconformiteitscheck vergelijkt die samenstelling met de verwachte.

**Rollback.** Trigger is een van de drie controles rood. Doel is een draaiende T-omgeving, niet schuldtoewijzing: de laatste deploy draait terug. Bij een afwijkende versiesamenstelling kan roll-forward de juiste beweging zijn — het ontbrekende deelsysteem alsnog deployen in plaats van het geslaagde terugtrekken. Rollback geldt voor deployments; het register kent geen rollback, daar is alleen een nieuwe versie.

Een gedwongen deployvolgorde is geen normale gang van zaken maar een signaal: de provider serveerde niet twee versies naast elkaar.

---

### 1.8 Testlagen en normen

| | tegen code | tegen draaiend deelsysteem |
|---|---|---|
| **unit** | unit tests — norm in de test | — |
| **integratie** | integratietest (eigen DB) — norm in de test<br>contractverificatie, consumertest tegen stub — norm = **spec** | healthcheck |
| **e2e smoke test** | — | smoke |

Buiten de piramide: drift-check en stubvalidatie. Dat zijn vergelijkingen van artefacten, geen runtime-gedrag — dezelfde familie als een linter.

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
| 2 | Payment's pipeline draait groen | conformiteit van de provider |
| 3 | Test omhoog, versieconformiteit | welke contractversies samen draaien |
| 4 | dezelfde smoke groen tegen de echte keten | de samenstelling werkt |

Scène 1 en 2 zijn in willekeurige volgorde te draaien; begin bewust met Payment, omdat het publiek verwacht dat de consumer als laatste moet.

De demo's uit hoofdstuk 2 tot en met 5 zijn scripts (`demo/<naam>.sh`), geen branches: een branch per scenario moet worden bijgewerkt bij elke wijziging in de basis. Elk script past de wijziging toe, draait de betrokken pipelines en eindigt met een reset naar de uitgangssituatie.

---

### 1.12 Bewust buiten dit hoofdstuk

| Onderdeel | Waar |
|---|---|
| Contractwijziging, breaking change, deprecation | hoofdstuk 2, 3 en 5 |
| Acceptatie als tweede omgeving, rollback | hoofdstuk 4 |
| Async, SOAP, derde deelsysteem | hoofdstuk 6 en 7 |
| Angular UI | hoofdstuk 8 |
| Publicatie vanuit een pipeline | hier handmatig; O5 |
| Monitoring op Productie (F4) | vereist een productielaag; O8 |

---

### 1.13 Besluiten en openstaande punten

**Besloten.** De naamgeving van de testlagen volgt één begrippenlijst en wijkt daar nergens van af; waar dit document "contractverificatie" schrijft, geldt die term consequent in scriptnamen, JUnit-tags en pipeline-uitvoer. Betekenisvolle `example`-waarden zijn een norm voor elke spec: zonder example faalt de stubgeneratie (zie 1.6).

| # | Openstaand punt |
|---|---|
| O2 | Verwachte samenstelling voor de versieconformiteitscheck: bestand in de repo of afgeleid uit de pins van de deelnemende pipelines |
| O3 | Eigenaarschap: wie bewaakt de versieconformiteit en wie voert de rollback uit |
| O4 | Version state voor deprecated versies in Apicurio 3.x — naamgeving verifiëren |
| O5 | Eigenaarschap van de spec: in de provider-repo of in een aparte spec-repo met review door de architect. Technisch afgedekt via het aansluitpunt in 1.9; dit is een vraag voor de werkwijze, niet voor deze showcase |
| O7 | Bestaande OpenAPI-naar-WireMock-generatoren beoordelen voordat stap 2–5 zelf wordt gebouwd |
| O8 | Pins op info-endpoints als surrogaat voor monitoring (F4): tijdelijk voor de showcase of blijvend naast monitoring |

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
| Toevoeging | de e2e gebruikersflow over de keten, op Acceptatie, met echte buren |
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

> Vereist de scripts uit hoofdstuk 1. Nog niet uitgewerkt.

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

> Vereist de scripts uit hoofdstuk 1. Nog niet uitgewerkt.

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

> Vereist hoofdstuk 1. Nog niet uitgewerkt.

| | |
|---|---|
| Grens | **geen** — Angular en backend zijn van hetzelfde team, er wisselt geen eigenaarschap |
| Contract | de eigen OpenAPI van het deelsysteem; publicatie in het register is hier optioneel |
| Toevoeging | de frontend als consumer: pinnen, stub genereren, schemavalidatie in de browser; dit is de plek voor Playwright en ajv |
| Status | teamkeuze, geen gezamenlijk kader — afspraken gelden op grenzen, niet op de binnenkant |

Deze showcase toont aan dat hetzelfde mechanisme bruikbaar is binnen een deelsysteem, met een uitdrukkelijk andere boodschap dan de rest van de showcase: het mag, het werkt, en het wordt niet voorgeschreven. Hij levert ook de UI die hoofdstuk 1 bewust niet heeft.

---

## 9. Frontend in shell

> Eigen model. Wordt pas gebouwd als de andere hoofdstukken staan; de opzet wijkt te veel af om er nu aan te beginnen.

| | |
|---|---|
| Grens | shell ↔ remote: een ander team levert de remote |
| Contract | exposed module-API: componenten, props, events |
| Toevoeging | het contract is geen spec: versiebeheer loopt via een package in plaats van het register, en verificatie is deels een typecheck in plaats van runtime-validatie |
| Open vraag | schemavalidatie in de browser op Test: het enige dat een contractafwijking bij de echte buur zichtbaar maakt |
| Testfeature | frontend-grens |

---

## Wijzigingslog

| Versie | Wijziging |
|---|---|
| 0.5.1 | Tegenvoorbeeld bij scenario A vervangen: `merchantId` verplicht toevoegen in plaats van `currency` uit de required-lijst halen. Dat laatste is geen breaking wijziging — een verzoek wordt er minder streng van — en werd door gate noch register geweigerd. Contractpad naar `contracts/order-payment/v1.0.0/`. In 1.9 vastgelegd dat het tweede net in Apicurio 3.3.1 ook voor OPENAPI werkt, en wat de gate niet ziet. |
| 0.5.0 | Startversie |
