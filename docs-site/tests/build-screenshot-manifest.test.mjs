import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdir, mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname, resolve} from 'node:path';
import test from 'node:test';
import {fileURLToPath} from 'node:url';
import {promisify} from 'node:util';

import sharp from 'sharp';

const runScript = promisify(execFile);
const scriptPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../scripts/build-screenshot-manifest.mjs',
);

// A deliberately tiny stand-in for metadata/screenshot-cases.json: the real
// 134-case matrix would make this test cost minutes for no extra coverage.
const REGISTRY = {
  schemaVersion: 2,
  defaultLocale: 'en',
  locales: ['en', 'de', 'fr'],
  cases: [
    {
      id: 'tasks/workspace',
      title: 'Task workspace',
      sourceTest: 'test/features/tasks/ui/widgets/task_manual_screenshots_test.dart',
      variants: {
        'mobile-light': 'workspace_mobile_light.png',
        'mobile-dark': 'workspace_mobile_dark.png',
        'desktop-light': 'workspace_desktop_light.png',
        'desktop-dark': 'workspace_desktop_dark.png',
      },
    },
    {
      id: 'ai/usage',
      title: 'Usage and impact',
      sourceTest: 'test/features/ai/ui/settings/ai_settings_manual_screenshots_test.dart',
      variants: {
        'mobile-light': 'usage_mobile_light.png',
        'mobile-dark': 'usage_mobile_dark.png',
        'desktop-light': 'usage_desktop_light.png',
        'desktop-dark': 'usage_desktop_dark.png',
      },
    },
  ],
};

/**
 * Pin the manifest's provenance fields so two runs of the same catalog differ
 * only where the code differs, never by wall clock or checked-out commit.
 */
const DETERMINISTIC_ENV = {
  ...process.env,
  LOTTI_COMMIT: '1234567890abcdef1234567890abcdef12345678',
  SOURCE_DATE_EPOCH: '1750000000',
};

/**
 * Write one distinguishable PNG per case, locale and variant, so a manifest
 * that silently pointed at the wrong file would produce a different checksum.
 */
async function seedCaptureTree(captureDirectory, locales) {
  for (const locale of locales) {
    for (const screenshotCase of REGISTRY.cases) {
      for (const [variant, fileName] of Object.entries(
        screenshotCase.variants,
      )) {
        const width = variant.startsWith('mobile') ? 12 : 20;
        const [r, g, b] = createHash('sha256')
          .update(`${locale}/${screenshotCase.id}/${variant}`)
          .digest();
        const path = resolve(captureDirectory, locale, fileName);
        await mkdir(dirname(path), {recursive: true});
        await sharp({
          create: {width, height: 8, channels: 3, background: {r, g, b}},
        })
          .png()
          .toFile(path);
      }
    }
  }
}

async function withWorkspace(run) {
  const root = await mkdtemp(resolve(tmpdir(), 'lotti-manifest-'));
  try {
    const registryPath = resolve(root, 'registry.json');
    await writeFile(registryPath, JSON.stringify(REGISTRY));
    const captureDirectory = resolve(root, 'capture');
    await seedCaptureTree(captureDirectory, REGISTRY.locales);
    await run({root, registryPath, captureDirectory});
  } finally {
    await rm(root, {force: true, recursive: true});
  }
}

const buildManifest = (registryPath, args) =>
  runScript('node', [scriptPath, '--registry', registryPath, ...args], {
    env: DETERMINISTIC_ENV,
  });

