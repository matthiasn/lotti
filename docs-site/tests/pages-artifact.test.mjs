import assert from 'node:assert/strict';
import {mkdir, mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve} from 'node:path';
import test from 'node:test';

import {
  assemblePagesSite,
  compareManualVersions,
  finalizePagesSite,
  normalizePagesPrefix,
} from '../scripts/assemble-pages-site.mjs';

test('normalizes safe repository URL prefixes', () => {
  assert.equal(normalizePagesPrefix('lotti'), '/lotti');
  assert.equal(normalizePagesPrefix('/lotti/'), '/lotti');
  assert.throws(() => normalizePagesPrefix('../lotti'), /Invalid/);
});

test('orders manual versions with development last', () => {
  const versions = ['0.9.1073', 'development', '0.10.0', '0.9.1073-rc.1'];
  versions.sort(compareManualVersions);
  assert.deepEqual(versions, [
    '0.9.1073-rc.1',
    '0.9.1073',
    '0.10.0',
    'development',
  ]);
});

test('compares numeric prerelease identifiers numerically', () => {
  assert.ok(compareManualVersions('1.2.3-rc.10', '1.2.3-rc.2') > 0);
  assert.ok(compareManualVersions('1.2.3-rc.2', '1.2.3-rc.10') < 0);
  assert.ok(compareManualVersions('1.2.3-rc', '1.2.3-rc.1') < 0);
  assert.ok(compareManualVersions('1.2.3-alpha', '1.2.3-beta') < 0);
  assert.ok(compareManualVersions('1.2.3-1', '1.2.3-alpha') < 0);
  assert.equal(compareManualVersions('1.2.3-rc.1', '1.2.3-rc.1'), 0);
});

test('finalizes a mirrored tree: catalog, latest redirect, marker guard', async () => {
  const root = await mkdtemp(resolve(tmpdir(), 'lotti-pages-'));
  const outputRoot = resolve(root, 'pages');
  const manualRoot = resolve(outputRoot, 'manual');
  const addSnapshot = async (version, {complete = true} = {}) => {
    await mkdir(resolve(manualRoot, version), {recursive: true});
    await writeFile(resolve(manualRoot, version, 'index.html'), '<h1>x</h1>');
    if (complete) {
      await writeFile(resolve(manualRoot, version, '.snapshot.json'), '{}');
    }
  };

  try {
    await addSnapshot('development');
    await addSnapshot('0.9.1073');
    await addSnapshot('0.10.0');

    const result = await finalizePagesSite({outputRoot, pagesPrefix: 'lotti'});
    assert.equal(result.latestPublished, '0.10.0');
    assert.equal(result.targetUrl, '/lotti/manual/0.10.0/');

    const catalog = JSON.parse(
      await readFile(resolve(manualRoot, 'releases.json'), 'utf8'),
    );
    assert.equal(catalog.latestPublished, '0.10.0');
    assert.deepEqual(
      catalog.versions.map((release) => `${release.version}:${release.status}`),
      ['development:development', '0.10.0:published', '0.9.1073:published'],
    );
    assert.match(
      await readFile(resolve(outputRoot, 'index.html'), 'utf8'),
      /\/lotti\/manual\/0\.10\.0\//,
    );

    await addSnapshot('0.10.1', {complete: false});
    await assert.rejects(
      finalizePagesSite({outputRoot, pagesPrefix: 'lotti'}),
      /no \.snapshot\.json marker/,
    );
  } finally {
    await rm(root, {force: true, recursive: true});
  }
});

test('finalize redirects to development before the first release', async () => {
  const root = await mkdtemp(resolve(tmpdir(), 'lotti-pages-'));
  const outputRoot = resolve(root, 'pages');
  try {
    await mkdir(resolve(outputRoot, 'manual', 'development'), {
      recursive: true,
    });
    await writeFile(
      resolve(outputRoot, 'manual', 'development', '.snapshot.json'),
      '{}',
    );
    const result = await finalizePagesSite({outputRoot, pagesPrefix: 'lotti'});
    assert.equal(result.latestPublished, null);
    assert.equal(result.targetUrl, '/lotti/manual/development/');
  } finally {
    await rm(root, {force: true, recursive: true});
  }
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
