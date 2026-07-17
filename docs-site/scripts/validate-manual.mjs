#!/usr/bin/env node

import {access, readdir, readFile} from 'node:fs/promises';
import {relative, resolve} from 'node:path';

import {
  findLegacyManualImport,
  findUnmanagedScreenshotReferences,
  parseNamedArguments,
  readJson,
  repositoryDirectory,
  requiredVariants,
  siteDirectory,
  validateManualVersion,
  validateScreenshotRegistry,
} from './manual-lib.mjs';

const options = parseNamedArguments(process.argv.slice(2));
const features = await readJson(resolve(siteDirectory, 'metadata/features.json'));
const releases = await readJson(resolve(siteDirectory, 'metadata/releases.json'));
const surfaceInventory = await readJson(
  resolve(siteDirectory, 'metadata/surface-inventory.json'),
);
const screenshotRegistry = await readJson(
  resolve(siteDirectory, 'metadata/screenshot-cases.json'),
);
const errors = validateScreenshotRegistry(screenshotRegistry);

const allowedFeatureStatuses = new Set([
  'draft',
  'migrated',
  'needs-screenshot-refresh',
  'verified',
]);
const caseIds = new Set(screenshotRegistry.cases.map((item) => item.id));
const featureIds = new Set();
const verifiedFeaturePages = new Set();

if (features.schemaVersion !== 1 || !Array.isArray(features.features)) {
  errors.push('features.json must use schemaVersion 1 and contain features.');
} else {
  for (const feature of features.features) {
    if (featureIds.has(feature.id)) {
      errors.push(`Duplicate feature id: ${feature.id}`);
    }
    featureIds.add(feature.id);
    if (!allowedFeatureStatuses.has(feature.status)) {
      errors.push(`${feature.id} has unknown status ${feature.status}.`);
    }
    const pagePath = resolve(siteDirectory, 'docs', `${feature.page}.mdx`);
    try {
      await access(pagePath);
    } catch {
      errors.push(`${feature.id} points to missing page ${feature.page}.mdx.`);
    }
    for (const caseId of feature.screenshotCases ?? []) {
      if (!caseIds.has(caseId)) {
        errors.push(`${feature.id} references unknown screenshot case ${caseId}.`);
      }
    }
    if (feature.status === 'verified') {
      if (feature.screenshotCases.length === 0) {
        errors.push(`${feature.id} is verified but has no screenshot coverage.`);
      } else {
        verifiedFeaturePages.add(feature.page);
      }
    }
  }
}

const allowedSurfaceKinds = new Set(['route-page', 'settings-page', 'workflow']);
const allowedSurfaceStatuses = new Set(['planned', 'documented', 'verified']);
const surfaceIds = new Set();
const surfaceStatusCounts = new Map(
  [...allowedSurfaceStatuses].map((status) => [status, 0]),
);
const surfaceSourceCache = new Map();
const inventoriedRoutes = new Map();

