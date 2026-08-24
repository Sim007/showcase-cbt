// De provider van showcase-CBT: scenario-api en run-stream, echt in plaats van nagebootst.
//
//   node server.js          luistert op 8090
//
// Tot 2026-08-21 bestond deze kant niet. Er waren twee gepubliceerde specs, drie uitgegeven
// versies en een bundel — en het enige dat ze serveerde was de stub. Zie docs/besluiten.md.
//
// --- Wat hij serveert -------------------------------------------------------------------
//
//   GET  /v1/scenarios           de lijst, uit de stamdata in deze image
//   GET  /v1/scenarios/{id}      één scenario, of 404 als het er niet is
//   GET  /v1/runs/stream         de stream; blijft open, de consumer sluit hem
//   POST /intern/gebeurtenis     wat stap() meldt, van de pipeline op de host
//
// `POST /v1/runs` hoort er nog niet bij. Dat is een bekende, benoemde afwijking en geen
// vergetelheid — zie O22 in docs/showcase-cbt.md.
//
// --- Waarom dit de machinerie van de stub dupliceert -------------------------------------
//
// SSE, de hartslag, de momentopname en de scenario's per id staan hier een tweede keer, en
// dat is een keuze. De stubbundel is een levering aan een andere squad met een eigen
// versielijn; een gedeelde library over die grens koppelt hun uitgave aan onze interne
// wijzigingen. Honderd regels dubbel is goedkoper dan die koppeling. Dezelfde reden waarom
// get-contract.sh niet wordt meegeleverd.
//
// --- Wat hij niet doet ------------------------------------------------------------------
//
// Hij verzint niets. De stand die bij het verbinden meegaat, is afgeleid uit wat hij zélf
// verstuurd heeft — nooit uit wat hij vermoedt. En hij stelt geen stapnummers vast op eigen
// gezag: die komen uit de stamdata, op omschrijving en op volgorde. Meldt de pipeline een
// stap die daar niet staat, dan draaide er iets anders dan beloofd, en dat hoort zichtbaar
// te zijn in plaats van weggenummerd.

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const HIER = __dirname;
const POORT = Number(process.env.POORT || 8090);
const HARTSLAG_MS = Number(process.env.HARTSLAG_MS || 20000);

const data = JSON.parse(fs.readFileSync(path.join(HIER, 'provider-data.json'), 'utf8'));

// De stamdata zit in de image en niet in een volume. Een scenario wijzigen is inhoud van de
// showcase: nieuwe stamdata, nieuwe opname, nieuwe uitgave. Monteren zou de inhoud onder een
// draaiende container laten veranderen zonder dat het versienummer meebeweegt.
const SCENARIOS = {};
for (const bestand of fs.readdirSync(path.join(HIER, 'scenarios'))) {
  if (!bestand.endsWith('.json')) continue;
  const s = JSON.parse(fs.readFileSync(path.join(HIER, 'scenarios', bestand), 'utf8'));
  SCENARIOS[s.id] = s;
}

const LIJST = Object.values(SCENARIOS)
  .sort((a, b) => a.id.localeCompare(b.id))
  .map(({ id, titel, ondertitel }) => ({ id, titel, ondertitel }));

// --- de stream ---------------------------------------------------------------------------

const abonnees = new Set();
let lopend = null;

// --- de runner, en waarom hij trekt in plaats van dat wij duwen ---------------------------
//
// De pipeline draait op de host en deze provider in een container. Duwen zou de Docker-socket
// vragen — root-equivalent — plus een mount van de repository, en dat zijn twee prijzen voor
// één functie. Dus draait het om: een klein bash-proces op de host haalt zijn werk hier op.
//
// Wat dat kost staat in O22: de 201 loopt tot een pollinterval voor op de werkelijkheid, en
// deze provider kan niet weten of er een runner luistert. Dat laatste is niet weg te poetsen
// maar wel te zien: elke keer dat de runner werk ophaalt, laat hij een spoor achter. Hoort
// deze provider al RUNNER_STIL_MS niets, dan weigert hij een start in plaats van hem aan te
// nemen en er niets mee te doen. Een knop die stil niets doet is erger dan een knop die zegt
// dat het nu niet kan.
const RUNNER_STIL_MS = Number(process.env.RUNNER_STIL_MS || 5000);
let laatsteRunnerPoll = 0;