test('sharded per-locale conversion plus a merge pass equals one-shot output', async () => {
  await withWorkspace(async ({root, registryPath, captureDirectory}) => {
    const shardedRoot = resolve(root, 'media-sharded');
    const oneShotRoot = resolve(root, 'media-one-shot');
    const common = [
      '--capture-dir',
      captureDirectory,
      '--version',
      'development',
    ];

    // What CI now does: each locale converts alone, on its own machine.
    for (const locale of REGISTRY.locales) {
      const {stdout} = await buildManifest(registryPath, [
        ...common,
        '--output-root',
        shardedRoot,
        '--locales',
        locale,
        '--skip-manifest',
      ]);
      assert.match(stdout, new RegExp(`captured locales: ${locale}\\.`));
    }

    // A shard must not leave a manifest behind: a manifest that described one
    // locale would advertise cases whose other locales had not been captured.
    await assert.rejects(
      readFile(resolve(shardedRoot, 'development/manifest.json')),
      {code: 'ENOENT'},
    );

    await buildManifest(registryPath, [
      '--output-root',
      shardedRoot,
      '--version',
      'development',
      '--manifest-only',
    ]);
    await buildManifest(registryPath, [
      ...common,
      '--output-root',
      oneShotRoot,
    ]);

    const sharded = JSON.parse(
      await readFile(resolve(shardedRoot, 'development/manifest.json'), 'utf8'),
    );
    const oneShot = JSON.parse(
      await readFile(resolve(oneShotRoot, 'development/manifest.json'), 'utf8'),
    );
    assert.deepEqual(sharded, oneShot);

    // The equality above is only worth something if the manifest is complete.
    assert.deepEqual(
      sharded.cases.map((entry) => entry.id).sort(),
      ['ai/usage', 'tasks/workspace'],
    );
    for (const entry of sharded.cases) {
      assert.deepEqual(Object.keys(entry.locales), REGISTRY.locales);
      for (const locale of REGISTRY.locales) {
        const variants = entry.locales[locale].variants;
        assert.deepEqual(Object.keys(variants).sort(), [
          'desktop-dark',
          'desktop-light',
          'mobile-dark',
          'mobile-light',
        ]);
        for (const [variant, media] of Object.entries(variants)) {
          const expectedPath =
            locale === REGISTRY.defaultLocale
              ? `${entry.id}/${variant}.webp`
              : `${locale}/${entry.id}/${variant}.webp`;
          assert.equal(media.path, expectedPath);
          assert.equal(media.width, variant.startsWith('mobile') ? 12 : 20);
          assert.ok(media.bytes > 0);
          assert.match(media.sha256, /^[0-9a-f]{64}$/);
        }
      }
    }

    // Distinguishable inputs must stay distinguishable: identical checksums
    // across locales would mean a shard overwrote another shard's media.
    const checksums = sharded.cases.flatMap((entry) =>
      REGISTRY.locales.map(
        (locale) => entry.locales[locale].variants['desktop-light'].sha256,
      ),
    );
    assert.equal(new Set(checksums).size, checksums.length);
  });
});

test('the merge pass refuses a catalog with a locale still missing', async () => {
  await withWorkspace(async ({root, registryPath, captureDirectory}) => {
    const mediaRoot = resolve(root, 'media-partial');
    for (const locale of ['en', 'de']) {
      await buildManifest(registryPath, [
        '--capture-dir',
        captureDirectory,
        '--output-root',
        mediaRoot,
        '--version',
        'development',
        '--locales',
        locale,
        '--skip-manifest',
      ]);
    }

    // French never ran — the guard that keeps a half-finished capture matrix
    // from being published as if it were whole.
    await assert.rejects(
      buildManifest(registryPath, [
        '--output-root',
        mediaRoot,
        '--version',
        'development',
        '--manifest-only',
      ]),
      (error) => {
        assert.match(error.stderr, /ENOENT/);
        assert.match(error.stderr, /fr\/tasks\/workspace\/mobile-light\.webp/);
        return true;
      },
    );
  });
});

test('--skip-manifest and --manifest-only are mutually exclusive', async () => {
  await withWorkspace(async ({root, registryPath}) => {
    await assert.rejects(
      buildManifest(registryPath, [
        '--output-root',
        resolve(root, 'media-conflict'),
        '--version',
        'development',
        '--skip-manifest',
        '--manifest-only',
      ]),
      (error) => {
        assert.match(error.stderr, /Use either --skip-manifest or --manifest-only/);
        return true;
      },
    );
  });
});

test('a published release manifest is never rebuilt over', async () => {
  await withWorkspace(async ({root, registryPath, captureDirectory}) => {
    const mediaRoot = resolve(root, 'media-release');
    const release = ['--version', '1.2.3'];
    await buildManifest(registryPath, [
      '--capture-dir',
      captureDirectory,
      '--output-root',
      mediaRoot,
      ...release,
    ]);

    await assert.rejects(
      buildManifest(registryPath, [
        '--capture-dir',
        captureDirectory,
        '--output-root',
        mediaRoot,
        ...release,
      ]),
      (error) => {
        assert.match(error.stderr, /Release media 1\.2\.3 already exists/);
        return true;
      },
    );
  });
});
