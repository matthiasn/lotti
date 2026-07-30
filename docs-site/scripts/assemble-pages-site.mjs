#!/usr/bin/env node

import {access, cp, mkdir, readdir, rm, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  parseNamedArguments,
  siteDirectory,
  validateManualVersion,
} from './manual-lib.mjs';

/**
 * Normalize a GitHub Pages project prefix such as `lotti` or `/lotti/`.
 */
export function normalizePagesPrefix(value) {
  const segments = String(value)
    .split('/')
    .filter(Boolean);
  if (
    segments.length === 0 ||
    segments.some(
      (segment) =>
        segment === '.' ||
        segment === '..' ||
        !/^[A-Za-z0-9._-]+$/.test(segment),
    )
  ) {
    throw new Error(`Invalid GitHub Pages prefix: ${value}`);
  }
  return `/${segments.join('/')}`;
}

/**
 * A tiny no-JavaScript-first redirect used at the repository and manual roots.
 */
export function redirectDocument(target) {
  const escapedTarget = target.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
  const jsonTarget = JSON.stringify(target).replaceAll('<', '\\u003c');
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="0; url=${escapedTarget}">
    <link rel="canonical" href="${escapedTarget}">
    <title>Lotti Manual</title>
    <script>window.location.replace(${jsonTarget});</script>
  </head>
  <body>
    <p><a href="${escapedTarget}">Open the Lotti Manual</a></p>
  </body>
</html>
`;
}

/**
 * Assemble one complete GitHub Pages snapshot without committing generated
 * Docusaurus output. A future extension can add immutable release artifacts
 * to the snapshot after this function creates the current version.
 */
export async function assemblePagesSite({
  buildRoot,
  outputRoot,
  pagesPrefix,
  version,
}) {
  validateManualVersion(version);
  const normalizedPrefix = normalizePagesPrefix(pagesPrefix);
  const targetUrl = `${normalizedPrefix}/manual/${version}/`;

  await rm(outputRoot, {force: true, recursive: true});
  await mkdir(resolve(outputRoot, 'manual'), {recursive: true});
  await cp(buildRoot, resolve(outputRoot, 'manual', version), {
    recursive: true,
  });
  await writeFile(resolve(outputRoot, '.nojekyll'), '');
  const redirect = redirectDocument(targetUrl);
  await writeFile(resolve(outputRoot, 'index.html'), redirect);
  await writeFile(resolve(outputRoot, 'manual', 'index.html'), redirect);

  return {targetUrl};
}

/**
 * Order two manual versions. `development` sorts after every release;
 * releases compare by their numeric `major.minor.patch` triple, and a
 * suffixed build (`1.2.3-rc.1`) sorts before the plain release it precedes.
 * Suffixes compare identifier-wise with semver precedence: numeric
 * identifiers compare numerically (`rc.10` > `rc.2`) and rank below
 * alphanumeric ones; a longer identifier list wins a shared prefix.
 */
export function compareManualVersions(a, b) {
  if (a === b) return 0;
  if (a === 'development') return 1;
  if (b === 'development') return -1;
  const parse = (value) => {
    const triple = value.match(/^\d+\.\d+\.\d+/)?.[0] ?? '0.0.0';
    return {
      numbers: triple.split('.').map(Number),
      suffix: value.slice(triple.length).replace(/^[-.]/, ''),
    };
  };
  const left = parse(a);
  const right = parse(b);
  for (let i = 0; i < 3; i += 1) {
    const diff = (left.numbers[i] ?? 0) - (right.numbers[i] ?? 0);
    if (diff !== 0) return diff;
  }
  if (left.suffix === right.suffix) return 0;
  if (left.suffix === '') return 1;
  if (right.suffix === '') return -1;
  const leftIds = left.suffix.split(/[-.]/);
  const rightIds = right.suffix.split(/[-.]/);
  const length = Math.max(leftIds.length, rightIds.length);
  for (let i = 0; i < length; i += 1) {
    const leftId = leftIds[i];
    const rightId = rightIds[i];
    if (leftId === undefined) return -1;
    if (rightId === undefined) return 1;
    if (leftId === rightId) continue;
    const leftNumeric = /^\d+$/.test(leftId);
    const rightNumeric = /^\d+$/.test(rightId);
    if (leftNumeric && rightNumeric) return Number(leftId) - Number(rightId);
    if (leftNumeric) return -1;
    if (rightNumeric) return 1;
    return leftId < rightId ? -1 : 1;
  }
  return 0;
}

/**
 * Finalize a Pages tree whose `manual/<version>/` directories were already
 * mirrored from the site-snapshot store: keep only complete snapshots (the
 * `.snapshot.json` marker is uploaded last), write the live release catalog
 * the version dropdown fetches at runtime, and point the root redirects at
 * the latest published release — or at `development` before the first one.
 */
export async function finalizePagesSite({outputRoot, pagesPrefix}) {
  const normalizedPrefix = normalizePagesPrefix(pagesPrefix);
  const manualRoot = resolve(outputRoot, 'manual');
  const entries = await readdir(manualRoot, {withFileTypes: true});
  const versions = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    validateManualVersion(entry.name);
    const marker = resolve(manualRoot, entry.name, '.snapshot.json');
    try {
      await access(marker);
    } catch {
      throw new Error(
        `Manual version ${entry.name} has no .snapshot.json marker; ` +
          'refusing to publish an incomplete site snapshot.',
      );
    }
    versions.push(entry.name);
  }
  if (versions.length === 0) {
    throw new Error('No manual site snapshots found to publish.');
  }
  versions.sort(compareManualVersions).reverse();

  const published = versions.filter((version) => version !== 'development');
  const latestPublished = published[0] ?? null;
  const catalog = {
    schemaVersion: 1,
    latestPublished,
    versions: [
      ...(versions.includes('development')
        ? [
            {
              version: 'development',
              label: 'Development',
              status: 'development',
            },
          ]
        : []),
      ...published.map((version) => ({
        version,
        label: version,
        status: 'published',
      })),
    ],
  };
  await writeFile(
    resolve(manualRoot, 'releases.json'),
    `${JSON.stringify(catalog, null, 2)}\n`,
  );

  const targetVersion = latestPublished ?? 'development';
  const targetUrl = `${normalizedPrefix}/manual/${targetVersion}/`;
  const redirect = redirectDocument(targetUrl);
  await writeFile(resolve(outputRoot, '.nojekyll'), '');
  await writeFile(resolve(outputRoot, 'index.html'), redirect);
  await writeFile(resolve(manualRoot, 'index.html'), redirect);

  return {targetUrl, latestPublished, versions};
}

async function main() {
  const options = parseNamedArguments(process.argv.slice(2));
  const outputRoot = resolve(
    siteDirectory,
    String(options['output-root'] ?? 'pages-build'),
  );
  const pagesPrefix = String(options['pages-prefix'] ?? 'lotti');

  if (options.finalize === true) {
    const result = await finalizePagesSite({outputRoot, pagesPrefix});
    console.log(
      `GitHub Pages tree finalized: versions ${result.versions.join(', ')}; ` +
        `root redirects to ${result.targetUrl}`,
    );
    return;
  }

  const version = String(options.version ?? 'development');
  const buildRoot = resolve(
    siteDirectory,
    String(options['build-root'] ?? 'build'),
  );
  const result = await assemblePagesSite({
    buildRoot,
    outputRoot,
    pagesPrefix,
    version,
  });
  console.log(`GitHub Pages artifact assembled for ${result.targetUrl}`);
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))
) {
  await main();
}
