import { test, expect } from '@playwright/test';

/**
 * De gebruikersflow op Acceptatie. Deze bestond al vóór contracttesten — hij hoort bij de
 * startsituatie en niet bij wat CBT toevoegt.
 *
 * Wat CBT eraan verandert is niet dát hij er is maar hoe **klein** hij mag zijn. De
 * structuur van de grens is al aangetoond bij de contractverificatie: velden, typen,
 * statuscodes, foutmodel. Wat overblijft is de vraag of de keten doet wat een gebruiker
 * verwacht — en dat is één scenario, geen tien.
 *
 * Het label bepaalt bij welke deploy hij draait. Deployt Payment, dan draaien de flows die
 * Payment raken; de rest is door die deploy niet aangeroerd.
 */

test('een bestelling wordt betaald en bevestigd @order @payment', async ({ request }) => {
  const geplaatst = await request.post('/orders', {
    data: { amount: 49.95, currency: 'EUR' },
  });
  expect(geplaatst.status()).toBe(201);

  const bestelling = await geplaatst.json();

  // Hier gaat het wél over inhoud, anders dan bij de smoke: dit is de uitkomst die een
  // gebruiker verwacht te zien.
  expect(bestelling.status).toBe('CONFIRMED');

  const bevestiging = await request.get(`/orders/${bestelling.orderId}`);
  expect(bevestiging.status()).toBe(200);
  expect((await bevestiging.json()).status).toBe('CONFIRMED');
});