// Een aanvraag doorloopt drie toestanden, en dat zijn er drie omdat twee te weinig bleek.
//
//   werk        aangevraagd, nog niet opgehaald
//   uitgegeven  aan een runner meegegeven, wachtend op het eerste bericht
//   lopend      de gebeurtenissen komen binnen
//
// **Waarom `uitgegeven` er apart bij hoort.** In de eerste versie werd het werk pas gewist
// zodra `run-gestart` binnenkwam. Een scenario dat nog geen gebeurtenissen zendt liet het dus
// staan, en de runner haalde hetzelfde werk elke seconde opnieuw op — hij draaide scenario 01
// twee keer achter elkaar en zou zijn doorgegaan. Gemeten, niet bedacht.
//
// Ophalen wist het werk nu meteen. En omdat er tussen ophalen en het eerste bericht een gat
// zit — de demo ruimt eerst op, dat duurt tientallen seconden — moet die tussentoestand
// zichtbaar blijven, anders neemt een tweede druk op de knop de plek in van een run die al
// onderweg is.
const UITGEGEVEN_MAX_MS = Number(process.env.UITGEGEVEN_MAX_MS || 300000);
let werk = null;
let uitgegeven = null;

// Een runner die omvalt tussen ophalen en starten zou de provider anders blijvend bezet
// houden. Dit is geen herstel maar een vangnet: na de grens is de plek weer vrij.
function uitgegevenVerlopen() {
  if (!uitgegeven) return false;
  if (Date.now() - uitgegeven.gezet <= UITGEGEVEN_MAX_MS) return false;
  uitgegeven = null;
  return true;
}

function hartslagOpnieuw(abonnee) {
  clearTimeout(abonnee.hartslag);
  abonnee.hartslag = setTimeout(() => {
    abonnee.antwoord.write(': hartslag\n\n');
    hartslagOpnieuw(abonnee);
  }, HARTSLAG_MS);
}

function zendAan(abonnee, bericht) {
  abonnee.antwoord.write(`data: ${JSON.stringify(bericht)}\n\n`);
  hartslagOpnieuw(abonnee);
}

function zend(bericht) {
  abonnees.forEach((abonnee) => zendAan(abonnee, bericht));
  if (lopend) werkBij(lopend.stand, bericht);
}

// De stand van de lopende run, uitsluitend afgeleid uit wat er verstuurd is.
function werkBij(stand, b) {
  stand.tijd = b.tijd;
  switch (b.soort) {
    case 'run-gestart':
      stand.run = { runId: b.runId, scenarioId: b.scenarioId, gestartOp: b.tijd };
      stand.afgerondeStappen = [];
      delete stand.lopendeStap;
      break;
    case 'stap-gestart':
      stand.lopendeStap = b.stapNummer;
      break;
    case 'stap-afgerond':
      stand.afgerondeStappen.push({ stapNummer: b.stapNummer, uitkomst: b.uitkomst });
      delete stand.lopendeStap;
      break;
    case 'run-afgerond':
      delete stand.lopendeStap;
      break;
    default:
      break;
  }
}

function momentopname() {
  if (lopend) return lopend.stand;
  return {
    soort: 'momentopname',
    tijd: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
    run: null,
    afgerondeStappen: [],
  };
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

  zendAan(abonnee, momentopname());
}

// --- van kale gebeurtenis naar bericht ---------------------------------------------------
//
// De pipeline meldt omschrijving en uitkomst en verder niets. Hier komt de contractvorm
// erbij, en dat is met opzet de enige plek: zou stap() al berichten schrijven, dan reikt een
// wijziging aan run-stream tot in de pipeline en zit een grens vast aan tools.sh.

function nieuwRunId() {
  return `run-${crypto.randomBytes(3).toString('hex')}`;
}

function volgendeStap(omschrijving) {
  const stappen = lopend.scenario.stappen;
  for (let i = lopend.wijzer; i < stappen.length; i += 1) {
    if (stappen[i].omschrijving === omschrijving) {
      lopend.wijzer = i + 1;
      return stappen[i];
    }
  }
  return null;
}

