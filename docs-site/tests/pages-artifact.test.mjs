import assert from 'node:assert/strict';
import {access, mkdir, mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve} from 'node:path';
import test from 'node:test';
import vm from 'node:vm';

import {
  assemblePagesSite,
  compareManualVersions,
  finalizePagesSite,
  listRetainedSnapshots,
  normalizePagesPrefix,
  notFoundDocument,
  planPagesVersions,
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
  // Only dots separate identifiers: alpha-1 is one identifier, after alpha.
  assert.ok(compareManualVersions('1.2.3-alpha-1', '1.2.3-alpha.2') > 0);
  // Digit-string comparison keeps precision beyond Number's safe range.
  assert.ok(
    compareManualVersions(
      '1.2.3-rc.9007199254740993',
      '1.2.3-rc.9007199254740992',
    ) > 0,
  );
  assert.equal(compareManualVersions('1.2.3-rc.010', '1.2.3-rc.10'), 0);
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

test('plan keeps the newest snapshots and the aliases that still resolve', () => {
  const plan = planPagesVersions(
    [
      {version: 'development'},
      {version: '1.0.1'},
      {version: '1.0.2', aliasOf: '1.0.1'},
      {version: '1.0.3'},
      {version: '1.0.4'},
      {version: '1.0.5', aliasOf: '1.0.4'},
    ],
    2,
  );
  // 1.0.1 falls out of the two kept snapshots, and its alias with it.
  assert.deepEqual(plan.retainedReal, ['1.0.4', '1.0.3']);
  assert.deepEqual(plan.aliases, {'1.0.5': '1.0.4'});
  assert.equal(plan.latestPublished, '1.0.5');
  // The newest release is an alias: land on the snapshot that serves it.
  assert.equal(plan.fallback, '1.0.4');
  assert.equal(plan.hasDevelopment, true);
});

test('plan falls back to development before the first release', () => {
  const plan = planPagesVersions([{version: 'development'}]);
  assert.deepEqual(plan.retainedReal, []);
  assert.equal(plan.latestPublished, null);
  assert.equal(plan.fallback, 'development');
});

test('finalize prunes old snapshots, redirects aliases, writes the catalog', async () => {
  const root = await mkdtemp(resolve(tmpdir(), 'lotti-pages-'));
  const outputRoot = resolve(root, 'pages');
  const manualRoot = resolve(outputRoot, 'manual');
  const addSnapshot = async (version, marker = {}) => {
    await mkdir(resolve(manualRoot, version), {recursive: true});
    if (!marker.aliasOf) {
      await writeFile(resolve(manualRoot, version, 'index.html'), '<h1>x</h1>');
    }
    await writeFile(
      resolve(manualRoot, version, '.snapshot.json'),
      JSON.stringify({version, ...marker}),
    );
  };
  const exists = (path) =>
    access(path).then(
      () => true,
      () => false,
    );

  try {
    await addSnapshot('development');
    for (let patch = 0; patch < 12; patch += 1) {
      await addSnapshot(`1.0.${patch}`);
    }
    await addSnapshot('1.0.12', {aliasOf: '1.0.11'});
    await addSnapshot('1.0.13', {aliasOf: '1.0.0'});

    assert.deepEqual(await listRetainedSnapshots({outputRoot}), [
      'development',
      ...Array.from({length: 10}, (_, i) => `1.0.${11 - i}`),
    ]);

    const result = await finalizePagesSite({outputRoot, pagesPrefix: 'lotti'});
    assert.equal(result.latestPublished, '1.0.12');
    assert.equal(result.targetUrl, '/lotti/manual/1.0.11/');
    assert.equal(await exists(resolve(manualRoot, '1.0.1')), false);
    assert.equal(await exists(resolve(manualRoot, '1.0.13')), false);
    assert.equal(await exists(resolve(manualRoot, '1.0.2')), true);
    assert.match(
      await readFile(resolve(manualRoot, '1.0.12', 'index.html'), 'utf8'),
      /\/lotti\/manual\/1\.0\.11\//,
    );

    const catalog = JSON.parse(
      await readFile(resolve(manualRoot, 'releases.json'), 'utf8'),
    );
    assert.deepEqual(catalog.aliases, {'1.0.12': '1.0.11'});
    assert.equal(catalog.versions.length, 11);
    assert.match(
      await readFile(resolve(outputRoot, '404.html'), 'utf8'),
      /"fallback":"1\.0\.11"/,
    );
  } finally {
    await rm(root, {force: true, recursive: true});
  }
});

test('the 404 page sends every missing manual URL to a kept snapshot', () => {
  const page = notFoundDocument({
    pagesPrefix: '/lotti',
    snapshots: ['development', '1.0.11'],
    aliases: {'1.0.12': '1.0.11'},
    fallback: '1.0.11',
  });
  const script = page.match(/<script>([\s\S]*?)<\/script>/)[1];
  const redirectFor = (pathname, search = '', hash = '') => {
    let target = null;
    vm.runInNewContext(script, {
      window: {
        location: {pathname, search, hash, replace: (url) => (target = url)},
      },
    });
    return target;
  };

  // An alias serves the same page of its snapshot.
  assert.equal(
    redirectFor('/lotti/manual/1.0.12/de/sync-and-data/first-device'),
    '/lotti/manual/1.0.11/de/sync-and-data/first-device',
  );
  // A pruned or never-published version lands on the newest release.
  assert.equal(
    redirectFor('/lotti/manual/1.0.1/fr/', '?q=1', '#top'),
    '/lotti/manual/1.0.11/fr/?q=1#top',
  );
  // A page missing inside a kept snapshot goes to that snapshot's root.
  assert.equal(
    redirectFor('/lotti/manual/development/gone/page'),
    '/lotti/manual/development/',
  );
  // A kept snapshot's own root and paths outside the manual stay put.
  assert.equal(redirectFor('/lotti/manual/1.0.11/'), null);
  assert.equal(redirectFor('/lotti/other'), null);
});