if (
  surfaceInventory.schemaVersion !== 1 ||
  !Array.isArray(surfaceInventory.surfaces)
) {
  errors.push(
    'surface-inventory.json must use schemaVersion 1 and contain surfaces.',
  );
} else {
  for (const surface of surfaceInventory.surfaces) {
    if (surfaceIds.has(surface.id)) {
      errors.push(`Duplicate surface id: ${surface.id}`);
    }
    surfaceIds.add(surface.id);

    if (!allowedSurfaceKinds.has(surface.kind)) {
      errors.push(`${surface.id} has unknown surface kind ${surface.kind}.`);
    }
    if (!allowedSurfaceStatuses.has(surface.status)) {
      errors.push(`${surface.id} has unknown coverage status ${surface.status}.`);
    } else {
      surfaceStatusCounts.set(
        surface.status,
        surfaceStatusCounts.get(surface.status) + 1,
      );
    }

    for (const field of ['id', 'title', 'source', 'sourcePattern', 'locator', 'page']) {
      if (typeof surface[field] !== 'string' || surface[field].trim() === '') {
        errors.push(`${surface.id ?? 'Unknown surface'} has invalid ${field}.`);
      }
    }

    if (surface.routes !== undefined && !Array.isArray(surface.routes)) {
      errors.push(`${surface.id} routes must be an array when present.`);
    }
    for (const route of surface.routes ?? []) {
      if (typeof route !== 'string' || !route.startsWith('/')) {
        errors.push(`${surface.id} has invalid route ${route}.`);
        continue;
      }
      const previousOwner = inventoriedRoutes.get(route);
      if (previousOwner) {
        errors.push(
          `Route ${route} is inventoried by both ${previousOwner} and ${surface.id}.`,
        );
      }
      inventoriedRoutes.set(route, surface.id);
    }

    const pagePath = resolve(siteDirectory, 'docs', `${surface.page}.mdx`);
    if (surface.status !== 'planned') {
      try {
        await access(pagePath);
      } catch {
        errors.push(
          `${surface.id} is ${surface.status} but points to missing page ` +
            `${surface.page}.mdx.`,
        );
      }
    }
    if (
      surface.status === 'verified' &&
      !verifiedFeaturePages.has(surface.page)
    ) {
      errors.push(
        `${surface.id} is verified but ${surface.page} is not a verified feature.`,
      );
    }

    const sourcePath = resolve(repositoryDirectory, surface.source);
    let source = surfaceSourceCache.get(sourcePath);
    if (source === undefined) {
      try {
        source = await readFile(sourcePath, 'utf8');
        surfaceSourceCache.set(sourcePath, source);
      } catch {
        errors.push(`${surface.id} points to missing source ${surface.source}.`);
        surfaceSourceCache.set(sourcePath, null);
        continue;
      }
    }
    if (source !== null && !source.includes(surface.sourcePattern)) {
      errors.push(
        `${surface.id} source anchor was not found in ${surface.source}: ` +
          surface.sourcePattern,
      );
    }

    if (options['require-complete'] && surface.status !== 'verified') {
      errors.push(
        `${surface.id} is ${surface.status}; complete coverage requires verified.`,
      );
    }
  }
}

const locationsDirectory = resolve(repositoryDirectory, 'lib/beamer/locations');
const locationEntries = await readdir(locationsDirectory, {withFileTypes: true});
const discoveredRoutes = new Map();
for (const entry of locationEntries) {
  if (!entry.isFile() || !entry.name.endsWith('_location.dart')) continue;
  const sourcePath = resolve(locationsDirectory, entry.name);
  const source = await readFile(sourcePath, 'utf8');
  const patternsBlock = /List<String>\s+get pathPatterns\s*=>\s*([\s\S]*?);/g;
  for (const block of source.matchAll(patternsBlock)) {
    for (const routeMatch of block[1].matchAll(/'(\/[^']+)'/g)) {
      const route = routeMatch[1];
      const previousSource = discoveredRoutes.get(route);
      if (previousSource) {
        errors.push(
          `Beamer route ${route} is declared by both ${previousSource} and ${entry.name}.`,
        );
      }
      discoveredRoutes.set(route, entry.name);
    }
  }
}
for (const [route, source] of discoveredRoutes) {
  if (!inventoriedRoutes.has(route)) {
    errors.push(`Beamer route ${route} from ${source} is missing from the surface inventory.`);
  }
}
for (const [route, surfaceId] of inventoriedRoutes) {
  if (!discoveredRoutes.has(route)) {
    errors.push(`${surfaceId} inventories route ${route}, but no Beamer location declares it.`);
  }
}

const settingsTreeRelativePath =
  'lib/features/settings_v2/domain/settings_tree_data.dart';
