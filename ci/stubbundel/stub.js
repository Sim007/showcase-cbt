// De stub van showcase-CBT, voor wie geen Docker en geen JDK heeft.
//
//   node stub.js            luistert op 8090
//   POORT=9000 node stub.js
//
// Alles wat hij serveert komt uit stub-data.json en de runs, en die zijn gegenereerd uit
// de gepubliceerde specs. Er staat hier dus niets wat niet uit het contract komt.
//
// Wat hij wél toetst: elke requestbody gaat langs het schema uit de spec. Wat niet in de
// spec staat, komt er niet doorheen — dat is waarom deze stub bruikbaar is om tegen te
// bouwen en een handgeschreven mock dat niet is.
//
// Wat hij niet toetst: de berichten op de stream. Die worden afgespeeld zoals ze zijn
// opgenomen. Zie de README.
//
// --- De verbinding blijft open (run-stream 0.11.0) -------------------------------------
//
// Eén verbinding per sessie, niet per run. De consumer sluit hem, niet wij. Een run start
// over `POST /v1/runs` en de berichten gaan naar iedereen die op dat moment luistert. Bij
// het verbinden komt eerst een momentopname, en blijft het daarna stil dan gaat er elke
// HARTSLAG_MS een SSE-commentaarregel uit als teken van leven.
//
// De momentopname bij verbinden draagt de stand van de run die op dat moment loopt. Die
// stand leidt de stub uitsluitend af uit wat hij verstuurd heeft — zie `beginStand` en
// `werkBij` verderop — en nooit uit wat hij vermoedt.

const http = require('http');
const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const HIER = __dirname;
const POORT = Number(process.env.POORT || 8090);
const data = JSON.parse(fs.readFileSync(path.join(HIER, 'stub-data.json'), 'utf8'));

// De twee schakelaars hieronder zijn gereedschap om een belofte uit het contract te kunnen
// aantonen, en geen gedrag dat het contract beschrijft. Zie de README.
//
// HARTSLAG_MS staat op de 20 seconden uit de spec. Lager zetten is er voor een toets: een
// hartslag die pas na 20 seconden komt, wordt door geen enkele toets binnen een run gezien,
// en dan is "er is een heartbeat" opnieuw een bewering zonder iets eronder.
const HARTSLAG_MS = Number(process.env.HARTSLAG_MS || 20000);
const TEMPO_MS = 400;

const ajv = new Ajv({ strict: false, allErrors: true });
addFormats(ajv);

// Elke route krijgt zijn eigen validator, of null als er geen body verwacht wordt.
const routes = data.routes.map((r) => ({
  ...r,
  patroon: new RegExp(r.patroon),
  keur: r.verzoekSchema ? ajv.compile({ ...data.componenten, ...r.verzoekSchema }) : null,
}));

const startroute = routes.find((r) => r.operationId === 'startRun');
if (!startroute) throw new Error('geen operatie startRun in stub-data.json');

// De drie fixtures, om en om bij elke start. Zo komt de gestopte run vanzelf aan de beurt,
// en die heeft de consumer het hardst nodig.
const NAMEN = ['voltooid', 'gestopt', 'midden'];
const RUNS = NAMEN.map((naam) =>
  fs.readFileSync(path.join(HIER, 'runs', `${naam}.jsonl`), 'utf8').trim().split('\n')
);

const SCENARIOS = (data.routes.find((r) => r.operationId === 'haalScenario') || {}).bodyPerId || {};
let beurt = 0;

// Het runId komt uit de opname zelf en niet uit een example: de drie fixtures dragen elk hun
// eigen nummer, en de stub moet zijn twee kanten daarover laten overeenstemmen.
function runIdVan(regels) {
  for (const regel of regels) {
    const b = JSON.parse(regel);
    if (b.runId) return b.runId;
    if (b.run && b.run.runId) return b.run.runId;
  }
  throw new Error('een opname zonder runId');
}

// De momentopname voor een verbinding waarop niets loopt. Uit de fixtures, want `run: null`
// is een opgenomen regel en de normale begintoestand van een sessie. Ontbreekt hij, dan
// stopt de stub: zelf een lege momentopname verzinnen is precies wat hij niet doet.
const IDLE = RUNS.map((regels) => regels[0])
  .find((regel) => {
    const b = JSON.parse(regel);
    return b.soort === 'momentopname' && b.run === null;
  });
if (!IDLE) throw new Error('geen momentopname met run: null in de fixtures');

// TOLERANTIE=ja stuurt wat een volgende contractversie zou kunnen sturen. Niet omdat 0.11.0
// dat doet, maar omdat een stub die alleen de huidige versie spreekt een tolerantiefout
// niet kán tonen: alles past, dus alles lijkt goed — tot de eerste additieve wijziging.
//
// Alle drie de vormen tegelijk, want een schakelaar die een derde van de belofte toetst en
// groen meldt is hetzelfde patroon als een lus die na één bericht stopt.
const TOLERANT = process.env.TOLERANTIE === 'ja';

