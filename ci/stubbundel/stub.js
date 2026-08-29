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

// De stamdata, uit `scenarios/` en niet uit `stub-data.json`. Ze stond er tot 0.14.0 twee
// keer in: als bestand én ingebakken in de routes. Eén bron, en het is deze — dezelfde plek
// waar de provider hem ook leest.
const SCENARIOS = {};
for (const bestand of fs.readdirSync(path.join(HIER, 'scenarios'))) {
  if (!bestand.endsWith('.json')) continue;
  const s = JSON.parse(fs.readFileSync(path.join(HIER, 'scenarios', bestand), 'utf8'));
  SCENARIOS[s.id] = s;
}

// --- welke run er bij welk scenario hoort -------------------------------------------------
//
// Tot 0.14.0 roteerde de stub over drie vaste namen, ongeacht welk scenario je startte. Twee
// gevolgen die squad 2 heeft gemeld: een start op scenario 00 speelde de run van 01, en de
// twee échte opnames die de bundel draagt werden nooit gespeeld — de bundel negeerde zijn
// eigen materiaal.
//
// Nu kiest hij op `scenarioId`, en binnen een scenario staat de **opname vooraan**: dat is
// een echte run, en wie op de knop drukt hoort die het eerst te zien. Wat erachter staat zijn
// de afgeleide verlopen, en daar zit de gestopte run bij — die heeft de consumer het hardst
// nodig, want daarin krijgt een deelsysteem dat nooit aan de beurt kwam geen enkel bericht.
function laad(bestand) {
  return fs.readFileSync(path.join(HIER, 'runs', bestand), 'utf8').trim().split('\n');
}

// Welk verloop bij welk scenario hoort staat in het manifest en niet in deze code. De
// herkomst van de ongenummerde verlopen — afgeleid, en van welk scenario — is anders alleen
// uit een bestandsnaam af te lezen, en een bestandsnaam is geen bewering die iemand kan
// controleren.
const manifest = JSON.parse(fs.readFileSync(path.join(HIER, 'manifest.json'), 'utf8'));

const VERLOPEN = {};
function voegToe(id, bestand) {
  if (!SCENARIOS[id]) return;
  if (!VERLOPEN[id]) VERLOPEN[id] = { namen: [], runs: [], beurt: 0 };
  VERLOPEN[id].namen.push(bestand);
  VERLOPEN[id].runs.push(laad(bestand));
}

// De opname eerst: dat is een echte run, en wie op de knop drukt hoort die het eerst te zien.
for (const o of manifest.opnames || []) voegToe(o.scenarioId, path.basename(o.bestand));
for (const a of manifest.afgeleid || []) voegToe(a.scenarioId, path.basename(a.bestand));

// Elk verloop dat de bundel draagt moet ook te spelen zijn. Tot 0.14.0 droeg hij twee echte
// opnames en speelde ze niet — hij negeerde zijn eigen materiaal, en dat viel niet op omdat
// wij tegen de provider toetsen en niet tegen de stub. Deze controle maakt dat onmogelijk:
// een bestand dat nergens in het manifest staat, laat de stub niet starten.
const GEDEKT = new Set(Object.values(VERLOPEN).flatMap((v) => v.namen));
for (const bestand of fs.readdirSync(path.join(HIER, 'runs'))) {
  if (!bestand.endsWith('.jsonl')) continue;
  if (!GEDEKT.has(bestand)) {
    throw new Error(`runs/${bestand} staat niet in het manifest en wordt dus nooit gespeeld`);
  }
}

const RUNS = Object.values(VERLOPEN).reduce((alles, v) => alles.concat(v.runs), []);

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

// --- foutteksten die over de werkelijkheid gaan ------------------------------------------
//
// De `code` en de zin komen uit de spec; het nummer erin niet. Een 404 die "er is geen
// scenario met id 42" zegt terwijl er om 07 gevraagd is, beweert iets anders dan er gebeurt —
// dezelfde soort onwaarheid als een 409 die het verkeerde runId noemt.
//
// Het schema van `Error` heeft geen veld voor dat nummer: het staat in de tekst. Vandaar deze
// vervanging en niet een eigen zin — de formulering blijft van de spec, alleen de waarde
// wordt die van het verzoek. Staat er geen nummer in de tekst, dan blijft hij zoals hij is.
function metWaarde(bericht, patroon, waarde) {
  const gevonden = bericht.match(patroon);
  return gevonden ? bericht.split(gevonden[0]).join(waarde) : bericht;
}

