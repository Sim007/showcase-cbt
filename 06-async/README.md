# 6. Async

> Vereist `ci/` en `deelsystemen/payment/`. Nog niet uitgewerkt.

De grens Payment → Notification over een queue of topic, met AsyncAPI als contract. Er is
geen response: provider-verificatie wordt *valideer wat ik publiceer*, consumer-verificatie
*valideer wat ik consumeer*, en de stub is een producer in plaats van een antwoordende
server. De kleinste stap van de drie grenstypen — Apicurio is van origine een schema
registry.

Zie `docs/showcase-cbt.md`, hoofdstuk 6.
