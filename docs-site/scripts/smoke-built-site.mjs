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

let screenshotControlCount = 0;
for (const feature of features.features) {
  if (feature.screenshotCases.length === 0) continue;
  const html = await readFile(
    resolve(buildDirectory, feature.page, 'index.html'),
    'utf8',
  );
  const renderedControls =
    html.match(/aria-label="Screenshot layout for all images"/g)?.length ?? 0;
  const renderedViewers =
    html.match(/aria-label="Open screenshot viewer"/g)?.length ?? 0;
  assert.equal(
    renderedControls,
    feature.screenshotCases.length,
    `Every ${feature.title} screenshot case must render its viewport control.`,
  );
  assert.equal(
    renderedViewers,
    feature.screenshotCases.length,
    `Every ${feature.title} screenshot case must render its expandable viewer.`,
  );
  screenshotControlCount += renderedControls;
  for (const caseId of feature.screenshotCases) {
    assert.match(html, new RegExp(`data-case-id=["']?${caseId}`));
  }
}

const searchIndex = await readFile(
  resolve(buildDirectory, 'search-index.json'),
  'utf8',
);
assert.match(searchIndex, /Daily OS/);
assert.match(searchIndex, /Create your first task/);

console.log(
  `Built-site smoke test passed for ${features.features.length} feature routes, ` +
    `${screenshotControlCount} global screenshot controls, ` +
    'the interactive screenshot shell, and local search.',
);
