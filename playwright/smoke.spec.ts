import { test, expect } from '@playwright/test';

/**
 * De gedeelde smoke. Eén spec, op een base-URL geparametriseerd, voor elke omgeving:
 * op Test tegen de echte keten, op Acceptatie tegen dezelfde keten met de buitenwereld
 * eraan. Ook een CI-omgeving met een stub erin kan hem draaien.
 *
 * **De smoke gaat niet over inhoud.** Hij toetst uitsluitend HTTP-status en of de keten
 * wordt doorlopen — geen veldwaarden, geen businessregels. Zou hij dat wel doen, dan
 * draait hij groen tegen de stub en rood tegen de echte buur om een reden die niets met
 * de grens te maken heeft. En hij verhuist werk van een goedkope laag naar een dure: de
 * structuur van de grens is al aangetoond bij de contractverificatie.
 */

test('Order is bereikbaar', async ({ request }) => {
  const antwoord = await request.get('/actuator/health');
  expect(antwoord.status()).toBe(200);
});

test('een bestelling doorloopt de keten', async ({ request }) => {
  const aangemaakt = await request.post('/orders', {
    data: { amount: 49.95, currency: 'EUR' },
  });
  expect(aangemaakt.status()).toBe(201);

  const bestelling = await aangemaakt.json();

  // Het bestaan van een paymentId is het bewijs dat de buur heeft geantwoord — welke
  // waarde erin staat, is niet aan de smoke.
  expect(bestelling.orderId).toBeTruthy();
  expect(bestelling.paymentId).toBeTruthy();

  const opgevraagd = await request.get(`/orders/${bestelling.orderId}`);
  expect(opgevraagd.status()).toBe(200);
});

test('een onbekende bestelling levert een 404', async ({ request }) => {
  const antwoord = await request.get('/orders/ord-00000');
  expect(antwoord.status()).toBe(404);
});
