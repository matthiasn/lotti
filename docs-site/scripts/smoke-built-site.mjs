#!/usr/bin/env node

import assert from 'node:assert/strict';
import {access, readFile} from 'node:fs/promises';
import {resolve} from 'node:path';

import {readJson, siteDirectory} from './manual-lib.mjs';

const buildDirectory = resolve(siteDirectory, 'build');
const features = await readJson(resolve(siteDirectory, 'metadata/features.json'));

await access(resolve(buildDirectory, 'index.html'));
for (const feature of features.features) {
  await access(resolve(buildDirectory, feature.page, 'index.html'));
}

const settingsHtml = await readFile(
  resolve(buildDirectory, 'reference/settings/index.html'),
  'utf8',
);
assert.match(settingsHtml, /aria-label="Screenshot layout for all images"/);
assert.match(settingsHtml, />All screenshots</);
assert.match(settingsHtml, />Mobile</);
assert.match(settingsHtml, />Desktop</);
assert.match(
  settingsHtml,
  /manual\/screenshots\/development\/settings\/home\/mobile-dark\.webp/,
);

const dailyOsFeature = features.features.find((feature) => feature.id === 'daily-os');
assert.ok(dailyOsFeature, 'Daily OS must remain in the feature coverage catalog.');
const dailyOsHtml = await readFile(
  resolve(buildDirectory, 'plan-and-capture/daily-os/index.html'),
  'utf8',
);
assert.equal(
  dailyOsHtml.match(/aria-label="Screenshot layout for all images"/g)?.length,
  dailyOsFeature.screenshotCases.length,
  'Every Daily OS screenshot case must render its global viewport control.',
);
for (const caseId of dailyOsFeature.screenshotCases) {
  assert.match(dailyOsHtml, new RegExp(`data-case-id=["']?${caseId}`));
}

const searchIndex = await readFile(
  resolve(buildDirectory, 'search-index.json'),
  'utf8',
);
assert.match(searchIndex, /Daily OS/);
assert.match(searchIndex, /Create your first task/);

console.log(
  `Built-site smoke test passed for ${features.features.length} feature routes, ` +
    `${dailyOsFeature.screenshotCases.length} Daily OS screenshot controls, ` +
    'the interactive screenshot shell, and local search.',
);
