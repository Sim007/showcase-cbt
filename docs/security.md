# Security — bevindingen en besluiten

Wat er tijdens het bouwen aan beveiligingskant is gevonden, wat ermee is besloten en wat
nog openstaat. Per bevinding een datum, want een besluit over een kwetsbaarheid is
houdbaar tot er iets verandert en niet langer.

De principes zelf staan in `showcase-cbt.md` onder *Veilige code en schone dependencies*.
Dit bestand is de logboekkant daarvan: waar de praktijk afweek en waarom.

---

## 2026-08-01 — Drie HIGH-CVE's in de basisimage

**Wat.** `eclipse-temurin:21.0.11_10-jre-alpine`, de runtime-basis van `payment-api` en
`order-api`, bevat drie kwetsbaarheden met een beschikbare fix:

| Pakket | CVE | Aanwezig | Gefixt in |
|---|---|---|---|
| libexpat | CVE-2026-56408 | 2.8.1-r0 | 2.8.2-r0 |
| p11-kit | CVE-2026-2100 | 0.25.5-r2 | 0.26.2-r0 |
| p11-kit-trust | CVE-2026-2100 | 0.25.5-r2 | 0.26.2-r0 |

**Hoe gevonden.** De IDE gaf een waarschuwing op de `FROM`-regel; nagelopen met
`aquasec/trivy:0.72.0`, `--severity HIGH,CRITICAL --scanners vuln`.

**Waarom hij er nog staat.** `21.0.11_10-jre-alpine` is de nieuwste beschikbare tag,
bijgewerkt op 2026-06-22. Alpine heeft de pakketten daarna gepatcht; er is dus geen
nieuwere image om naar te bumpen.

**Besluit: de pin blijft staan.** Twee redenen. Een `apk upgrade` in de Dockerfile lost het
vandaag op maar maakt de image niet-reproduceerbaar — dezelfde Dockerfile levert dan
volgende week andere inhoud, en dat botst met de eis dat de versie op een laptop en op een
runner identiek is. En beide kwetsbaarheden zitten in C-bibliotheken die een Spring
Boot-applicatie niet aanroept: Java parseert XML met zijn eigen JAXP-implementatie en niet
met libexpat, en er wordt geen PKCS#11 gebruikt. Dat maakt ze niet onbereikbaar per
definitie, maar het risico is klein genoeg om de reproduceerbaarheid niet voor op te geven.

**Herzien wanneer.** Er een temurin-release verschijnt die op een gepatchte Alpine draait.
Dependabot hoort dat op te pikken; zo niet, dan is dat op zichzelf een bevinding.

**Wat dit blootlegt.** *Vastgepinde tag* en *geen bekende kwetsbaarheden* zijn niet altijd
tegelijk waar. Tussen het moment dat een CVE wordt gepubliceerd en het moment dat de
upstream-image opnieuw is gebouwd, moet je kiezen welke van de twee je loslaat. Deze
showcase kiest voor reproduceerbaarheid en schrijft op wat dat kost.

**Openstaand — een scan als artefactcontrole.** Een kwetsbaarhedenscan hoort in dezelfde
familie als de drift-check en de stubvalidatie: een vergelijking van artefacten, geen
runtime-gedrag en dus geen test. Als hij in de pipeline staat, is een bevinding als deze
geen toevallige IDE-waarschuwing maar een uitkomst die je elke run ziet. Nog niet gebouwd;
het raakt de opzet van de artefactcontroles in 1.8 van `showcase-cbt.md`.

## 2026-08-22 — De runner is een uitvoerkanaal, en dat is de kern en geen bijzin

`ci/runner.sh` haalt werk op bij de provider en start het scenario dat gevraagd wordt.
**Daarmee bestaat er op deze laptop een proces dat programma's start op aanwijzing van iets
buiten zichzelf.** Dat is de eigenschap die telt; alle andere overwegingen komen daarna.

**Waarom hij er is.** De provider draait in een container en het werk gebeurt op de host —
images bouwen, containers starten, een register omhoog. Zou de provider dat zelf starten,
dan had hij de Docker-socket nodig. Die socket geeft root-equivalente toegang tot de hele
machine: wie erbij kan, start een container die het hostbestandssysteem monteert. Daar komt
een mount van de repository bij, want het demoscript staat op de host en niet in de image.
Twee blootstellingen voor één functie.

De omkering kost geen van beide. De runner heeft geen socket nodig — hij ís al op de host —
en geen mount, want hij staat in de repository. Het verkeer gaat over HTTP en de enige
richting die ertoe doet is: de provider zegt wát, de runner bepaalt óf en hoe.

**Wat het kanaal nauw houdt, en waarom dat controles zijn en geen aannames.**

| | |
|---|---|
| **Vorm** | het scenario-id moet `^[0-9]{2}$` zijn — het patroon uit de spec |
| **Verzameling** | het moet in een `case`-lijst staan die letterlijk `00` en `01` noemt |
| **Afbeelding** | die lijst geeft het scriptpad terug; er wordt nooit een pad samengesteld |

Die drie staan **twee keer**: in de provider vóór het werk wordt aangenomen, en in de runner
vóór het wordt uitgevoerd. Dat is geen dubbel werk maar het hele punt. "De provider heeft het
al gecontroleerd" is precies de aanname waarmee een uitvoerkanaal onveilig wordt — dan is de
veiligheid van de host afhankelijk van de juistheid van een ander proces, en niet van een
controle op de plek waar het gebeurt.

**Waarom er geen pad wordt samengesteld.** `"${SCENARIO}/demo/demo.sh"` zou werken en is fout:
`../../` in de invoer wijst dan naar een script buiten de scenariomappen. De `case` kan dat
niet, want hij kent maar twee antwoorden en verzint er geen derde. Gemeten: een POST met
`{"scenarioId":"../../etc"}` geeft 404 en komt nooit bij de runner.

**Wat er blootgesteld blijft, en dat is niet nul.** Wie de provider kan bereiken, kan op deze
laptop scenario 00 of 01 starten. Dat betekent: containers omhoog en omlaag, images bouwen,
het register legen. Voor een demo op één machine is dat de bedoeling; op een gedeelde machine
zou het dat niet zijn. De provider luistert daarom op `localhost` en er hoort geen route van
buiten naartoe te bestaan.

**Herzien wanneer.** De provider ergens anders draait dan naast de runner op dezelfde laptop,
of er een derde scenario bij komt — dan groeit de lijst, en een lijst die groeit is de plek
waar zo'n controle in de praktijk verwatert.