function verwerk(g) {
  const tijd = g.tijd || new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

  if (g.soort === 'run-gestart') {
    const scenario = SCENARIOS[g.scenarioId];
    if (!scenario) return { fout: `scenario ${g.scenarioId} staat niet in deze provider` };

    // Is deze run via POST /v1/runs aangevraagd, dan heeft de aanroeper dat nummer al in
    // handen: hij kreeg het in de 201. Een tweede nummer munten zou betekenen dat het
    // antwoord op de knop een andere run aanwijst dan de stream afspeelt.
    const runId = (uitgegeven && uitgegeven.scenarioId === g.scenarioId && uitgegeven.runId)
      || g.runId || nieuwRunId();
    uitgegeven = null;
    lopend = {
      scenario,
      wijzer: 0,
      huidig: null,
      stand: { soort: 'momentopname', tijd, run: null, afgerondeStappen: [] },
    };
    zend({ soort: 'momentopname', tijd, run: null, afgerondeStappen: [] });
    zend({ soort: 'run-gestart', tijd, runId, scenarioId: scenario.id });
    lopend.runId = runId;
    return { runId };
  }

  if (!lopend) return { fout: 'er loopt geen run' };

  switch (g.soort) {
    case 'stap-gestart': {
      const stap = volgendeStap(g.omschrijving);
      if (!stap) return { fout: `stap "${g.omschrijving}" staat niet in de stamdata van ${lopend.scenario.id}` };
      lopend.huidig = stap;
      zend({ soort: 'stap-gestart', tijd, runId: lopend.runId, stapNummer: stap.nummer });
      zend({ soort: 'cli-uitvoer', tijd, runId: lopend.runId, stapNummer: stap.nummer, regel: `$ ${stap.cli}` });
      return { stapNummer: stap.nummer };
    }
    case 'uitvoer':
      if (!lopend.huidig) return { fout: 'uitvoer zonder lopende stap' };
      zend({ soort: 'cli-uitvoer', tijd, runId: lopend.runId, stapNummer: lopend.huidig.nummer, regel: g.regel });
      return { stapNummer: lopend.huidig.nummer };
    case 'stap-afgerond':
      if (!lopend.huidig) return { fout: 'stap-afgerond zonder lopende stap' };
      zend({ soort: 'stap-afgerond', tijd, runId: lopend.runId, stapNummer: lopend.huidig.nummer, uitkomst: g.uitkomst });
      return { stapNummer: lopend.huidig.nummer };
    case 'run-afgerond': {
      const bericht = { soort: 'run-afgerond', tijd, runId: lopend.runId, reden: g.reden };
      if (g.reden === 'gestopt' && lopend.huidig) bericht.gestoptBijStap = lopend.huidig.nummer;
      zend(bericht);
      lopend = null;
      return { klaar: true };
    }
    default:
      return { fout: `onbekende gebeurtenis ${g.soort}` };
  }
}

// --- de server ---------------------------------------------------------------------------

function json(antwoord, status, body) {
  antwoord.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': data.origin,
  });
  antwoord.end(JSON.stringify(body));
}

function lees(verzoek) {
  return new Promise((klaar) => {
    let ruw = '';
    verzoek.on('data', (stuk) => (ruw += stuk));
    verzoek.on('end', () => klaar(ruw));
  });
}

