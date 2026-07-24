#!/usr/bin/env node
// Production-dependency advisory gate.
//
// `npm audit --audit-level=high` cannot express "this advisory has no
// reachable fix yet". When an advisory's vulnerable range covers every
// published version of a transitive package, the audit fails on every branch,
// forever, and no dependency change clears it — `npm audit fix --force`
// included. Left alone that blocks every merge; silenced with `|| true` it
// stops catching anything.
//
// So: same data, same threshold, but advisories listed in
// `audit-allowlist.json` are reported and skipped rather than failing the
// build, and each entry must carry a reason and an expiry — after which this
// fails on the entry itself. An exception that outlives its justification
// becomes a build failure instead of a habit.

import { execFile } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import { evaluate, expiredEntries } from './audit-gate-lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const siteRoot = resolve(here, '..');
const allowlistPath = resolve(siteRoot, 'audit-allowlist.json');
const THRESHOLD = 'high';

/// `npm audit` exits non-zero whenever it finds anything at its own threshold,
/// so a non-zero exit is expected — the JSON on stdout is the result. Only a
/// missing or unparseable report is a real failure.
function runAudit() {
  return new Promise((resolvePromise, reject) => {
    execFile(
      'npm',
      ['audit', '--json', '--omit=dev'],
      { cwd: siteRoot, maxBuffer: 32 * 1024 * 1024 },
      (error, stdout) => {
        if (!stdout) {
          reject(error ?? new Error('npm audit produced no output'));
          return;
        }
        try {
          resolvePromise(JSON.parse(stdout));
        } catch (parseError) {
          reject(parseError);
        }
      },
    );
  });
}

async function readAllowlist() {
  try {
    return JSON.parse(await readFile(allowlistPath, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return { allow: [] };
    throw error;
  }
}

const [report, allowlist] = await Promise.all([runAudit(), readAllowlist()]);

const expired = expiredEntries(allowlist);
if (expired.length > 0) {
  console.error('Audit allowlist entries have expired — re-check upstream:');
  for (const entry of expired) {
    console.error(`  ${entry.id} expired ${entry.expires}: ${entry.reason}`);
  }
  process.exit(1);
}

const { waived, blocking } = evaluate(report, allowlist, THRESHOLD);

if (waived.length > 0) {
  console.log(`Waived ${waived.length} allowlisted advisory path(s):`);
  for (const line of waived) console.log(`  ${line}`);
}

if (blocking.length > 0) {
  console.error(
    `\n${blocking.length} production advisory path(s) at ${THRESHOLD}+ with no allowlist entry:`,
  );
  for (const line of blocking) console.error(`  ${line}`);
  console.error(
    '\nFix them, or add a justified, dated entry to audit-allowlist.json.',
  );
  process.exit(1);
}

console.log(`No unwaived production advisories at ${THRESHOLD} or above.`);
