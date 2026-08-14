# 5. Sunset

> Vereist scenario 3. Nog niet uitgewerkt.

Voegt het einde van de levenscyclus toe: deprecation, de laatste consumer van een major af,
de route uit de runtime. Het contract wordt niet verwijderd — het register is immutable;
wat verdwijnt is dat de provider de oude major nog serveert. Dit is het enige scenario dat
Build principieel niet kan zien: *wordt deze versie nog geserveerd* is geen eigenschap van
een spec maar van een omgeving.

Zie `docs/showcase-cbt.md`, scenario 5.