const settingsTreeSource = await readFile(
  resolve(repositoryDirectory, settingsTreeRelativePath),
  'utf8',
);
const discoveredSettingsLeafIds = new Set(
  [...settingsTreeSource.matchAll(/\bleaf\(\s*'([^']+)'/g)].map(
    (match) => match[1],
  ),
);
const inventoriedSettingsLeafIds = new Map();
for (const surface of surfaceInventory.surfaces ?? []) {
  if (surface.source !== settingsTreeRelativePath) continue;
  const idMatch = /^'([^']+)'$/.exec(surface.sourcePattern);
  if (!idMatch || !discoveredSettingsLeafIds.has(idMatch[1])) continue;
  const previousOwner = inventoriedSettingsLeafIds.get(idMatch[1]);
  if (previousOwner) {
    errors.push(
      `Settings leaf ${idMatch[1]} is inventoried by both ` +
        `${previousOwner} and ${surface.id}.`,
    );
  }
  inventoriedSettingsLeafIds.set(idMatch[1], surface.id);
}
for (const leafId of discoveredSettingsLeafIds) {
  if (!inventoriedSettingsLeafIds.has(leafId)) {
    errors.push(`Settings leaf ${leafId} is missing from the surface inventory.`);
  }
}

if (releases.schemaVersion !== 1 || !Array.isArray(releases.versions)) {
  errors.push('releases.json must use schemaVersion 1 and contain versions.');
} else {
  const releaseVersions = new Set();
  for (const release of releases.versions) {
    try {
      validateManualVersion(release.version);
    } catch (error) {
      errors.push(error.message);
    }
    if (releaseVersions.has(release.version)) {
      errors.push(`Duplicate release version: ${release.version}`);
    }
    releaseVersions.add(release.version);
  }
  if (!releaseVersions.has('development')) {
    errors.push('releases.json must include development.');
  }
  if (
    releases.latestPublished !== null &&
    !releaseVersions.has(releases.latestPublished)
  ) {
    errors.push('latestPublished must be null or name a catalog version.');
  }
}

const checkedScreenshotSources = new Set();
for (const screenshotCase of screenshotRegistry.cases) {
  const sourcePath = resolve(repositoryDirectory, screenshotCase.sourceTest);
  try {
    await access(sourcePath);
  } catch {
    errors.push(
      `${screenshotCase.id} points to missing test ${screenshotCase.sourceTest}.`,
    );
    continue;
  }
  if (!checkedScreenshotSources.has(sourcePath)) {
    checkedScreenshotSources.add(sourcePath);
    const source = await readFile(sourcePath, 'utf8');
    const legacyManualImport = findLegacyManualImport(source);
    if (legacyManualImport) {
      errors.push(
        `${screenshotCase.sourceTest} imports a Widgetbook/showcase surface. ` +
          'Manual screenshots must render production application pages.',
      );
    }
  }
}

