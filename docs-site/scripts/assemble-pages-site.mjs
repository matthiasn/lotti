#!/usr/bin/env node

import {cp, mkdir, readFile, readdir, rm, writeFile} from 'node:fs/promises';
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
  // Semver: only dots separate prerelease identifiers — a hyphen inside an
  // identifier (alpha-1) is part of it. Numeric identifiers compare as
  // digit strings (normalized length, then lexicographic) so arbitrarily
  // large build counters never lose precision to float coercion.
  const leftIds = left.suffix.split('.');
  const rightIds = right.suffix.split('.');
  const length = Math.max(leftIds.length, rightIds.length);
  for (let i = 0; i < length; i += 1) {
    const leftId = leftIds[i];
    const rightId = rightIds[i];
    if (leftId === undefined) return -1;
    if (rightId === undefined) return 1;
    if (leftId === rightId) continue;
    const leftNumeric = /^\d+$/.test(leftId);
    const rightNumeric = /^\d+$/.test(rightId);
    if (leftNumeric && rightNumeric) {
      const leftDigits = leftId.replace(/^0+(?=\d)/, '');
      const rightDigits = rightId.replace(/^0+(?=\d)/, '');
      if (leftDigits.length !== rightDigits.length) {
        return leftDigits.length - rightDigits.length;
      }
      if (leftDigits === rightDigits) continue;
      return leftDigits < rightDigits ? -1 : 1;
    }
    if (leftNumeric) return -1;
    if (rightNumeric) return 1;
    return leftId < rightId ? -1 : 1;
  }
  return 0;
}

/**
 * How many full release snapshots GitHub Pages keeps. One snapshot is ~55 MB
 * of HTML, scripts and search indexes (screenshots live on R2), and a Pages
 * site may not exceed 1 GB. Older snapshots stay in R2; their versions reach
 * the newest release through the 404 fallback.
 */
export const RETAINED_RELEASES = 10;

/**
 * Decide what a Pages deploy publishes from the mirrored snapshot markers
 * (`{version, aliasOf?}`): `development`, the newest [keep] full release
 * snapshots, and every alias — a release whose manual sources were unchanged,
 * so it reuses an earlier snapshot — whose target is still kept.
 * `fallback` is where an unknown, pruned or never-published version lands.
 */
export function planPagesVersions(markers, keep = RETAINED_RELEASES) {
  const byNewest = (a, b) => compareManualVersions(b, a);
  const retainedReal = markers
    .filter((marker) => !marker.aliasOf && marker.version !== 'development')
    .map((marker) => marker.version)
    .sort(byNewest)
    .slice(0, keep);
  const aliases = Object.fromEntries(
    markers
      .filter((marker) => retainedReal.includes(marker.aliasOf))
      .map((marker) => [marker.version, marker.aliasOf])
      .sort(([a], [b]) => byNewest(a, b)),
  );
  const latestPublished =
    [...retainedReal, ...Object.keys(aliases)].sort(byNewest)[0] ?? null;
  const hasDevelopment = markers.some(
    (marker) => marker.version === 'development',
  );
  return {
    retainedReal,
    aliases,
    latestPublished,
    hasDevelopment,
    fallback: latestPublished
      ? (aliases[latestPublished] ?? latestPublished)
      : 'development',
  };
}

/**
 * The site-wide 404 page. A request for `/manual/<version>/<page>` whose
 * version has no snapshot on Pages — an alias, a pruned or a never-published
 * release, or a dev build's guess — is sent to the same page of the snapshot
 * that serves it; a missing page inside a kept snapshot goes to that
 * snapshot's root. Every redirect lands on a kept snapshot, so it cannot loop.
 */
