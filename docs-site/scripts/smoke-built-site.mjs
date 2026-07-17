#!/usr/bin/env node

import assert from 'node:assert/strict';
import {access, readFile, readdir} from 'node:fs/promises';
import {resolve} from 'node:path';

import {readJson, siteDirectory} from './manual-lib.mjs';

const buildDirectory = resolve(siteDirectory, 'build');
const features = await readJson(resolve(siteDirectory, 'metadata/features.json'));

await access(resolve(buildDirectory, 'index.html'));
const buildFiles = await readdir(buildDirectory, {recursive: true});
assert.ok(
  buildFiles.some((path) => /Inter-VariableFont.*\.ttf$/.test(path)),
  'The manual build must bundle Lotti\'s Inter variable font.',
);
assert.ok(
  buildFiles.some((path) => /Inconsolata-Regular.*\.ttf$/.test(path)),
  'The manual build must bundle Lotti\'s Inconsolata code font.',
);
for (const feature of features.features) {
  await access(resolve(buildDirectory, feature.page, 'index.html'));
  await access(resolve(buildDirectory, 'de', feature.page, 'index.html'));
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

const germanSettingsHtml = await readFile(
  resolve(buildDirectory, 'de', 'reference/settings/index.html'),
  'utf8',
);
assert.match(germanSettingsHtml, /aria-label="Screenshot-Layout für alle Bilder"/);
assert.match(germanSettingsHtml, />Alle Screenshots</);
assert.match(germanSettingsHtml, />Mobil</);
assert.match(germanSettingsHtml, />Desktop</);
assert.match(
  germanSettingsHtml,
  /manual\/screenshots\/development\/de\/settings\/home\/mobile-dark\.webp/,
);

let screenshotControlCount = 0;
let germanScreenshotControlCount = 0;
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
  const germanHtml = await readFile(
    resolve(buildDirectory, 'de', feature.page, 'index.html'),
    'utf8',
  );
  const germanRenderedControls =
    germanHtml.match(/aria-label="Screenshot-Layout für alle Bilder"/g)?.length ?? 0;
  assert.equal(
    germanRenderedControls,
    feature.screenshotCases.length,
    `Every translated ${feature.title} screenshot case must render its viewport control.`,
  );
  germanScreenshotControlCount += germanRenderedControls;
  for (const caseId of feature.screenshotCases) {
    assert.match(html, new RegExp(`data-case-id=["']?${caseId}`));
    assert.match(germanHtml, new RegExp(`data-case-id=["']?${caseId}`));
  }
}

const searchIndex = await readFile(
  resolve(buildDirectory, 'search-index.json'),
  'utf8',
);
assert.match(searchIndex, /Daily OS/);
assert.match(searchIndex, /Create your first task/);
const germanSearchIndex = await readFile(
  resolve(buildDirectory, 'de', 'search-index.json'),
  'utf8',
);
assert.match(germanSearchIndex, /Daily OS/);
assert.match(germanSearchIndex, /Deine erste Aufgabe erstellen/);

console.log(
  `Built-site smoke test passed for ${features.features.length} feature routes, ` +
    `${screenshotControlCount} English and ${germanScreenshotControlCount} German ` +
    'global screenshot controls, the interactive screenshot shell, and both local search indexes.',
);
