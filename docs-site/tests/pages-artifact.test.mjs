import assert from 'node:assert/strict';
import {mkdir, mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve} from 'node:path';
import test from 'node:test';

import {
  assemblePagesSite,
  normalizePagesPrefix,
} from '../scripts/assemble-pages-site.mjs';

test('normalizes safe repository URL prefixes', () => {
  assert.equal(normalizePagesPrefix('lotti'), '/lotti');
  assert.equal(normalizePagesPrefix('/lotti/'), '/lotti');
  assert.throws(() => normalizePagesPrefix('../lotti'), /Invalid/);
});

test('assembles a versioned Pages snapshot with root redirects', async () => {
  const root = await mkdtemp(resolve(tmpdir(), 'lotti-pages-'));
  const buildRoot = resolve(root, 'build');
  const outputRoot = resolve(root, 'pages');
  await mkdir(resolve(buildRoot, 'guide'), {recursive: true});
  await writeFile(resolve(buildRoot, 'index.html'), '<h1>Manual</h1>');
  await writeFile(resolve(buildRoot, 'guide', 'index.html'), '<h1>Guide</h1>');

  try {
    const result = await assemblePagesSite({
      buildRoot,
      outputRoot,
      pagesPrefix: '/lotti/',
      version: 'development',
    });

    assert.equal(result.targetUrl, '/lotti/manual/development/');
    assert.equal(
      await readFile(
        resolve(outputRoot, 'manual', 'development', 'guide', 'index.html'),
        'utf8',
      ),
      '<h1>Guide</h1>',
    );
    assert.match(
      await readFile(resolve(outputRoot, 'index.html'), 'utf8'),
      /\/lotti\/manual\/development\//,
    );
    assert.equal(await readFile(resolve(outputRoot, '.nojekyll'), 'utf8'), '');
  } finally {
    await rm(root, {force: true, recursive: true});
  }
});
