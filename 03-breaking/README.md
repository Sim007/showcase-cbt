# 3. Breaking wijziging

> Vereist hoofdstuk 1. Nog niet uitgewerkt.

Scenario B. Een grens breekt niet: een breuk wordt een nieuwe major náást de bestaande,
met een deprecation-termijn die bij publicatie wordt vastgelegd. `amount` wordt een object
met `value` en `currency`, `currency` verdwijnt uit de root → v2.0.0. Wat hier structureel
nieuw is: `get-contract` en de contractverificatie draaien per major.

Zie `docs/showcase-cbt.md`, hoofdstuk 3.
