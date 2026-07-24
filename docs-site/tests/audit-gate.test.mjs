import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import test from 'node:test';

import {
  advisoryRoots,
  evaluate,
  expiredEntries,
} from '../scripts/audit-gate-lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));

/// Mirrors the shape npm emits: the package carrying an advisory has an
/// advisory object in `via`; each dependent names the package it is vulnerable
/// through, and inherits the worst severity beneath it.
const report = {
  vulnerabilities: {
    'brace-expansion': {
      severity: 'high',
      via: [
        {
          source: 1,
          url: 'https://github.com/advisories/GHSA-mh99-v99m-4gvg',
          severity: 'high',
        },
      ],
    },
    uuid: {
      severity: 'moderate',
      via: [
        {
          source: 2,
          url: 'https://github.com/advisories/GHSA-w5hq-g745-h8pq',
          severity: 'moderate',
        },
      ],
    },
    minimatch: { severity: 'high', via: ['brace-expansion'] },
    'serve-handler': { severity: 'high', via: ['minimatch'] },
    sockjs: { severity: 'moderate', via: ['uuid'] },
    // Rolled up to high by brace-expansion, but also carries a moderate root.
    '@docusaurus/core': { severity: 'high', via: ['serve-handler', 'sockjs'] },
  },
};

const allowBraceExpansion = {
  allow: [
    {
      id: 'GHSA-mh99-v99m-4gvg',
      reason: 'no reachable fix',
      expires: '2999-01-01',
    },
  ],
};

test('resolves a dependent to the root advisories it is vulnerable through', () => {
  assert.deepEqual(
    [...advisoryRoots(report, '@docusaurus/core')].sort(),
    [
      ['GHSA-mh99-v99m-4gvg', 'high'],
      ['GHSA-w5hq-g745-h8pq', 'moderate'],
    ].sort(),
  );
});

test('allowlisting one root waives every package flagged only through it', () => {
  const { waived, blocking } = evaluate(report, allowBraceExpansion);

  assert.deepEqual(blocking, []);
  // The moderate uuid root neither blocks nor needs an allowlist entry.
  assert.ok(waived.some((line) => line.startsWith('@docusaurus/core')));
  assert.ok(waived.some((line) => line.startsWith('brace-expansion')));
});

test('an unlisted high advisory still blocks — the gate is not a no-op', () => {
  const { blocking } = evaluate(report, { allow: [] });

  assert.ok(blocking.length > 0);
  assert.ok(blocking.every((line) => line.includes('GHSA-mh99-v99m-4gvg')));
});

test('a new high advisory blocks even while another is waived', () => {
  const withNewFinding = {
    vulnerabilities: {
      ...report.vulnerabilities,
      'something-else': {
        severity: 'critical',
        via: [
          {
            url: 'https://github.com/advisories/GHSA-aaaa-bbbb-cccc',
            severity: 'critical',
          },
        ],
      },
    },
  };

  const { blocking } = evaluate(withNewFinding, allowBraceExpansion);
  assert.deepEqual(blocking, [
    'something-else [critical] GHSA-aaaa-bbbb-cccc',
  ]);
});

test('a moderate-only advisory never blocks at the high threshold', () => {
  const moderateOnly = {
    vulnerabilities: {
      uuid: report.vulnerabilities.uuid,
      sockjs: report.vulnerabilities.sockjs,
    },
  };

  const { waived, blocking } = evaluate(moderateOnly, { allow: [] });
  assert.deepEqual(blocking, []);
  assert.deepEqual(waived, []);
});

test('an expired entry is reported so a waiver cannot outlive its reason', () => {
  const expired = expiredEntries({
    allow: [{ id: 'GHSA-x', reason: 'stale', expires: '2020-01-01' }],
  });
  assert.equal(expired.length, 1);

  assert.deepEqual(expiredEntries(allowBraceExpansion), []);
});

test('the committed allowlist is valid and every entry is justified and dated', async () => {
  const allowlist = JSON.parse(
    await readFile(resolve(here, '..', 'audit-allowlist.json'), 'utf8'),
  );

  assert.ok(Array.isArray(allowlist.allow));
  for (const entry of allowlist.allow) {
    assert.match(entry.id, /^GHSA-[\w-]+$/, 'entry needs a GHSA id');
    assert.ok(entry.reason?.length > 40, `${entry.id} needs a real reason`);
    assert.ok(
      !Number.isNaN(new Date(entry.expires).getTime()),
      `${entry.id} needs a parseable expiry`,
    );
  }
  // Committed entries must not already be expired, or CI is red on arrival.
  assert.deepEqual(expiredEntries(allowlist), []);
});
