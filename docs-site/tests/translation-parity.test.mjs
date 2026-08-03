import assert from 'node:assert/strict';
import test from 'node:test';

import {
  compareTranslationStructure,
  extractMdxStructure,
  findUntranslatedMediaText,
  identityFrontmatterKeys,
  requiredFrontmatterKeys,
} from '../scripts/translation-parity.mjs';

const englishPage = `---
id: index
title: Record audio
slug: /
sidebar_label: Welcome
description: Capture a voice note.
---

# Record audio

## Capture a recording

<ManualScreenshot
  caseId="recordings/active"
  alt="Active audio recording sheet"
  caption="The sheet keeps elapsed time in view."
/>

:::note[About the demo]

Demo content only.

:::

## Review saved transcripts

:::tip[Start small]

One recording is enough.

:::
`;

function translatedVariant(overrides = {}) {
  const {
    slug = 'slug: /',
    heading = '## Transkripte prüfen',
    caseId = 'recordings/active',
    alt = 'Aktive Audioaufnahme',
    caption = 'Die verstrichene Zeit bleibt sichtbar.',
    admonition = ':::tip[Klein anfangen]',
  } = overrides;
  return `---
id: index
title: Audio aufnehmen
${slug}
sidebar_label: Willkommen
description: Halte eine Sprachnotiz fest.
---

# Audio aufnehmen

## Eine Aufnahme erstellen

<ManualScreenshot
  caseId="${caseId}"
  alt="${alt}"
  caption="${caption}"
/>

:::note[Über die Demo]

Nur Demo-Inhalte.

:::

${heading}

${admonition}

Eine Aufnahme genügt.

:::
`;
}

test('the identity and required frontmatter contracts are explicit', () => {
  assert.deepEqual(identityFrontmatterKeys, ['id', 'slug']);
  assert.deepEqual(requiredFrontmatterKeys, [
    'title',
    'description',
    'sidebar_label',
  ]);
});

test('extractMdxStructure captures frontmatter, headings, screenshots, and admonitions', () => {
  const structure = extractMdxStructure(englishPage);
  assert.equal(structure.frontmatter.id, 'index');
  assert.equal(structure.frontmatter.slug, '/');
  assert.equal(structure.frontmatter.sidebar_label, 'Welcome');
  assert.deepEqual(structure.headings, ['#', '##', '##']);
  assert.deepEqual(structure.screenshots, [
    {
      caseId: 'recordings/active',
      alt: 'Active audio recording sheet',
      caption: 'The sheet keeps elapsed time in view.',
    },
  ]);
  assert.deepEqual(structure.admonitions, ['note', 'tip']);
});

test('a page without frontmatter yields an empty frontmatter object', () => {
  const structure = extractMdxStructure('# Title\n\nBody.\n');
  assert.deepEqual(structure.frontmatter, {});
  assert.deepEqual(structure.headings, ['#']);
});

test('frontmatter lines without a colon are ignored', () => {
  const structure = extractMdxStructure('---\ntitle: Yes\njust text\n---\n');
  assert.deepEqual(structure.frontmatter, {title: 'Yes'});
});

test('a frontmatter line with an empty key is ignored', () => {
  const structure = extractMdxStructure('---\ntitle: Yes\n: stray value\n---\n');
  assert.deepEqual(structure.frontmatter, {title: 'Yes'});
});

test('a screenshot without alt text reports null for it', () => {
  const structure = extractMdxStructure(
    '<ManualScreenshot\n  caseId="a/b"\n  caption="Only a caption"\n/>\n',
  );
  assert.deepEqual(structure.screenshots, [
    {caseId: 'a/b', alt: null, caption: 'Only a caption'},
  ]);
});

test('apostrophes inside double-quoted values and single-quoted attributes parse fully', () => {
  const structure = extractMdxStructure(
    [
      '<ManualScreenshot',
      "  caseId='a/b'",
      '  alt="The sentinel\'s directive"',
      '  caption="L\'agente propone un\'estensione"',
      '/>',
    ].join('\n'),
  );
  assert.deepEqual(structure.screenshots, [
    {
      caseId: 'a/b',
      alt: "The sentinel's directive",
      caption: "L'agente propone un'estensione",
    },
  ]);
});

test('headings inside code fences and inline code do not count', () => {
  const source = [
    '# Real heading',
    '```bash',
    '# a comment, not a heading',
    '```',
    'Inline `# also not a heading` stays inline.',
  ].join('\n');
  assert.deepEqual(extractMdxStructure(source).headings, ['#']);
});

test('a screenshot without caption or caseId reports null for the gap', () => {
  const structure = extractMdxStructure(
    '<ManualScreenshot\n  alt="Only alt text"\n/>\n',
  );
  assert.deepEqual(structure.screenshots, [
    {caseId: null, alt: 'Only alt text', caption: null},
  ]);
});