const docsDirectory = resolve(siteDirectory, 'docs');
const docFiles = await collectFiles(docsDirectory);
const localizedDocFiles = [...docFiles];
for (const locale of screenshotRegistry.locales ?? []) {
  if (locale === screenshotRegistry.defaultLocale) continue;
  const localeDocsDirectory = resolve(
    siteDirectory,
    'i18n',
    locale,
    'docusaurus-plugin-content-docs',
    'current',
  );
  let translatedFiles = [];
  try {
    translatedFiles = await collectFiles(localeDocsDirectory);
  } catch {
    errors.push(`Missing translated docs directory for ${locale}.`);
    continue;
  }
  const translatedByPath = new Map(
    translatedFiles.map((path) => [relative(localeDocsDirectory, path), path]),
  );
  const sourcePaths = new Set();
  for (const docFile of docFiles) {
    const relativePath = relative(docsDirectory, docFile);
    sourcePaths.add(relativePath);
    const translatedPath = translatedByPath.get(relativePath);
    if (!translatedPath) {
      errors.push(`${locale} is missing translated page ${relativePath}.`);
      continue;
    }
    const [source, translation] = await Promise.all([
      readFile(docFile, 'utf8'),
      readFile(translatedPath, 'utf8'),
    ]);
    if (source.trim() === translation.trim()) {
      errors.push(`${locale} page ${relativePath} is still identical to English.`);
    }
  }
  for (const relativePath of translatedByPath.keys()) {
    if (!sourcePaths.has(relativePath)) {
      errors.push(`${locale} contains obsolete translated page ${relativePath}.`);
    }
  }
  localizedDocFiles.push(...translatedFiles);
}
const referencedCaseIds = new Set();
const screenshotPattern = /<ManualScreenshot[\s\S]*?caseId=["']([^"']+)["'][\s\S]*?\/>/g;
for (const docFile of localizedDocFiles) {
  const source = await readFile(docFile, 'utf8');
  const authoringMarkup = source
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]+`/g, '');
  for (const match of authoringMarkup.matchAll(screenshotPattern)) {
    referencedCaseIds.add(match[1]);
    if (!caseIds.has(match[1])) {
      errors.push(`${docFile} references unknown screenshot case ${match[1]}.`);
    }
  }
  for (const url of findUnmanagedScreenshotReferences(source)) {
    errors.push(
      `${docFile} embeds unmanaged lotti-docs media (${url}). ` +
        'App screenshots must use a registered ManualScreenshot case.',
    );
  }
}
for (const caseId of caseIds) {
  if (!referencedCaseIds.has(caseId)) {
    errors.push(`Screenshot case ${caseId} is not used by any manual page.`);
  }
}

if (options['media-root']) {
  const version = String(options.version ?? 'development');
  try {
    validateManualVersion(version);
  } catch (error) {
    errors.push(error.message);
  }
  const versionRoot = resolve(String(options['media-root']), version);
  let manifest;
  try {
    manifest = await readJson(resolve(versionRoot, 'manifest.json'));
  } catch {
    errors.push(`Missing or invalid media manifest for ${version}.`);
  }
  if (manifest) {
    if (manifest.schemaVersion !== 2) {
      errors.push(`Media manifest for ${version} must use schemaVersion 2.`);
    }
    if (manifest.defaultLocale !== screenshotRegistry.defaultLocale) {
      errors.push(`Media manifest for ${version} has the wrong default locale.`);
    }
    if (
      JSON.stringify(manifest.locales) !==
      JSON.stringify(screenshotRegistry.locales)
    ) {
      errors.push(`Media manifest for ${version} has the wrong locale catalog.`);
    }
    const manifestCases = new Map(
      (manifest.cases ?? []).map((item) => [item.id, item]),
    );
    for (const screenshotCase of screenshotRegistry.cases) {
      const manifestCase = manifestCases.get(screenshotCase.id);
      if (!manifestCase) {
        errors.push(`Media manifest is missing ${screenshotCase.id}.`);
        continue;
      }
      for (const locale of screenshotRegistry.locales) {
        for (const variant of requiredVariants) {
          const metadata = manifestCase.locales?.[locale]?.variants?.[variant];
          if (!metadata) {
            errors.push(
              `Media manifest is missing ${locale} ${screenshotCase.id} ${variant}.`,
            );
            continue;
          }
          try {
            await access(resolve(versionRoot, metadata.path));
          } catch {
            errors.push(`Media file does not exist: ${version}/${metadata.path}.`);
          }
        }
      }
    }
  }
}

const forbiddenVersionDirectories = ['versioned_docs', 'versioned_sidebars'];
for (const directory of forbiddenVersionDirectories) {
  try {
    await access(resolve(siteDirectory, directory));
    errors.push(
      `${directory} duplicates manual source. Release history must come from Git tags.`,
    );
  } catch {
    // Absence is the desired state.
  }
}

if (errors.length > 0) {
  console.error(`Manual validation failed with ${errors.length} error(s):`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(
    `Manual validation passed: ${features.features.length} features, ` +
      `${docFiles.length} source pages across ${screenshotRegistry.locales.length} locale(s), ` +
      `${screenshotRegistry.cases.length} screenshot case(s), ` +
      `${surfaceInventory.surfaces.length} inventoried surface(s) ` +
      `(${surfaceStatusCounts.get('verified')} verified, ` +
      `${surfaceStatusCounts.get('documented')} documented, ` +
      `${surfaceStatusCounts.get('planned')} planned).`,
  );
}

async function collectFiles(directory) {
  const entries = await readdir(directory, {withFileTypes: true});
  const files = [];
  for (const entry of entries) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collectFiles(path)));
    } else if (/\.mdx?$/.test(entry.name)) {
      files.push(path);
    }
  }
  return files;
}