function tolerantBericht(b) {
  b.herkomst = 'toekomstige-versie';                         // 1 — onbekend veld
  if (b.soort === 'run-afgerond' && b.reden === 'gestopt') {
    b.reden = 'gestopt-door-beheerder';                      // 3 — onbekende enum-waarde
  }
  return b;
}

function tolerantRegel(regel) {
  if (!TOLERANT) return regel;
  return JSON.stringify(tolerantBericht(JSON.parse(regel)));
}

function toekomstig(regels) {
  if (!TOLERANT) return regels;

  const uit = regels.map((regel) => JSON.stringify(tolerantBericht(JSON.parse(regel))));

  // 2 — onbekend berichttype, vlak voor het einde zodat het midden in de verwerking valt
  const laatste = JSON.parse(uit[uit.length - 1]);
  uit.splice(uit.length - 1, 0, JSON.stringify({
    soort: 'deelsysteem-overgeslagen',
    tijd: laatste.tijd,
    runId: laatste.runId,
    deelsysteem: 'order',
    herkomst: 'toekomstige-versie',
  }));

  return uit;
}

function lees(verzoek) {
  return new Promise((klaar) => {
    let ruw = '';
    verzoek.on('data', (stuk) => (ruw += stuk));
    verzoek.on('end', () => klaar(ruw));
  });
}

// --- de stream ---------------------------------------------------------------------------

const abonnees = new Set();
let lopend = null;

// De hartslag wordt na elk bericht opnieuw opgezet: hij is er voor stilte, en een verbinding
// waarover berichten gaan heeft geen extra teken van leven nodig. Zo staat het ook in de
// kanaalbeschrijving — "blijft het stil, dan".
function hartslagOpnieuw(abonnee) {
  clearTimeout(abonnee.hartslag);
  abonnee.hartslag = setTimeout(() => {
    abonnee.antwoord.write(': hartslag\n\n');
    hartslagOpnieuw(abonnee);
  }, HARTSLAG_MS);
}

function zend(abonnee, regel) {
  abonnee.antwoord.write(`data: ${regel}\n\n`);
  hartslagOpnieuw(abonnee);
}

// --- de stand van de lopende run ---------------------------------------------------------
//
// De stub leidt zijn toestand uitsluitend af uit wat hij verstuurd heeft, nooit uit wat hij
// vermoedt. Dat is het verschil met zelf een momentopname verzinnen: hier begint de stand bij
// de openingsmomentopname van de opname — zelf een opgenomen uitspraak over de toestand — en
// wordt hij bijgewerkt door precies de berichten die de deur uit zijn gegaan.
//
// Zonder dit stuurde de stub bij verbinden de openingsregel van de opname, dus `run: null`
// terwijl er een run liep. Het schema zegt daarover: "Null wanneer er geen run loopt."
// Dat was geen beperking van de bundel maar een stub die zijn eigen contract tegensprak.

function beginStand(openingRegel) {
  const b = JSON.parse(openingRegel);
  const stand = {
    soort: 'momentopname',
    tijd: b.tijd,
    run: b.run,
    afgerondeStappen: (b.afgerondeStappen || []).slice(),
  };
  if (b.lopendeStap !== undefined) stand.lopendeStap = b.lopendeStap;
  return stand;
}

function werkBij(stand, b) {
  stand.tijd = b.tijd;
  switch (b.soort) {
    case 'run-gestart':
      // `Run` eist een gestartOp en run-gestart draagt dat veld niet. De tijd van dít bericht
      // is het moment waarop wij de start gemeld hebben, en dat is wat wij kunnen weten.
      stand.run = { runId: b.runId, scenarioId: b.scenarioId, gestartOp: b.tijd };
      stand.afgerondeStappen = [];
      delete stand.lopendeStap;
      break;
    case 'stap-gestart':
      stand.lopendeStap = b.stapNummer;
      break;
    case 'stap-afgerond': {
      const stap = { stapNummer: b.stapNummer, uitkomst: b.uitkomst };
      if (b.bijzonderheden !== undefined) stap.bijzonderheden = b.bijzonderheden;
      stand.afgerondeStappen.push(stap);
      delete stand.lopendeStap;
      break;
    }
    case 'run-afgerond':
      delete stand.lopendeStap;
      break;
    default:
      // cli-uitvoer draagt geen toestand, en een onbekende soort uit een volgende versie
      // hoort de stand niet te raken.
      break;
  }
}

function verbind(verzoek, antwoord) {
  antwoord.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
    'Access-Control-Allow-Origin': data.origin,
  });

  const abonnee = { antwoord, hartslag: null };
  abonnees.add(abonnee);
  verzoek.on('close', () => {
    clearTimeout(abonnee.hartslag);
    abonnees.delete(abonnee);
  });

  // Loopt er een run, dan gaat de stand van die run mee. Loopt er niets, dan de opgenomen
  // regel met `run: null` — en dat is de normale begintoestand van een sessie.
  zend(abonnee, tolerantRegel(lopend ? JSON.stringify(lopend.stand) : IDLE));
}