const RUNID_IN_TEKST = /run-[0-9a-f]{6}/;
const ID_IN_TEKST = /\b\d{2,}\b/;

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
function startRun(scenarioId) {
  const verloop = VERLOPEN[scenarioId];
  const regels = toekomstig(verloop.runs[verloop.beurt % verloop.runs.length]);
  verloop.beurt += 1;

  // De eerste regel van een opname is de momentopname bij het verbinden. Er wordt nu één
  // keer verbonden en daarna vaker gestart, dus hier hoort hij niet meer in de stroom: hij
  // zou een `run: null` melden op het moment dat er net een run begon.
  const eerste = JSON.parse(regels[0]);
  const opening = eerste.soort === 'momentopname' ? regels[0] : IDLE;
  const stroom = eerste.soort === 'momentopname' ? regels.slice(1) : regels;

  // De tijdstippen worden bewaard omdat een run afgebroken moet kunnen worden. Zonder deze
  // lijst liep de replay door nadat afbreken 202 had gemeld, en gaf elke volgende start
  // RUN_LOOPT_AL — het antwoord zei iets anders dan er gebeurde.
  lopend = { runId: runIdVan(regels), scenarioId, stand: beginStand(opening), timers: [] };

  stroom.forEach((regel, i) => lopend.timers.push(setTimeout(() => {
    abonnees.forEach((abonnee) => zend(abonnee, regel));
    // Bijwerken ná het zenden: de stand is een uitspraak over wat er verstuurd ís.
    werkBij(lopend.stand, JSON.parse(regel));
    if (i === stroom.length - 1) lopend = null;
  }, (i + 1) * TEMPO_MS)));

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

  let body = null;
  if (route.keur) {
    const ruw = await lees(verzoek);
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

  // Elk scenario zijn eigen inhoud, uit de stamdata, en een id dat niet bestaat de 404 uit de
  // spec. Tot bundel 0.11.1 was er één body voor alle id's: elke scenarioId gaf scenario 01.
  if (route.operationId === 'haalScenario') {
    const id = decodeURIComponent(pad.split('/').filter(Boolean).pop());
    if (!/^[0-9]{2}$/.test(id) || !Object.prototype.hasOwnProperty.call(SCENARIOS, id)) {
      const voorbeeld = route.fouten['404'];
      return json(antwoord, 404, {
        ...voorbeeld,
        message: metWaarde(voorbeeld.message, ID_IN_TEKST, id),
      });
    }
    return json(antwoord, route.status, SCENARIOS[id]);
  }

  // Wie hier staat, en waar wat je ziet vandaan komt. `bron: opname` — deze stub speelt
  // vastgelegd materiaal af. Dat is geen bekentenis maar de hele reden dat dit veld bestaat:
  // er stond vijf dagen een stub op de poort van de echte kant en niemand kon het zien.
  if (route.operationId === 'haalInfo') {
    return json(antwoord, route.status, {
      naam: 'stubbundel van showcase-CBT',
      versie: manifest.bundelversie,
      bron: 'opname',
      serveert: manifest.specs.map(({ artifact, versie }) => ({ artifact, versie })),
    });
  }

  if (route.operationId === 'lijstScenarios') {
    return json(antwoord, route.status, Object.values(SCENARIOS)
      .sort((a, b) => a.id.localeCompare(b.id))
      .map(({ id, titel, ondertitel }) => ({ id, titel, ondertitel })));
  }

  if (route.operationId === 'startRun') {
    // "Er kan één run tegelijk lopen. Loopt er al een, dan levert dit een 409 met het runId
    // van die lopende run." De body is de example uit de spec; alleen het nummer erin wordt
    // dat van de run die echt loopt, want anders wijst het antwoord een andere run aan dan
    // de stream afspeelt. Het `Error`-schema heeft geen veld voor een runId — die staat in
    // de tekst, dus daar gebeurt het.
    // Welk scenario er gestart wordt, bepaalt wat er speelt. Tot 0.14.0 roteerde de stub over
    // drie vaste verlopen ongeacht het id: een start op 00 speelde de run van 01, en de twee
    // échte opnames die de bundel draagt kwamen nooit aan de beurt.
    //
    // Eerst de invoer en dan pas de toestand: een verzoek om een scenario dat niet bestaat is
    // fout ongeacht of er iets loopt. Zelfde volgorde als in de provider.
    const id = String((body || {}).scenarioId || '');
    if (!/^[0-9]{2}$/.test(id) || !VERLOPEN[id]) {
      return json(antwoord, 404, routes.find((r) => r.operationId === 'haalScenario').fouten['404']);
    }

    if (lopend) {
      const voorbeeld = route.fouten['409'];
      return json(antwoord, 409, {
        ...voorbeeld,
        message: voorbeeld.message
          .split(route.body.runId).join(lopend.runId)
          .split(`scenario ${route.body.scenarioId}`).join(`scenario ${lopend.scenarioId}`),
      });
    }

    // Het runId van de opname die nu begint. Het example in de spec is een voorbeeld en geen
    // voorschrift dat elk antwoord dat nummer draagt; de stub houdt hiermee zijn twee kanten
    // over dezelfde run aan het woord.
    const runId = startRun(id);
    return json(antwoord, route.status, { ...route.body, runId, scenarioId: id });
  }

  // Afbreken brak niets af. Er was geen tak voor, dus viel het door naar het generieke pad:
  // 202 met de voorbeeldbody uit de spec — die een ánder runId noemt dan er in het pad staat —
  // terwijl de replay gewoon doorliep, zodat elke volgende start RUN_LOOPT_AL gaf. Gemeld door
  // squad 2, en het is dezelfde vorm als de startbug: het voorbeeld teruggeven in plaats van
  // de werkelijkheid.
  if (route.operationId === 'breekRunAf') {
    const id = decodeURIComponent(pad.split('/').filter(Boolean)[2] || '');

    if (!lopend || lopend.runId !== id) {
      // Kent de stub dit nummer wél, maar loopt het niet? Dan is de run afgerond en niet
      // onbekend. Dat onderscheid staat in de spec en de stub kan het maken, want hij kent
      // alle nummers die hij kan spelen.
      const bestaat = Object.values(VERLOPEN)
        .some((v) => v.runs.some((regels) => runIdVan(regels) === id));
      const status = bestaat ? 409 : 404;
      const voorbeeld = route.fouten[String(status)];
      return json(antwoord, status, {
        ...voorbeeld,
        message: metWaarde(voorbeeld.message, RUNID_IN_TEKST, id),
      });
    }

    // "Het antwoord zegt dat het verzoek is aangenomen, niet dat de run al stil staat. Dat
    // laatste blijkt uit run-afgerond op de stream, met reden afgebroken."
    lopend.timers.forEach(clearTimeout);
    const stil = lopend;
    lopend = null;

    const tijd = stil.stand.tijd;
    const bericht = { soort: 'run-afgerond', tijd, runId: stil.runId, reden: 'afgebroken' };
    abonnees.forEach((abonnee) => zend(abonnee, tolerantRegel(JSON.stringify(bericht))));

    return json(antwoord, route.status, {
      ...route.body,
      runId: stil.runId,
      scenarioId: stil.scenarioId,
    });
  }

  antwoord.writeHead(route.status, route.kopteksten);
  antwoord.end(route.body === null ? '' : JSON.stringify(route.body));
}).listen(POORT, () => {
  console.log(`stub van showcase-CBT luistert op http://localhost:${POORT}`);
  console.log(`  ${routes.length} operaties uit het contract`);
  console.log(`  scenario's uit de stamdata: ${Object.keys(SCENARIOS).join(', ') || 'geen'}`);
  console.log(`  stream op ${data.streampad} — blijft open, jij sluit hem`);
  for (const [id, v] of Object.entries(VERLOPEN)) {
    console.log(`  POST /v1/runs {"scenarioId":"${id}"} — ${v.namen.join(', ')}`);
  }
  console.log(`  hartslag na ${HARTSLAG_MS / 1000}s stilte`);
  if (TOLERANT) {
    console.log('  TOLERANTIE=ja — de stream stuurt een onbekend veld, een onbekend');
    console.log('    berichttype en een onbekende enum-waarde. Alle drie horen jouw');
    console.log('    client niet te breken. Zie README.md.');
  }
});
