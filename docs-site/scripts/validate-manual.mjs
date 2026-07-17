#!/usr/bin/env node

import {access, readdir, readFile} from 'node:fs/promises';
import {resolve} from 'node:path';

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
    if (feature.status === 'verified' && feature.screenshotCases.length === 0) {
      errors.push(`${feature.id} is verified but has no screenshot coverage.`);
    }
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

const docFiles = await collectFiles(resolve(siteDirectory, 'docs'));
const referencedCaseIds = new Set();
const screenshotPattern = /<ManualScreenshot[\s\S]*?caseId=["']([^"']+)["'][\s\S]*?\/>/g;
for (const docFile of docFiles) {
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
    const manifestCases = new Map(
      (manifest.cases ?? []).map((item) => [item.id, item]),
    );
    for (const screenshotCase of screenshotRegistry.cases) {
      const manifestCase = manifestCases.get(screenshotCase.id);
      if (!manifestCase) {
        errors.push(`Media manifest is missing ${screenshotCase.id}.`);
        continue;
      }
      for (const variant of requiredVariants) {
        const metadata = manifestCase.variants?.[variant];
        if (!metadata) {
          errors.push(`Media manifest is missing ${screenshotCase.id} ${variant}.`);
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
      `${docFiles.length} pages, ${screenshotRegistry.cases.length} screenshot case(s).`,
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
