import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export const siteDirectory = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '..',
);
export const repositoryDirectory = resolve(siteDirectory, '..');
export const requiredVariants = [
  'mobile-light',
  'mobile-dark',
  'desktop-light',
  'desktop-dark',
];

export async function readJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

export function validateCaseId(caseId) {
  if (!/^[a-z0-9]+(?:[/-][a-z0-9]+)*$/.test(caseId)) {
    throw new Error(
      `Invalid screenshot case id "${caseId}". Use lowercase path segments.`,
    );
  }
}

export function validateManualVersion(version) {
  if (version === 'development') return;
  if (!/^\d+\.\d+\.\d+(?:[-.][0-9A-Za-z.-]+)?$/.test(version)) {
    throw new Error(
      `Invalid manual version "${version}". Expected development or a marketing version.`,
    );
  }
}

export function validateScreenshotRegistry(registry) {
  const errors = [];
  if (registry.schemaVersion !== 2) {
    errors.push('screenshot-cases.json must use schemaVersion 2.');
  }
  if (!Array.isArray(registry.locales) || registry.locales.length === 0) {
    errors.push('screenshot-cases.json must list at least one locale.');
  } else {
    if (!registry.locales.includes(registry.defaultLocale)) {
      errors.push(
        'screenshot-cases.json defaultLocale must be listed in locales.',
      );
    }
    const seenLocales = new Set();
    for (const locale of registry.locales) {
      if (!/^[a-z]{2}(?:-[A-Z]{2})?$/.test(locale)) {
        errors.push(`screenshot-cases.json contains invalid locale ${locale}.`);
      }
      if (seenLocales.has(locale)) {
        errors.push(`screenshot-cases.json contains duplicate locale ${locale}.`);
      }
      seenLocales.add(locale);
    }
  }
  if (!Array.isArray(registry.cases) || registry.cases.length === 0) {
    errors.push('screenshot-cases.json must contain at least one case.');
    return errors;
  }

  const seen = new Set();
  for (const screenshotCase of registry.cases) {
    try {
      validateCaseId(screenshotCase.id);
    } catch (error) {
      errors.push(error.message);
    }
    if (seen.has(screenshotCase.id)) {
      errors.push(`Duplicate screenshot case id: ${screenshotCase.id}`);
    }
    seen.add(screenshotCase.id);

    for (const variant of requiredVariants) {
      if (!screenshotCase.variants?.[variant]) {
        errors.push(`${screenshotCase.id} is missing ${variant}.`);
      }
    }
    const unexpectedVariants = Object.keys(screenshotCase.variants ?? {}).filter(
      (variant) => !requiredVariants.includes(variant),
    );
    if (unexpectedVariants.length > 0) {
      errors.push(
        `${screenshotCase.id} has unexpected variants: ${unexpectedVariants.join(', ')}.`,
      );
    }
  }
  return errors;
}

export function findUnmanagedScreenshotReferences(source) {
  const authoringMarkup = source
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]+`/g, '');
  const lottiDocsMediaUrl =
    /https:\/\/raw\.githubusercontent\.com\/matthiasn\/lotti-docs\/[^\s)'">]+/g;
  return [...new Set(authoringMarkup.match(lottiDocsMediaUrl) ?? [])];
}

/** Find an import that points at a Widgetbook or showcase-only surface. */
export function findLegacyManualImport(source) {
  const importPattern = /import\s+['"]([^'"]+)['"]/gi;
  for (const match of source.matchAll(importPattern)) {
    const importPath = match[1];
    if (
      /(?:^package:widgetbook\/|(?:^|\/)widgetbook\/|showcase)/i.test(
        importPath,
      )
    ) {
      return match[0];
    }
  }
  return null;
}

export function canonicalVariantPath(
  caseId,
  variant,
  locale = 'en',
  defaultLocale = 'en',
) {
  validateCaseId(caseId);
  if (!requiredVariants.includes(variant)) {
    throw new Error(`Unknown screenshot variant: ${variant}`);
  }
  const localePrefix = locale === defaultLocale ? '' : `${locale}/`;
  return `${localePrefix}${caseId}/${variant}.webp`;
}

export function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

export function parseNamedArguments(argumentsList) {
  const result = {};
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (!argument.startsWith('--')) {
      throw new Error(`Unexpected argument: ${argument}`);
    }
    const name = argument.slice(2);
    const value = argumentsList[index + 1];
    if (!value || value.startsWith('--')) {
      result[name] = true;
    } else {
      result[name] = value;
      index += 1;
    }
  }
  return result;
}
