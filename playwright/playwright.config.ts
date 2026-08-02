import { defineConfig } from '@playwright/test';

// Eén configuratie voor alle omgevingen en alle specs. Wat verschilt is de base-URL, en
// die komt van buiten: ci/smoke.sh is het enige aanroeppunt.
//
// Twee projecten, en het verschil is eigenaarschap:
//
//   deelsysteem     de smoke van één deelsysteem, in deelsystemen/<naam>/smoke/, van de squad
//   keten           de smoke over alle grenzen, hier, van de tribe
//   gebruikersflow  wat een gebruiker doet, op Acceptatie, met een label per deelsysteem
//
// De specs van de squads staan bij hun deelsysteem en worden hier alleen opgehaald — geen
// kopie. Zo is er één plek om alles te draaien en te zien, staat elke spec bij zijn
// eigenaar, en is er niets dat kan gaan afwijken.
//
// Geen browsers: deze specs praten HTTP en de officiële Playwright-image is ruim twee
// gigabyte. Laptopbudget is een ontwerpeis. Hoofdstuk 8 heeft browsers wél nodig en krijgt
// daar een eigen opzet voor.
export default defineConfig({
  // Een smoke die tweemaal moet draaien om groen te worden, verbergt een probleem.
  retries: 0,
  reporter: process.env.CI
    ? [['list'], ['junit', { outputFile: '../build/smoke-rapport/junit.xml' }]]
    : [['list']],
  use: {
    baseURL: process.env.SMOKE_BASE_URL,
    extraHTTPHeaders: { 'Content-Type': 'application/json' },
  },
  projects: [
    {
      name: 'deelsysteem',
      testDir: '../deelsystemen',
      testMatch: '*/smoke/*.spec.ts',
    },
    {
      name: 'gebruikersflow',
      testDir: './gebruikersflow',
      testMatch: '*.spec.ts',
    },
    {
      name: 'keten',
      testDir: './keten',
      testMatch: '*.spec.ts',
    },
  ],
});