http.createServer(async (verzoek, antwoord) => {
  const pad = verzoek.url.split('?')[0];

  if (verzoek.method === 'GET' && pad === '/v1/runs/stream') return verbind(verzoek, antwoord);

  if (verzoek.method === 'GET' && pad === '/v1/scenarios') {
    return json(antwoord, 200, LIJST);
  }

  if (verzoek.method === 'GET' && pad.startsWith('/v1/scenarios/')) {
    // Nooit een pad samenstellen uit wat er binnenkomt: eerst tegen het patroon uit de spec,
    // daarna tegen wat deze provider werkelijk draagt. Een opzoeking in een object dat we
    // zelf hebben gevuld, en geen bestandsnaam.
    const id = decodeURIComponent(pad.slice('/v1/scenarios/'.length));
    if (!/^[0-9]{2}$/.test(id) || !Object.prototype.hasOwnProperty.call(SCENARIOS, id)) {
      // Het nummer in de tekst wordt dat van het verzoek. Een 404 die "er is geen scenario
      // met id 42" zegt terwijl er om 07 gevraagd is, beweert iets anders dan er gebeurt.
      const voorbeeld = data.fouten.scenarioOnbekend;
      const gevonden = voorbeeld.message.match(/\b\d{2,}\b/);
      return json(antwoord, 404, {
        ...voorbeeld,
        message: gevonden ? voorbeeld.message.split(gevonden[0]).join(id) : voorbeeld.message,
      });
    }
    return json(antwoord, 200, SCENARIOS[id]);
  }

  if (verzoek.method === 'POST' && pad === '/v1/runs') {
    let body;
    try {
      body = JSON.parse(await lees(verzoek));
    } catch {
      return json(antwoord, 400, { code: 'VERZOEK_ONGELDIG', message: 'geen geldige JSON' });
    }

    // Eerste van twee controles op het scenario-id, en ze staan los van elkaar met opzet: de
    // runner doet hem straks opnieuw. Eerst het patroon uit de spec, dan of dít exemplaar het
    // scenario werkelijk draagt. Een opzoeking in een object dat we zelf hebben gevuld, nooit
    // een pad dat uit de invoer wordt samengesteld.
    const id = String((body || {}).scenarioId || '');
    if (!/^[0-9]{2}$/.test(id) || !Object.prototype.hasOwnProperty.call(SCENARIOS, id)) {
      return json(antwoord, 404, data.fouten.scenarioOnbekend);
    }

    // "Er kan één run tegelijk lopen." Deze provider weet dat werkelijk, want hij ontvangt de
    // gebeurtenissen — het is geen nabootsing.
    uitgegevenVerlopen();
    if (lopend || werk || uitgegeven) {
      const bezet = (lopend && lopend.runId) || (werk && werk.runId) || (uitgegeven && uitgegeven.runId);
      const bezetScenario = (lopend && lopend.scenario && lopend.scenario.id)
        || (werk && werk.scenarioId) || (uitgegeven && uitgegeven.scenarioId);
      const voorbeeld = data.fouten.runLooptAl;
      // Zowel het nummer als het scenario worden die van de run die écht loopt. Alleen het
      // runId vervangen liet de tekst "loopt nog voor scenario 01" staan terwijl 00 draaide —
      // dezelfde soort onwaarheid, een veld verderop.
      return json(antwoord, 409, {
        ...voorbeeld,
        message: voorbeeld.message
          .split(data.voorbeeldRunId).join(bezet)
          .split(`scenario ${data.voorbeeldScenarioId}`).join(`scenario ${bezetScenario}`),
      });
    }

    // De 503 staat niet in de spec en is een benoemde afwijking — zie O22. Er is daar geen
    // status voor "er is niemand die dit kan uitvoeren", en de knop stil aannemen is de
    // slechtste van de mogelijkheden.
    if (Date.now() - laatsteRunnerPoll > RUNNER_STIL_MS) {
      return json(antwoord, 503, {
        code: 'GEEN_RUNNER',
        message: 'er luistert geen runner op deze machine; start ci/runner.sh',
      });
    }

    const runId = nieuwRunId();
    werk = { scenarioId: id, runId, gezet: Date.now() };
    return json(antwoord, 201, {
      runId,
      scenarioId: id,
      gestartOp: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
    });
  }

  // De runner haalt hier zijn werk op, en laat met elke aanroep zien dat hij luistert.
  if (verzoek.method === 'GET' && pad === '/intern/werk') {
    laatsteRunnerPoll = Date.now();
    if (!werk) return json(antwoord, 200, { werk: null });

    // Eén keer uitgeven en niet één keer per seconde. Wat hier weggaat is weg; de plek blijft
    // bezet tot het eerste bericht binnenkomt of de vangnetgrens verstrijkt.
    uitgegeven = { ...werk, gezet: Date.now() };
    werk = null;
    return json(antwoord, 200, { werk: { scenarioId: uitgegeven.scenarioId, runId: uitgegeven.runId } });
  }

  if (verzoek.method === 'POST' && pad === '/intern/gebeurtenis') {
    let g;
    try {
      g = JSON.parse(await lees(verzoek));
    } catch {
      return json(antwoord, 400, { code: 'VERZOEK_ONGELDIG', message: 'geen geldige JSON' });
    }
    const uitkomst = verwerk(g);
    if (uitkomst.fout) return json(antwoord, 409, { code: 'GEBEURTENIS_ONGELDIG', message: uitkomst.fout });
    return json(antwoord, 202, uitkomst);
  }

  return json(antwoord, 404, {
    code: 'PAD_ONBEKEND',
    message: `${verzoek.method} ${pad} staat niet in het contract`,
  });
}).listen(POORT, () => {
  console.log(`provider van showcase-CBT luistert op http://localhost:${POORT}`);
  console.log(`  scenario's uit de stamdata: ${Object.keys(SCENARIOS).join(', ')}`);
  console.log(`  stream op /v1/runs/stream — blijft open, jij sluit hem`);
  console.log(`  hartslag na ${HARTSLAG_MS / 1000}s stilte`);
  console.log(`  POST /v1/runs ontbreekt in deze versie — zie O22`);
});
