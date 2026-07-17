import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canonicalVariantPath,
  findLegacyManualImport,
  findUnmanagedScreenshotReferences,
  requiredVariants,
  resolveCaptureLocales,
  validateCaseId,
  validateManualVersion,
  validateScreenshotRegistry,
} from '../scripts/manual-lib.mjs';

test('the screenshot contract requires the complete viewport and theme matrix', () => {
  assert.deepEqual(requiredVariants, [
    'mobile-light',
    'mobile-dark',
    'desktop-light',
    'desktop-dark',
  ]);
  const errors = validateScreenshotRegistry({
    schemaVersion: 2,
    defaultLocale: 'en',
    locales: ['en', 'de'],
    cases: [
      {
        id: 'settings/home',
        variants: {
          'mobile-light': 'mobile-light.png',
          'mobile-dark': 'mobile-dark.png',
          'desktop-light': 'desktop-light.png',
        },
      },
    ],
  });
  assert.deepEqual(errors, ['settings/home is missing desktop-dark.']);
});

test('unmanaged lotti-docs images are rejected outside code examples', () => {
  const legacyUrl =
    'https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/old.png';
  const source = [
    `![Old screenshot](${legacyUrl})`,
    `\`![Example only](${legacyUrl})\``,
    `\`\`\`md\n![Example only](${legacyUrl})\n\`\`\``,
  ].join('\n');

  assert.deepEqual(findUnmanagedScreenshotReferences(source), [legacyUrl]);
});

test('Widgetbook and showcase imports are rejected regardless of path style', () => {
  for (const importPath of [
    'package:lotti/features/widgetbook/task_showcase.dart',
    'package:widgetbook/widgetbook.dart',
    '../../../widgetbook/task.dart',
    'widgetbook/task.dart',
    '../showcases/task_showcase.dart',
  ]) {
    assert.equal(
      findLegacyManualImport(`import '${importPath}';`),
      `import '${importPath}'`,
    );
  }
  assert.equal(
    findLegacyManualImport(
      "import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';",
    ),
    null,
  );
});

test('canonical media paths are stable and nested by case', () => {
  assert.equal(
    canonicalVariantPath('settings/home', 'desktop-dark'),
    'settings/home/desktop-dark.webp',
  );
  assert.equal(
    canonicalVariantPath('settings/home', 'desktop-dark', 'de', 'en'),
    'de/settings/home/desktop-dark.webp',
  );
});

test('the screenshot registry requires a valid default and unique locales', () => {
  const screenshotCase = {
    id: 'settings/home',
    variants: Object.fromEntries(
      requiredVariants.map((variant) => [variant, `${variant}.png`]),
    ),
  };

  assert.deepEqual(
    validateScreenshotRegistry({
      schemaVersion: 2,
      defaultLocale: 'fr',
      locales: ['en', 'de', 'de'],
      cases: [screenshotCase],
    }),
    [
      'screenshot-cases.json defaultLocale must be listed in locales.',
      'screenshot-cases.json contains duplicate locale de.',
    ],
  );
});

test('incremental captures select only registered locales', () => {
  assert.deepEqual(resolveCaptureLocales(undefined, ['en', 'de', 'fr', 'cs']), [
    'en',
    'de',
    'fr',
    'cs',
  ]);
  assert.deepEqual(resolveCaptureLocales('cs, fr', ['en', 'de', 'fr', 'cs']), [
    'cs',
    'fr',
  ]);
  assert.throws(
    () => resolveCaptureLocales('es', ['en', 'de', 'fr', 'cs']),
    /Unsupported manual screenshot locale/,
  );
  assert.throws(
    () => resolveCaptureLocales('cs cs', ['en', 'de', 'cs']),
    /contains duplicates/,
  );
});

test('case ids reject traversal and presentation-specific names', () => {
  assert.throws(() => validateCaseId('../settings'), /Invalid screenshot case id/);
  assert.throws(() => validateCaseId('settings_home'), /Invalid screenshot case id/);
  assert.doesNotThrow(() => validateCaseId('daily-os/agenda'));
});

test('manual versions accept development and marketing versions only', () => {
  assert.doesNotThrow(() => validateManualVersion('development'));
  assert.doesNotThrow(() => validateManualVersion('1.0.0'));
  assert.doesNotThrow(() => validateManualVersion('1.0.0-rc.1'));
  assert.throws(() => validateManualVersion('1.0.0+42'), /Invalid manual version/);
  assert.throws(() => validateManualVersion('../latest'), /Invalid manual version/);
});