// Het hele replaymechanisme: de regels van één opname, met dezelfde tussenpozen als de
// opname, naar iedereen die luistert. Het toetst niets en beslist niets.
function startRun() {
  const regels = toekomstig(RUNS[beurt % RUNS.length]);
  beurt += 1;

  // De eerste regel van een opname is de momentopname bij het verbinden. Er wordt nu één
  // keer verbonden en daarna vaker gestart, dus hier hoort hij niet meer in de stroom: hij
  // zou een `run: null` melden op het moment dat er net een run begon.
  const eerste = JSON.parse(regels[0]);
  const opening = eerste.soort === 'momentopname' ? regels[0] : IDLE;
  const stroom = eerste.soort === 'momentopname' ? regels.slice(1) : regels;

  lopend = { runId: runIdVan(regels), stand: beginStand(opening) };

  stroom.forEach((regel, i) => setTimeout(() => {
    abonnees.forEach((abonnee) => zend(abonnee, regel));
    // Bijwerken ná het zenden: de stand is een uitspraak over wat er verstuurd ís.
    werkBij(lopend.stand, JSON.parse(regel));
    if (i === stroom.length - 1) lopend = null;
  }, (i + 1) * TEMPO_MS));

  return lopend.runId;
}

// --- de server ---------------------------------------------------------------------------

function json(antwoord, status, body) {
  antwoord.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': data.origin,
  });
  antwoord.end(JSON.stringify(body));
}

http.createServer(async (verzoek, antwoord) => {
  const pad = verzoek.url.split('?')[0];

  if (verzoek.method === 'GET' && pad === data.streampad) return verbind(verzoek, antwoord);

  const route = routes.find((r) => r.methode === verzoek.method && r.patroon.test(pad));
  if (!route) {
    return json(antwoord, 404, {
      code: 'PAD_ONBEKEND',
      message: `${verzoek.method} ${pad} staat niet in het contract`,
    });
  }

  if (route.keur) {
    const ruw = await lees(verzoek);
    let body;
    try {
      body = JSON.parse(ruw);
    } catch {
      body = null;
    }
    if (!route.keur(body)) {
      return json(antwoord, 400, {
        code: 'VERZOEK_ONGELDIG',
        message: ajv.errorsText(route.keur.errors),
      });
    }
  }

  // Een route met een body per id bedient elk id met zijn eigen inhoud, en een id dat niet
  // bestaat met de 404 uit de spec. Tot bundel 0.11.1 was er één body voor alle id's: elke
  // scenarioId gaf scenario 01 terug, en een onbekend id gaf 200 in plaats van 404.
  if (route.bodyPerId) {
    const id = decodeURIComponent(pad.split('/').filter(Boolean).pop());
    const body = Object.prototype.hasOwnProperty.call(route.bodyPerId, id)
      ? route.bodyPerId[id]
      : null;
    if (!body) return json(antwoord, 404, route.fouten['404']);
    return json(antwoord, route.status, body);
  }

  if (route.operationId === 'startRun') {
    // "Er kan één run tegelijk lopen. Loopt er al een, dan levert dit een 409 met het runId
    // van die lopende run." De body is de example uit de spec; alleen het nummer erin wordt
    // dat van de run die echt loopt, want anders wijst het antwoord een andere run aan dan
    // de stream afspeelt. Het `Error`-schema heeft geen veld voor een runId — die staat in
    // de tekst, dus daar gebeurt het.
    if (lopend) {
      const voorbeeld = route.fouten['409'];
      return json(antwoord, 409, {
        ...voorbeeld,
        message: voorbeeld.message.split(route.body.runId).join(lopend.runId),
      });
    }

    // Het runId van de opname die nu begint. Het example in de spec is een voorbeeld en geen
    // voorschrift dat elk antwoord dat nummer draagt; de stub houdt hiermee zijn twee kanten
    // over dezelfde run aan het woord.
    const runId = startRun();
    return json(antwoord, route.status, { ...route.body, runId });
  }

  // Afbreken beantwoordt zijn eigen operatie en raakt de replay niet: de opname bepaalt hoe
  // een run eindigt. Wie een run wil zien die stopt, start `gestopt`.
  antwoord.writeHead(route.status, route.kopteksten);
  antwoord.end(route.body === null ? '' : JSON.stringify(route.body));
}).listen(POORT, () => {
  console.log(`stub van showcase-CBT luistert op http://localhost:${POORT}`);
  console.log(`  ${routes.length} operaties uit het contract`);
  console.log(`  scenario's uit de stamdata: ${Object.keys(SCENARIOS).join(', ') || 'geen'}`);
  console.log(`  stream op ${data.streampad} — blijft open, jij sluit hem`);
  console.log(`  POST /v1/runs start de volgende opname: ${NAMEN.join(', ')}`);
  console.log(`  hartslag na ${HARTSLAG_MS / 1000}s stilte`);
  if (TOLERANT) {
    console.log('  TOLERANTIE=ja — de stream stuurt een onbekend veld, een onbekend');
    console.log('    berichttype en een onbekende enum-waarde. Alle drie horen jouw');
    console.log('    client niet te breken. Zie README.md.');
  }
});
