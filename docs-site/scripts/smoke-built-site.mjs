#!/usr/bin/env node

import assert from 'node:assert/strict';
import {access, readFile, readdir} from 'node:fs/promises';
import {resolve} from 'node:path';

import {readJson, siteDirectory} from './manual-lib.mjs';

const buildDirectory = resolve(siteDirectory, 'build');
const features = await readJson(resolve(siteDirectory, 'metadata/features.json'));
const screenshotRegistry = await readJson(
  resolve(siteDirectory, 'metadata/screenshot-cases.json'),
);
const localeExpectations = {
  de: {
    allScreenshots: 'Alle Screenshots',
    desktop: 'Desktop',
    firstTaskTitle: 'Deine erste Aufgabe erstellen',
    layoutLabel: 'Screenshot-Layout für alle Bilder',
    mobile: 'Mobil',
    openViewer: 'Screenshot-Ansicht öffnen',
  },
  fr: {
    allScreenshots: 'Toutes les captures d’écran',
    desktop: 'Ordinateur',
    firstTaskTitle: 'Crée ta première tâche',
    layoutLabel: 'Présentation des captures pour toutes les images',
    mobile: 'Mobile',
    openViewer: 'Ouvrir la visionneuse de captures',
  },
  es: {
    allScreenshots: 'Todas las capturas',
    desktop: 'Escritorio',
    firstTaskTitle: 'Crea tu primera tarea',
    layoutLabel: 'Diseño de las capturas para todas las imágenes',
    mobile: 'Móvil',
    openViewer: 'Abrir el visor de capturas',
  },
  cs: {
    allScreenshots: 'Všechny snímky',
    desktop: 'Počítač',
    firstTaskTitle: 'Vytvoření prvního úkolu',
    layoutLabel: 'Rozvržení snímků pro všechny obrázky',
    mobile: 'Mobil',
    openViewer: 'Otevřít prohlížeč snímku',
  },
  ro: {
    allScreenshots: 'Toate capturile de ecran',
    desktop: 'Desktop',
    firstTaskTitle: 'Creați prima sarcină',
    layoutLabel: 'Aspectul capturilor de ecran pentru toate imaginile',
    mobile: 'Mobil',
    openViewer: 'Deschideți vizualizatorul capturilor de ecran',
  },
};
const translatedLocales = screenshotRegistry.locales.filter(
  (locale) => locale !== screenshotRegistry.defaultLocale,
);

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
const indexHtml = await readFile(resolve(buildDirectory, 'index.html'), 'utf8');
assert.doesNotMatch(
  indexHtml,
  /:::note/,
  'Admonition fences must not be rendered as manual text.',
);
assert.match(
  indexHtml,
  /theme-admonition/,
  'The manual start page must render its penguin-world note as an admonition.',
);
for (const path of buildFiles) {
  if (!path.endsWith('index.html')) continue;
  const html = await readFile(resolve(buildDirectory, path), 'utf8');
  if (!html.includes('theme-doc-markdown')) continue;
  assert.doesNotMatch(
    html,
    /:::(?:note|tip|warning|caution|danger|info)\b/,
    `Manual page ${path} must not render an admonition fence as text.`,
  );
}
for (const feature of features.features) {
  await access(resolve(buildDirectory, feature.page, 'index.html'));
  for (const locale of translatedLocales) {
    await access(resolve(buildDirectory, locale, feature.page, 'index.html'));
  }
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

assert.doesNotMatch(settingsHtml, /data-translation-notice=/);
for (const locale of translatedLocales) {
  const expected = localeExpectations[locale];
  assert.ok(expected, `Smoke expectations are missing for locale ${locale}.`);
  const translatedIndexHtml = await readFile(
    resolve(buildDirectory, locale, 'index.html'),
    'utf8',
  );
  assert.doesNotMatch(
    translatedIndexHtml,
    /:::note/,
    `${locale} admonition fences must not be rendered as manual text.`,
  );
  assert.match(
    translatedIndexHtml,
    /theme-admonition/,
    `${locale} manual start page must render its penguin-world note as an admonition.`,
  );
  const translatedSettingsHtml = await readFile(
    resolve(buildDirectory, locale, 'reference/settings/index.html'),
    'utf8',
  );
  assert.match(
    translatedSettingsHtml,
    new RegExp(`data-translation-notice=["']?${locale}["']?`),
  );
  assert.match(translatedSettingsHtml, /GPT 5\.6 Sol xHigh/);
  assert.match(
    translatedSettingsHtml,
    new RegExp(`aria-label="${expected.layoutLabel}"`),
  );
  assert.match(translatedSettingsHtml, new RegExp(`>${expected.allScreenshots}<`));
  assert.match(translatedSettingsHtml, new RegExp(`>${expected.mobile}<`));
  assert.match(translatedSettingsHtml, new RegExp(`>${expected.desktop}<`));
  assert.match(
    translatedSettingsHtml,
    new RegExp(
      `manual/screenshots/development/${locale}/settings/home/mobile-dark\\.webp`,
    ),
  );
}

let screenshotControlCount = 0;
const translatedScreenshotControlCounts = Object.fromEntries(
  translatedLocales.map((locale) => [locale, 0]),
);
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
  for (const locale of translatedLocales) {
    const expected = localeExpectations[locale];
    const translatedHtml = await readFile(
      resolve(buildDirectory, locale, feature.page, 'index.html'),
      'utf8',
    );
    const renderedControls =
      translatedHtml.match(
        new RegExp(`aria-label="${expected.layoutLabel}"`, 'g'),
      )?.length ?? 0;
    const renderedViewers =
      translatedHtml.match(
        new RegExp(`aria-label="${expected.openViewer}"`, 'g'),
      )?.length ?? 0;
    assert.equal(
      renderedControls,
      feature.screenshotCases.length,
      `Every ${locale} ${feature.title} screenshot case must render its viewport control.`,
    );
    assert.equal(
      renderedViewers,
      feature.screenshotCases.length,
      `Every ${locale} ${feature.title} screenshot case must render its expandable viewer.`,
    );
    translatedScreenshotControlCounts[locale] += renderedControls;
    for (const caseId of feature.screenshotCases) {
      assert.match(translatedHtml, new RegExp(`data-case-id=["']?${caseId}`));
    }
  }
}