export function notFoundDocument({pagesPrefix, snapshots, aliases, fallback}) {
  const config = JSON.stringify({
    manualPath: `${pagesPrefix}/manual/`,
    snapshots,
    aliases,
    fallback,
  }).replaceAll('<', '\\u003c');
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Lotti Manual</title>
    <script>
      (function (config) {
        var path = window.location.pathname;
        if (path.indexOf(config.manualPath) !== 0) return;
        var rest = path.slice(config.manualPath.length);
        var slash = rest.indexOf('/');
        var version = slash === -1 ? rest : rest.slice(0, slash);
        var page = slash === -1 ? '' : rest.slice(slash + 1);
        var target;
        if (config.snapshots.indexOf(version) !== -1) {
          if (page === '') return;
          target = config.manualPath + version + '/';
        } else {
          var served = config.aliases[version] || config.fallback;
          target = config.manualPath + served + '/' + page +
            window.location.search + window.location.hash;
        }
        window.location.replace(target);
      })(${config});
    </script>
  </head>
  <body>
    <p><a href="${pagesPrefix}/manual/">Open the Lotti Manual</a></p>
  </body>
</html>
`;
}

/**
 * Read the `.snapshot.json` marker of every mirrored version directory. The
 * marker is uploaded last, so a directory without one is an incomplete
 * snapshot and fails the deploy rather than shipping half a site.
 */
async function readSnapshotMarkers(manualRoot) {
  const entries = await readdir(manualRoot, {withFileTypes: true});
  const markers = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    validateManualVersion(entry.name);
    const marker = resolve(manualRoot, entry.name, '.snapshot.json');
    let body;
    try {
      body = await readFile(marker, 'utf8');
    } catch {
      throw new Error(
        `Manual version ${entry.name} has no .snapshot.json marker; ` +
          'refusing to publish an incomplete site snapshot.',
      );
    }
    let aliasOf;
    try {
      aliasOf = JSON.parse(body).aliasOf;
    } catch {
      aliasOf = undefined;
    }
    if (aliasOf !== undefined) validateManualVersion(aliasOf);
    markers.push({version: entry.name, aliasOf});
  }
  return markers;
}

/**
 * The version directories a Pages deploy needs in full: `development` and
 * the kept release snapshots. The workflow mirrors only the markers first,
 * asks for this list, then downloads just these — pruned snapshots are never
 * fetched.
 */
export async function listRetainedSnapshots({outputRoot}) {
  const plan = planPagesVersions(
    await readSnapshotMarkers(resolve(outputRoot, 'manual')),
  );
  return [
    ...(plan.hasDevelopment ? ['development'] : []),
    ...plan.retainedReal,
  ];
}

/**
 * Finalize a Pages tree whose `manual/<version>/` directories were already
 * mirrored from the site-snapshot store: drop what [planPagesVersions] does
 * not keep, turn each kept alias into a redirect to its snapshot, write the
 * live release catalog the version dropdown fetches at runtime and the 404
 * fallback, and point the root redirects at the latest published release —
 * or at `development` before the first one.
 */
export async function finalizePagesSite({outputRoot, pagesPrefix}) {
  const normalizedPrefix = normalizePagesPrefix(pagesPrefix);
  const manualRoot = resolve(outputRoot, 'manual');
  const markers = await readSnapshotMarkers(manualRoot);
  if (markers.length === 0) {
    throw new Error('No manual site snapshots found to publish.');
  }
  const plan = planPagesVersions(markers);

  for (const {version} of markers) {
    const kept =
      version === 'development' ||
      plan.retainedReal.includes(version) ||
      version in plan.aliases;
    if (!kept) {
      await rm(resolve(manualRoot, version), {force: true, recursive: true});
    }
  }
  for (const [alias, target] of Object.entries(plan.aliases)) {
    await writeFile(
      resolve(manualRoot, alias, 'index.html'),
      redirectDocument(`${normalizedPrefix}/manual/${target}/`),
    );
  }

  const catalog = {
    schemaVersion: 1,
    latestPublished: plan.latestPublished,
    versions: [
      ...(plan.hasDevelopment
        ? [
            {
              version: 'development',
              label: 'Development',
              status: 'development',
            },
          ]
        : []),
      ...plan.retainedReal.map((version) => ({
        version,
        label: version,
        status: 'published',
      })),
    ],
    aliases: plan.aliases,
  };
  await writeFile(
    resolve(manualRoot, 'releases.json'),
    `${JSON.stringify(catalog, null, 2)}\n`,
  );

  const snapshots = [
    ...(plan.hasDevelopment ? ['development'] : []),
    ...plan.retainedReal,
  ];
  await writeFile(
    resolve(outputRoot, '404.html'),
    notFoundDocument({
      pagesPrefix: normalizedPrefix,
      snapshots,
      aliases: plan.aliases,
      fallback: plan.fallback,
    }),
  );

  const targetUrl = `${normalizedPrefix}/manual/${plan.fallback}/`;
  const redirect = redirectDocument(targetUrl);
  await writeFile(resolve(outputRoot, '.nojekyll'), '');
  await writeFile(resolve(outputRoot, 'index.html'), redirect);
  await writeFile(resolve(manualRoot, 'index.html'), redirect);

  return {
    targetUrl,
    latestPublished: plan.latestPublished,
    versions: snapshots,
    aliases: plan.aliases,
  };
}

async function main() {
  const options = parseNamedArguments(process.argv.slice(2));
  const outputRoot = resolve(
    siteDirectory,
    String(options['output-root'] ?? 'pages-build'),
  );
  const pagesPrefix = String(options['pages-prefix'] ?? 'lotti');

  if (options['list-retained'] === true) {
    // One version per line, for the workflow's selective mirror.
    console.log((await listRetainedSnapshots({outputRoot})).join('\n'));
    return;
  }

  if (options.finalize === true) {
    const result = await finalizePagesSite({outputRoot, pagesPrefix});
    console.log(
      `GitHub Pages tree finalized: versions ${result.versions.join(', ')}; ` +
        `aliases ${JSON.stringify(result.aliases)}; ` +
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
