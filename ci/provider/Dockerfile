# De provider van showcase-CBT. Geen afhankelijkheden buiten de standaardbibliotheek van
# Node, dus geen npm install en geen node_modules: http, fs en crypto volstaan.
#
# De image draagt zijn eigen stamdata. Een scenario wijzigen levert een nieuwe image op, en
# dat is de bedoeling — dan zegt het versienummer iets en is de inhoud reproduceerbaar.
FROM node:22.23.2-alpine

# Non-root, zoals elke container in deze opzet. De image van Node brengt de gebruiker `node`
# al mee.
USER node
WORKDIR /provider

COPY --chown=node:node server.js provider-data.json manifest.json ./
COPY --chown=node:node scenarios ./scenarios

EXPOSE 8090
CMD ["node", "server.js"]
