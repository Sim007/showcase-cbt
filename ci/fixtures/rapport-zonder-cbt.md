# Rapport CBT — hoofdstuk 0

Begonnen op 2026-01-01 10:00:00 UTC. Alle tijden zijn UTC.

| Tijd | Onderdeel | Stap | Uitkomst | Bijzonderheden |
|---|---|---|---|---|
| 10:00:00 | payment-api 1.0.0 | unit | groen | Tests run: 9, Failures: 0, Errors: 0 |
| 10:00:08 | payment-api 1.0.0 | integratie | groen | Tests run: 8, Failures: 0, Errors: 0 |
| 10:00:11 | payment-api 1.0.0 | jar bouwen | groen | |
| 10:00:13 | payment-api 1.0.0 | image bouwen | groen | |
| 10:00:13 | payment-api 1.0.0 | — | **oordeel** | Oordeel: groen. De microservice is gebouwd en getoetst tegen zijn eigen tests. |
| 10:00:20 | payment 1.0.0 → CI | deploy op ci-payment | groen | |
| 10:00:22 | payment 1.0.0 → CI | e2e binnen payment | groen | 2 passed |
| 10:00:23 | payment 1.0.0 → CI | — | **oordeel** | Oordeel: groen. payment 1.0.0 draait als geheel op een eigen omgeving. Over de grenzen is hier niets vastgesteld. |
