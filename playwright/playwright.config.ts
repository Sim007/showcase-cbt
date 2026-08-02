import { defineConfig } from '@playwright/test';

// Eén configuratie voor alle omgevingen. Wat verschilt is de base-URL, en die komt van
// buiten: ci/smoke.sh <base-url> is het enige aanroeppunt.
//
// Geen browsers: de smoke praat HTTP en heeft er geen nodig. Dat scheelt een image van
// ruim twee gigabyte, en laptopbudget is een ontwerpeis. Hoofdstuk 8 heeft ze wel nodig;
// dan komt daar een tweede project bij, niet een zwaardere basis voor iedereen.
export default defineConfig({
  testDir: '.',
  // Een smoke die tweemaal moet draaien om groen te worden, verbergt een probleem.
  retries: 0,
  reporter: process.env.CI ? [['list'], ['junit', { outputFile: '../build/smoke-rapport/junit.xml' }]]
                           : [['list']],
  use: {
    baseURL: process.env.SMOKE_BASE_URL,
    extraHTTPHeaders: { 'Content-Type': 'application/json' },
  },
});