test('a faithful translation produces no structural issues', () => {
  assert.deepEqual(
    compareTranslationStructure(englishPage, translatedVariant()),
    [],
  );
});

test('a changed identity frontmatter value is reported with what was found', () => {
  const issues = compareTranslationStructure(
    englishPage,
    translatedVariant({slug: 'slug: /wrong'}),
  );
  assert.deepEqual(issues, [
    'frontmatter slug must equal the source value "/" (found "/wrong").',
  ]);
});

test('a missing identity frontmatter value is reported as nothing found', () => {
  const translation = translatedVariant().replace('slug: /\n', '');
  const issues = compareTranslationStructure(englishPage, translation);
  assert.deepEqual(issues, [
    'frontmatter slug must equal the source value "/" (found nothing).',
  ]);
});

test('identity keys the source does not declare are not demanded', () => {
  const source = '---\ntitle: Plain page\n---\n\n# Plain page\n';
  const translation = '---\ntitle: Einfache Seite\n---\n\n# Einfache Seite\n';
  assert.deepEqual(compareTranslationStructure(source, translation), []);
});

test('a required frontmatter key missing from the translation is reported', () => {
  const translation = translatedVariant().replace(
    'sidebar_label: Willkommen\n',
    '',
  );
  const issues = compareTranslationStructure(englishPage, translation);
  assert.deepEqual(issues, [
    'frontmatter sidebar_label is missing from the translation.',
  ]);
});

test('a dropped section changes the heading sequence and is reported', () => {
  const translation = translatedVariant({heading: 'Kein Abschnitt mehr.'});
  const issues = compareTranslationStructure(englishPage, translation);
  assert.deepEqual(issues, [
    'heading structure differs: source has [#, ##, ##], translation has [#, ##].',
  ]);
});

test('a diverging screenshot sequence is reported by case id', () => {
  const translation = translatedVariant({caseId: 'recordings/transcripts'});
  const issues = compareTranslationStructure(englishPage, translation);
  assert.deepEqual(issues, [
    'screenshot sequence differs: source shows [recordings/active], ' +
      'translation shows [recordings/transcripts].',
  ]);
});

test('a changed admonition type is reported in sequence terms', () => {
  const translation = translatedVariant({admonition: ':::warning[Achtung]'});
  const issues = compareTranslationStructure(englishPage, translation);
  assert.deepEqual(issues, [
    'admonition sequence differs: source has [note, tip], translation has [note, warning].',
  ]);
});

test('translated media text produces no issues', () => {
  assert.deepEqual(
    findUntranslatedMediaText(englishPage, translatedVariant()),
    [],
  );
});

test('alt text left identical to English is flagged', () => {
  const translation = translatedVariant({alt: 'Active audio recording sheet'});
  assert.deepEqual(findUntranslatedMediaText(englishPage, translation), [
    'screenshot recordings/active alt text is still identical to the English source.',
  ]);
});

test('caption text left identical to English is flagged', () => {
  const translation = translatedVariant({
    caption: 'The sheet keeps elapsed time in view.',
  });
  assert.deepEqual(findUntranslatedMediaText(englishPage, translation), [
    'screenshot recordings/active caption text is still identical to the English source.',
  ]);
});

test('a caption dropped by the translation is flagged as missing', () => {
  const translation = translatedVariant().replace(
    /\n  caption="[^"]*"/,
    '',
  );
  assert.deepEqual(findUntranslatedMediaText(englishPage, translation), [
    'screenshot recordings/active is missing its caption text.',
  ]);
});

test('media text the source itself does not carry is not demanded', () => {
  const source = '<ManualScreenshot\n  caseId="a/b"\n  alt="Alt"\n/>\n';
  const translation = '<ManualScreenshot\n  caseId="a/b"\n  alt="Alt-Text"\n/>\n';
  assert.deepEqual(findUntranslatedMediaText(source, translation), []);
});

test('positions where the case ids diverge are left to the structural check', () => {
  const source = '<ManualScreenshot caseId="a/b" alt="Alt" />\n';
  const translation = '<ManualScreenshot caseId="c/d" alt="Alt" />\n';
  assert.deepEqual(findUntranslatedMediaText(source, translation), []);
});

test('extra screenshots beyond the shared prefix are left to the structural check', () => {
  const source = [
    '<ManualScreenshot caseId="a/b" alt="Alt one" />',
    '<ManualScreenshot caseId="c/d" alt="Alt two" />',
  ].join('\n');
  const translation = '<ManualScreenshot caseId="a/b" alt="Alt eins" />\n';
  assert.deepEqual(findUntranslatedMediaText(source, translation), []);
});
