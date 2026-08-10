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

const http = require('http');
const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const HIER = __dirname;
const POORT = Number(process.env.POORT || 8090);
const data = JSON.parse(fs.readFileSync(path.join(HIER, 'stub-data.json'), 'utf8'));

const ajv = new Ajv({ strict: false, allErrors: true });
addFormats(ajv);

// Elke route krijgt zijn eigen validator, of null als er geen body verwacht wordt.
const routes = data.routes.map((r) => ({
  ...r,
  patroon: new RegExp(r.patroon),
  keur: r.verzoekSchema ? ajv.compile({ ...data.componenten, ...r.verzoekSchema }) : null,
}));

// De drie fixtures, om en om bij elke verbinding — net als de WireMock-stub. Zo komt de
// gestopte run vanzelf aan de beurt, en die heeft de consumer het hardst nodig.
const RUNS = ['voltooid', 'gestopt', 'midden'].map((naam) =>
  fs.readFileSync(path.join(HIER, 'runs', `${naam}.jsonl`), 'utf8').trim().split('\n')
);
let beurt = 0;

// TOLERANTIE=ja stuurt wat een volgende contractversie zou kunnen sturen. Niet omdat 1.0.0
// dat doet, maar omdat een stub die alleen de huidige versie spreekt een tolerantiefout
// niet kán tonen: alles past, dus alles lijkt goed — tot de eerste additieve wijziging.
//
// Alle drie de vormen tegelijk, want een schakelaar die een derde van de belofte toetst en
// groen meldt is hetzelfde patroon als een lus die na één bericht stopt.
const TOLERANT = process.env.TOLERANTIE === 'ja';

function toekomstig(regels) {
  if (!TOLERANT) return regels;

  const uit = regels.map((regel) => {
    const b = JSON.parse(regel);
    b.herkomst = 'toekomstige-versie';                       // 1 — onbekend veld
    if (b.soort === 'run-afgerond' && b.reden === 'gestopt') {
      b.reden = 'gestopt-door-beheerder';                    // 3 — onbekende enum-waarde
    }
    return JSON.stringify(b);
  });

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

// De stream: één bericht per SSE-event, met dezelfde tussenpozen als de opname. Dit is het
// hele replaymechanisme — het toetst niets en beslist niets.
function stream(antwoord) {
  const regels = toekomstig(RUNS[beurt++ % RUNS.length]);
  antwoord.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
    'Access-Control-Allow-Origin': data.origin,
  });
  regels.forEach((regel, i) => setTimeout(() => {
    antwoord.write(`data: ${regel}\n\n`);
    if (i === regels.length - 1) antwoord.end();
  }, i * 400));
}

http.createServer(async (verzoek, antwoord) => {
  const pad = verzoek.url.split('?')[0];

  if (verzoek.method === 'GET' && pad === data.streampad) return stream(antwoord);

  const route = routes.find((r) => r.methode === verzoek.method && r.patroon.test(pad));
  if (!route) {
    antwoord.writeHead(404, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': data.origin,
    });
    return antwoord.end(JSON.stringify({
      code: 'PAD_ONBEKEND',
      message: `${verzoek.method} ${pad} staat niet in het contract`,
    }));
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
      antwoord.writeHead(400, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': data.origin,
      });
      return antwoord.end(JSON.stringify({
        code: 'VERZOEK_ONGELDIG',
        message: ajv.errorsText(route.keur.errors),
      }));
    }
  }

  antwoord.writeHead(route.status, route.kopteksten);
  antwoord.end(route.body === null ? '' : JSON.stringify(route.body));
}).listen(POORT, () => {
  console.log(`stub van showcase-CBT luistert op http://localhost:${POORT}`);
  console.log(`  ${routes.length} operaties uit het contract`);
  console.log(`  stream op ${data.streampad} — drie fixtures, om en om per verbinding`);
  if (TOLERANT) {
    console.log('  TOLERANTIE=ja — de stream stuurt een onbekend veld, een onbekend');
    console.log('    berichttype en een onbekende enum-waarde. Alle drie horen jouw');
    console.log('    client niet te breken. Zie README.md.');
  }
});
