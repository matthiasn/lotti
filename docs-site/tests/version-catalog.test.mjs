import assert from 'node:assert/strict';
import test from 'node:test';

import {
  fetchLiveCatalog,
  isReleaseCatalog,
} from '../src/components/ManualVersionNavbarItem/catalog.mjs';

const validCatalog = {
  schemaVersion: 1,
  latestPublished: '0.10.0',
  versions: [
    {version: 'development', label: 'Development', status: 'development'},
    {version: '0.10.0', label: '0.10.0', status: 'published'},
  ],
};

const jsonResponse = (body, ok = true) => ({
  ok,
  json: async () => body,
});

test('a valid live catalog replaces the baked one', async () => {
  const live = await fetchLiveCatalog('/manual/releases.json', async (url) => {
    assert.equal(url, '/manual/releases.json');
    return jsonResponse(validCatalog);
  });
  assert.deepEqual(live, validCatalog);
});

test('a non-OK response keeps the fallback', async () => {
  const live = await fetchLiveCatalog('/manual/releases.json', async () =>
    jsonResponse(validCatalog, false),
  );
  assert.equal(live, null);
});

test('malformed payloads keep the fallback', async () => {
  for (const body of [
    null,
    'releases',
    {versions: 'not-a-list'},
    {versions: [{label: 'missing version string'}]},
    {latestPublished: '0.10.0'},
  ]) {
    assert.equal(
      await fetchLiveCatalog('/manual/releases.json', async () =>
        jsonResponse(body),
      ),
      null,
      `expected null for ${JSON.stringify(body)}`,
    );
  }
});

test('a broken JSON body keeps the fallback', async () => {
  const live = await fetchLiveCatalog('/manual/releases.json', async () => ({
    ok: true,
    json: async () => {
      throw new SyntaxError('Unexpected end of JSON input');
    },
  }));
  assert.equal(live, null);
});

test('a network failure keeps the fallback', async () => {
  const live = await fetchLiveCatalog('/manual/releases.json', async () => {
    throw new TypeError('fetch failed');
  });
  assert.equal(live, null);
});

test('isReleaseCatalog accepts the shape the finalizer writes', () => {
  assert.equal(isReleaseCatalog(validCatalog), true);
  assert.equal(isReleaseCatalog({versions: []}), true);
  assert.equal(isReleaseCatalog([]), false);
});
