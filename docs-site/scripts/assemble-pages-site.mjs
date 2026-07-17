#!/usr/bin/env node

import {cp, mkdir, rm, writeFile} from 'node:fs/promises';
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

async function main() {
  const options = parseNamedArguments(process.argv.slice(2));
  const version = String(options.version ?? 'development');
  const buildRoot = resolve(
    siteDirectory,
    String(options['build-root'] ?? 'build'),
  );
  const outputRoot = resolve(
    siteDirectory,
    String(options['output-root'] ?? 'pages-build'),
  );
  const pagesPrefix = String(options['pages-prefix'] ?? 'lotti');

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
