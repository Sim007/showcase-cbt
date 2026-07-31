# 7. SOAP

> Vereist `ci/` en `deelsystemen/payment/`. Nog niet uitgewerkt.

De grens Payment → externe betaalprovider, met WSDL/XSD als contract dat niet in eigen
bezit is. Publiceren vervalt: de externe partij levert het contract en de organisatie pint
erop. De diff-gate draait op wijzigingen van een ander, versiebeheer is onderhandeling in
plaats van beleid, en een deprecation-termijn is niet af te dwingen. Dit is het antwoord op
de vraag of contracttesten ook buiten de eigen organisatie werkt.

Zie `docs/showcase-cbt.md`, hoofdstuk 7.
