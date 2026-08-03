/**
 * Structural parity between an English manual page and one translation.
 *
 * Translation drift has historically been silent: a section added to the
 * English page simply never appeared in a locale, and a page-count audit
 * stayed green because the file itself existed. These helpers compare the
 * page *skeleton* — frontmatter identity, heading sequence, screenshot
 * sequence, admonition sequence — and flag screenshot alt/caption text that
 * is still identical to the English source.
 */

const frontmatterPattern = /^---\n([\s\S]*?)\n---\n?/;
const screenshotPattern = /<ManualScreenshot[\s\S]*?\/>/g;
// The closing quote must match the opening one, so a double-quoted value may
// contain apostrophes ("The sentinel's directive") without being truncated.
const attributePattern = (name) =>
  new RegExp(`\\b${name}=(?:"([^"]*)"|'([^']*)')`);

function attributeValue(component, name) {
  const match = attributePattern(name).exec(component);
  if (!match) return null;
  return match[1] ?? match[2];
}

/** Keys whose values identify the page and must survive translation as-is. */
export const identityFrontmatterKeys = ['id', 'slug'];

/** Keys a translation must provide (translated) whenever the source has them. */
export const requiredFrontmatterKeys = ['title', 'description', 'sidebar_label'];

function stripCodeAndInlineCode(source) {
  return source
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]+`/g, '');
}

function parseFrontmatter(source) {
  const match = frontmatterPattern.exec(source);
  if (!match) return {};
  const entries = {};
  for (const line of match[1].split('\n')) {
    const separator = line.indexOf(':');
    if (separator === -1) continue;
    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim();
    if (key) entries[key] = value;
  }
  return entries;
}

/** Extract the translation-invariant skeleton of one MDX page. */
export function extractMdxStructure(source) {
  const frontmatter = parseFrontmatter(source);
  const body = stripCodeAndInlineCode(source.replace(frontmatterPattern, ''));

  const headings = [];
  for (const line of body.split('\n')) {
    const heading = /^(#{1,6})\s/.exec(line);
    if (heading) headings.push(heading[1]);
  }

  const screenshots = [];
  for (const componentMatch of body.matchAll(screenshotPattern)) {
    const component = componentMatch[0];
    screenshots.push({
      caseId: attributeValue(component, 'caseId'),
      alt: attributeValue(component, 'alt'),
      caption: attributeValue(component, 'caption'),
    });
  }

  const admonitions = [];
  for (const line of body.split('\n')) {
    const admonition = /^:::([a-z]+)/.exec(line);
    if (admonition) admonitions.push(admonition[1]);
  }

  return {frontmatter, headings, screenshots, admonitions};
}

/**
 * Compare page skeletons. Returns human-readable issues; an empty array means
 * the translation mirrors the source structure.
 */
export function compareTranslationStructure(source, translation) {
  const issues = [];
  const sourceStructure = extractMdxStructure(source);
  const translatedStructure = extractMdxStructure(translation);

  for (const key of identityFrontmatterKeys) {
    const sourceValue = sourceStructure.frontmatter[key];
    if (sourceValue === undefined) continue;
    const translatedValue = translatedStructure.frontmatter[key];
    if (translatedValue !== sourceValue) {
      issues.push(
        `frontmatter ${key} must equal the source value "${sourceValue}" ` +
          `(found ${translatedValue === undefined ? 'nothing' : `"${translatedValue}"`}).`,
      );
    }
  }
  for (const key of requiredFrontmatterKeys) {
    if (
      sourceStructure.frontmatter[key] !== undefined &&
      translatedStructure.frontmatter[key] === undefined
    ) {
      issues.push(`frontmatter ${key} is missing from the translation.`);
    }
  }

  if (
    sourceStructure.headings.join(' ') !== translatedStructure.headings.join(' ')
  ) {
    issues.push(
      `heading structure differs: source has [${sourceStructure.headings.join(', ')}], ` +
        `translation has [${translatedStructure.headings.join(', ')}].`,
    );
  }

  const sourceCases = sourceStructure.screenshots.map((item) => item.caseId);
  const translatedCases = translatedStructure.screenshots.map(
    (item) => item.caseId,
  );
  if (sourceCases.join(' ') !== translatedCases.join(' ')) {
    issues.push(
      `screenshot sequence differs: source shows [${sourceCases.join(', ')}], ` +
        `translation shows [${translatedCases.join(', ')}].`,
    );
  }

  if (
    sourceStructure.admonitions.join(' ') !==
    translatedStructure.admonitions.join(' ')
  ) {
    issues.push(
      `admonition sequence differs: source has [${sourceStructure.admonitions.join(', ')}], ` +
        `translation has [${translatedStructure.admonitions.join(', ')}].`,
    );
  }

  return issues;
}

/**
 * Flag screenshot alt/caption text the translation left in English. Runs only
 * over positions where both pages show the same case, so structural drift is
 * reported once by compareTranslationStructure rather than twice.
 */
export function findUntranslatedMediaText(source, translation) {
  const issues = [];
  const sourceShots = extractMdxStructure(source).screenshots;
  const translatedShots = extractMdxStructure(translation).screenshots;

  const pairCount = Math.min(sourceShots.length, translatedShots.length);
  for (let index = 0; index < pairCount; index += 1) {
    const sourceShot = sourceShots[index];
    const translatedShot = translatedShots[index];
    if (sourceShot.caseId !== translatedShot.caseId) continue;
    for (const attribute of ['alt', 'caption']) {
      const sourceText = sourceShot[attribute];
      const translatedText = translatedShot[attribute];
      if (!sourceText) continue;
      if (!translatedText) {
        issues.push(
          `screenshot ${sourceShot.caseId} is missing its ${attribute} text.`,
        );
      } else if (translatedText === sourceText) {
        issues.push(
          `screenshot ${sourceShot.caseId} ${attribute} text is still identical ` +
            'to the English source.',
        );
      }
    }
  }
  return issues;
}