const translatedDocCounts = Object.fromEntries(
  translatedLocales.map((locale) => [locale, 0]),
);
for (const locale of translatedLocales) {
  for (const path of buildFiles) {
    if (!path.startsWith(`${locale}/`) || !path.endsWith('/index.html')) continue;
    const html = await readFile(resolve(buildDirectory, path), 'utf8');
    if (!html.includes('theme-doc-markdown')) continue;
    assert.equal(
      html.match(
        new RegExp(`data-translation-notice=["']?${locale}["']?`, 'g'),
      )?.length ?? 0,
      1,
      `Translated document ${path} must render exactly one translation notice.`,
    );
    translatedDocCounts[locale] += 1;
  }
  assert.equal(
    translatedDocCounts[locale],
    37,
    `The translation notice audit must cover every ${locale} manual document.`,
  );
}

const searchIndex = await readFile(
  resolve(buildDirectory, 'search-index.json'),
  'utf8',
);
assert.match(searchIndex, /Daily OS/);
assert.match(searchIndex, /Create your first task/);
for (const locale of translatedLocales) {
  const translatedSearchIndex = await readFile(
    resolve(buildDirectory, locale, 'search-index.json'),
    'utf8',
  );
  assert.match(translatedSearchIndex, /Daily OS/);
  assert.match(
    translatedSearchIndex,
    new RegExp(localeExpectations[locale].firstTaskTitle),
  );
}

console.log(
  `Built-site smoke test passed for ${features.features.length} feature routes, ` +
    `${screenshotControlCount} English and ${JSON.stringify(translatedScreenshotControlCounts)} translated ` +
    `global screenshot controls, ${JSON.stringify(translatedDocCounts)} translation notices, ` +
    'the interactive screenshot shell, and every local search index.',
);
