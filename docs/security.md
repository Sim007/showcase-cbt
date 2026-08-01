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
