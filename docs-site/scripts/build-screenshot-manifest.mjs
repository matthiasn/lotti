#!/usr/bin/env node

import {execFileSync} from 'node:child_process';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';

import sharp from 'sharp';

import {
  canonicalVariantPath,
  parseNamedArguments,
  readJson,
  repositoryDirectory,
  requiredVariants,
  sha256,
  siteDirectory,
  validateManualVersion,
  validateScreenshotRegistry,
} from './manual-lib.mjs';

const options = parseNamedArguments(process.argv.slice(2));
const version = String(options.version ?? 'development');
const captureDirectory = resolve(
  String(options['capture-dir'] ?? '../lotti-docs/manual/.staging'),
);
const outputRoot = resolve(
  String(options['output-root'] ?? '../lotti-docs/manual/screenshots'),
);
const outputDirectory = resolve(outputRoot, version);
const registry = await readJson(
  resolve(siteDirectory, 'metadata/screenshot-cases.json'),
);

validateManualVersion(version);
const registryErrors = validateScreenshotRegistry(registry);
if (registryErrors.length > 0) {
  throw new Error(registryErrors.join('\n'));
}

if (version !== 'development' && options['allow-release-overwrite'] !== true) {
  try {
    await readFile(resolve(outputDirectory, 'manifest.json'));
    throw new Error(
      `Release media ${version} already exists. Release screenshot sets are immutable.`,
    );
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

const appCommit =
  process.env.LOTTI_COMMIT ??
  execFileSync('git', ['rev-parse', 'HEAD'], {
    cwd: repositoryDirectory,
    encoding: 'utf8',
  }).trim();
const generatedAt =
  process.env.SOURCE_DATE_EPOCH !== undefined
    ? new Date(Number(process.env.SOURCE_DATE_EPOCH) * 1000).toISOString()
    : execFileSync('git', ['show', '-s', '--format=%cI', appCommit], {
        cwd: repositoryDirectory,
        encoding: 'utf8',
      }).trim();
const manifestCases = [];

for (const screenshotCase of registry.cases) {
  const variants = {};
  for (const variant of requiredVariants) {
    const inputPath = resolve(captureDirectory, screenshotCase.variants[variant]);
    const relativeOutputPath = canonicalVariantPath(screenshotCase.id, variant);
    const outputPath = resolve(outputDirectory, relativeOutputPath);
    await mkdir(resolve(outputPath, '..'), {recursive: true});

    const input = await readFile(inputPath);
    await sharp(input)
      .webp({quality: 88, effort: 5, smartSubsample: true})
      .toFile(outputPath);
    const output = await readFile(outputPath);
    const metadata = await sharp(output).metadata();

    variants[variant] = {
      path: relativeOutputPath,
      width: metadata.width,
      height: metadata.height,
      bytes: output.byteLength,
      sha256: sha256(output),
    };
  }
  manifestCases.push({
    id: screenshotCase.id,
    title: screenshotCase.title,
    sourceTest: screenshotCase.sourceTest,
    variants,
  });
}

const manifest = {
  schemaVersion: 1,
  version,
  generatedAt,
  appCommit,
  cases: manifestCases,
};
await mkdir(outputDirectory, {recursive: true});
await writeFile(
  resolve(outputDirectory, 'manifest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
);

console.log(
  `Wrote ${manifestCases.length} screenshot case(s) to ${outputDirectory}.`,
);
