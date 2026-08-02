import { test, expect } from '@playwright/test';

/**
 * De smoke van het deelsysteem Payment. Van de squad die Payment bezit.
 *
 * Payment heeft binnen deze scope geen buren, dus hier is geen keten te doorlopen: de
 * vraag is of het deelsysteem omhoog komt en zijn grens bedient. Wát hij precies antwoordt
 * is al aangetoond bij de contractverificatie en hoort hier niet nog eens.
 */

test('Payment is bereikbaar', async ({ request }) => {
  const antwoord = await request.get('/actuator/health');
  expect(antwoord.status()).toBe(200);
});

test('de grens bedient een betaling', async ({ request }) => {
  const aangemaakt = await request.post('/v1/payments', {
    data: { orderId: 'ord-smoke', amount: 49.95, currency: 'EUR' },
  });
  expect(aangemaakt.status()).toBe(201);

  const betaling = await aangemaakt.json();
  expect(betaling.paymentId).toBeTruthy();

  const opgevraagd = await request.get(`/v1/payments/${betaling.paymentId}`);
  expect(opgevraagd.status()).toBe(200);
});
