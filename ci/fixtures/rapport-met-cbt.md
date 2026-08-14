# Rapport CBT — scenario 1

Begonnen op 2026-01-01 10:00:00 UTC. Alle tijden zijn UTC.

| Tijd | Onderdeel | Stap | Uitkomst | Bijzonderheden |
|---|---|---|---|---|
| 10:00:00 | contract payment-api 1.0.0 | diff-gate en publiceren | groen | leeg register, niets om mee te vergelijken |
| 10:00:02 | contract payment-api 1.0.0 | ophalen ter controle | groen | |
| 10:00:02 | contract payment-api 1.0.0 | — | **oordeel** | Oordeel: groen. Het schema is een artefact geworden. |
| 10:00:10 | payment-api 1.0.0 | unit | groen | Tests run: 9, Failures: 0, Errors: 0 |
| 10:00:18 | payment-api 1.0.0 | integratie | groen | Tests run: 8, Failures: 0, Errors: 0 |
| 10:00:21 | payment-api 1.0.0 | jar bouwen | groen | |
| 10:00:23 | payment-api 1.0.0 | image bouwen | groen | |
| 10:00:23 | payment-api 1.0.0 | — | **oordeel** | Oordeel: groen. Dezelfde microservice, dezelfde tests, ongewijzigd artefact. |
| 10:00:30 | payment 1.0.0 → CI | deploy op ci-payment | groen | |
| 10:00:33 | payment 1.0.0 → CI | drift | groen | 2 operaties, geen schaduw |
| 10:00:39 | payment 1.0.0 → CI | contractverificatie, provider | groen | 6 operaties, 12 responses |
| 10:00:41 | payment 1.0.0 → CI | e2e binnen payment | groen | 2 passed |
| 10:00:42 | payment 1.0.0 → CI | — | **oordeel** | Oordeel: groen. payment 1.0.0 voldoet aan de gepubliceerde spec, zonder dat Order ergens draaide. |
