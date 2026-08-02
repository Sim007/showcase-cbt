import { test, expect } from '@playwright/test';

/**
 * De smoke over alle grenzen. Deze is van de tribe en niet van één squad — daarom staat
 * hij hier en niet bij een deelsysteem.
 *
 * Hij hangt níét aan een deploy. Een deploy van Order zegt iets over Order; deze run zegt
 * iets over de samenstelling, en die verandert ook als er niets gedeployd wordt. Daarom
 * draait hij gepland, bijvoorbeeld 's nachts.
 *
 * Ook hier: status en het doorlopen van de keten, geen inhoud.
 */

test('de keten Order naar Payment loopt', async ({ request }) => {
  const aangemaakt = await request.post('/orders', {
    data: { amount: 49.95, currency: 'EUR' },
  });
  expect(aangemaakt.status()).toBe(201);

  const bestelling = await aangemaakt.json();
  expect(bestelling.paymentId).toBeTruthy();
});
