import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the validator is a repo tool, not part of the `lotti`
// package, so it has no `package:` URI.
import '../../../tool/okf/okf_validator.dart';

/// The house keys a complete concept carries.
///
/// Kept in one place so adding a required key is a single edit here rather than
/// thirty edits across the fixtures.
const _houseKeys = '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: https://example.com/src
''';

/// Builds a complete concept document.
///
/// [house] replaces the whole house-key block for tests that vary one of those
/// fields; [extra] appends additional frontmatter; [body] replaces the body.
String _concept({
  String type = 'Feature Module',
  String house = _houseKeys,
  String extra = '',
  String body = 'Body.',
}) =>
    '''
---
type: $type
title: Speech
description: Audio capture.
resource: ../../lib/features/speech
tags: [speech]
$house$extra---

$body
''';

/// Minimal valid frontmatter, used as the baseline every negative case mutates.
final String _validFrontmatter = _concept();

/// Builds a one-concept bundle so a test only states what it is varying.
Map<String, String> _bundle(
  String conceptBody, {
  String path = 'features/speech.md',
  String? index =
      '---\nokf_version: "0.2"\n---\n\n# Root\n\n* [Speech](features/speech.md) - x\n',
  Map<String, String> extra = const {},
}) {
  return {
    'index.md': ?index,
    path: conceptBody,
    ...extra,
  };
}

/// Convenience: every message in a result, regardless of severity.
List<String> _messages(OkfValidationResult result) =>
    result.issues.map((i) => i.message).toList();

String _joined(Iterable<OkfIssue> issues) =>
    issues.map((i) => i.message).join(' ');

void main() {
  group('conformance errors (spec §11)', () {
    test('a concept with no frontmatter is rejected', () {
      final result = validateBundle(_bundle('# Just a heading\n'));

      expect(result.isConformant, isFalse);
      expect(result.errors.single.path, 'features/speech.md');
      expect(result.errors.single.message, contains('no YAML frontmatter'));
    });

    test('unparseable frontmatter is reported as an error, not a crash', () {
      final result = validateBundle(
        _bundle('---\ntype: [unclosed\n---\n\nBody.\n'),
      );

      expect(result.isConformant, isFalse);
      expect(result.errors.single.message, contains('not parseable YAML'));
    });

    test('missing type is an error while other fields are present', () {
      final result = validateBundle(
        _bundle('''
---
title: Speech
description: Audio capture.
resource: ../../lib/features/speech
tags: [speech]
$_houseKeys---

Body.
'''),
      );

      expect(
        result.errors.map((e) => e.message).single,
        contains('missing the required `type`'),
      );
    });

    test('an empty type string is rejected as firmly as a missing one', () {
      final result = validateBundle(_concept(type: '"   "').let(_bundle));

      expect(
        result.errors.single.message,
        contains('must be a non-empty string'),
      );
    });

    test('frontmatter in a non-root index.md is an error', () {
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          extra: {
            'features/index.md': '---\ntype: Index\n---\n\n# Features\n',
          },
        ),
      );

      expect(result.errors.single.path, 'features/index.md');
      expect(
        result.errors.single.message,
        contains('only the bundle-root index.md may carry frontmatter'),
      );
    });

    test('the root index.md may only declare okf_version', () {
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          index: '---\nokf_version: "0.2"\ntitle: Bundle\n---\n\n# Root\n',
        ),
      );

      expect(
        result.errors.single.message,
        allOf(contains('may only declare'), contains('title')),
      );
    });

    test('root index.md with unparseable YAML errors instead of throwing', () {
      // Regression: an unguarded loadYaml here took the CLI down with a stack
      // trace instead of reporting a file-scoped diagnostic.
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          index: '---\nokf_version: [unclosed\n---\n\n# Root\n',
        ),
      );

      expect(result.isConformant, isFalse);
      expect(
        result.errors.single.message,
        contains('root index.md frontmatter is not parseable YAML'),
      );
    });

    test('a root index.md mapping without okf_version is flagged', () {
      // The fallback warning only fires when the whole block is missing, so a
      // `{}` frontmatter told consumers nothing and produced no issue.
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          index: '---\ntitle_placeholder_removed: ~\n---\n\n# Root\n',
        ),
      );

      expect(
        _joined(result.issues),
        contains('declares no `okf_version`'),
      );
    });

    test('log.md date headings must be ISO 8601', () {
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          extra: {
            'log.md': '# Log\n\n## May 22, 2026\n* **Update**: something\n',
          },
        ),
      );

      final error = result.errors.single;
      expect(error.path, 'log.md');
      expect(error.line, 3);
      expect(error.message, contains('must use ISO 8601'));
    });

    test('a fenced example in log.md is not read as a heading', () {
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          extra: {
            'log.md':
                '# Log\n\n## 2026-05-22\n* **Update**: x\n\n'
                '```markdown\n## example\n```\n',
          },
        ),
      );

      expect(result.errors, isEmpty);
    });

    test('a well-formed log.md passes', () {
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          extra: {
            'log.md': '# Log\n\n## 2026-05-22\n* **Update**: something\n',
          },
        ),
      );

      expect(result.isConformant, isTrue);
      expect(_messages(result), isEmpty);
    });

    test('a concept carrying only type fails every house rule', () {
      // §4.1 asks for nothing but `type`, so this document is spec-conformant.
      // This repo requires the rest, because a concept with no description, no
      // freshness date and no sources is precisely the one whose drift nobody
      // can detect — so each missing key is an error here, not a suggestion.
      final result = validateBundle(
        _bundle('---\ntype: Reference\n---\n\nx\n'),
      );

      expect(result.isConformant, isFalse);
      expect(
        _joined(result.errors),
        allOf(
          contains('`title`'),
          contains('`description`'),
          contains('`status`'),
          contains('`generated`'),
          contains('`stale_after`'),
          contains('`sources`'),
        ),
      );
      expect(result.warnings, isEmpty);
    });
  });

  group('required house keys carry values, not just colons', () {
    test('a key present but empty is flagged for each key', () {
      // `generated:` with nothing after it parses as YAML null. A
      // `containsKey` test passed it, and every per-field validator treats null
      // like an absent key and stays silent — so the concept validated clean
      // while carrying no freshness, provenance or lifecycle data at all.
      for (final key in [
        'title',
        'description',
        'status',
        'generated',
        'stale_after',
        'sources',
      ]) {
        final result = validateBundle(_bundle(_conceptWithEmpty(key)));

        expect(
          _joined(result.issues),
          contains('`$key` is empty'),
          reason: 'an empty `$key` must be reported',
        );
      }
    });

    test('a non-string title or description is flagged', () {
      for (final entry in {'title': '[a, b]', 'description': '42'}.entries) {
        final result = validateBundle(
          _bundle(
            _validFrontmatter.replaceFirst(
              RegExp('^${entry.key}:.*\$', multiLine: true),
              '${entry.key}: ${entry.value}',
            ),
          ),
        );

        expect(
          _joined(result.issues),
          contains('`${entry.key}` must be a non-empty string'),
          reason: '${entry.key}: ${entry.value} must be rejected',
        );
      }
    });

    test('a whitespace-only description is flagged', () {
      final result = validateBundle(
        _bundle(
          _validFrontmatter.replaceFirst(
            RegExp(r'^description:.*$', multiLine: true),
            "description: '   '",
          ),
        ),
      );

      expect(
        _joined(result.issues),
        contains('`description` must be a non-empty string'),
      );
    });
  });

  group('trust and lifecycle fields (§5)', () {
    test('a bare verified mapping is accepted as a one-element list', () {
      final result = validateBundle(
        _bundle(
          _concept(
            extra:
                'verified: { by: human:matthiasn, at: 2026-07-25T09:00:00Z }\n',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a verified list with several entries is accepted', () {
      final result = validateBundle(
        _bundle(
          _concept(
            extra: '''
verified:
  - { by: human:matthiasn, at: 2026-07-25T09:00:00Z }
  - { by: process:nightly-audit, at: 2026-07-26T02:00:00Z }
''',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('an actor outside the convention is flagged', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: someone, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: https://example.com/src
''',
          ),
        ),
      );

      expect(result.isConformant, isFalse);
      expect(
        result.errors.single.message,
        contains('does not follow the actor convention'),
      );
    });

    test('an unknown status value is flagged', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: provisional
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: https://example.com/src
''',
          ),
        ),
      );

      expect(
        result.errors.single.message,
        contains('draft, stable, deprecated'),
      );
    });

    test('stale_after must be an absolute date, not a duration', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('90d'))),
      );

      expect(
        result.errors.single.message,
        contains('absolute `YYYY-MM-DD` date'),
      );
    });

    test('an expired stale_after fails the build', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-01-31'))),
        today: DateTime.utc(2026, 7, 26),
      );

      // An error, not a warning: the date is a commitment to re-read by, and a
      // reminder nothing ever fails on is not a reminder.
      expect(result.isConformant, isFalse);
      expect(
        result.errors.single.message,
        contains('`stale_after` passed on 2026-01-31'),
      );
    });

    test('the day stale_after names is not yet an error', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-07-26'))),
        today: DateTime.utc(2026, 7, 26),
      );

      // Due today, not overdue — so it warns rather than failing the build.
      expect(result.isConformant, isTrue);
      expect(result.warnings.single.message, contains('0 day(s) away'));
    });

    test('a future stale_after is silent', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2027-01-31'))),
        today: DateTime.utc(2026, 7, 26),
      );

      expect(result.issues, isEmpty);
    });

    test('a stale_after inside the warning window warns without failing', () {
      // Without this, the first signal that a date had arrived was a red push,
      // for a whole subsystem at once — the dates are batched by subsystem.
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-08-05'))),
        today: DateTime.utc(2026, 7, 26),
      );

      expect(result.isConformant, isTrue);
      expect(
        result.warnings.single.message,
        allOf(contains('2026-08-05'), contains('10 day(s) away')),
      );
    });

    test('the day the window opens warns, the day before is silent', () {
      final onEdge = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-08-09'))),
        today: DateTime.utc(2026, 7, 26),
      );
      final outside = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-08-10'))),
        today: DateTime.utc(2026, 7, 26),
      );

      expect(onEdge.warnings, hasLength(1), reason: '14 days away');
      expect(outside.issues, isEmpty, reason: '15 days away');
    });

    test('expiry is not checked when the caller names no day', () {
      // Callers that omit `today` — every test fixture above — must not pick up
      // a clock-dependent result, or the suite would start failing on a date.
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2020-01-01'))),
      );

      expect(result.issues, isEmpty);
    });

    test('generated.at must be a datetime, not a bare date', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25 }
stale_after: 2027-01-31
sources:
  - id: src
    resource: https://example.com/src
''',
          ),
        ),
      );

      expect(result.errors.single.message, contains('ISO 8601 datetime'));
    });

    test('duplicate source ids are flagged because footnotes join on them', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: repo
    resource: https://example.com/a
  - id: repo
    resource: https://example.com/b
''',
          ),
        ),
      );

      expect(
        result.errors.single.message,
        contains('duplicate `sources[].id`'),
      );
    });

    test('a null sources value is flagged', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
''',
          ),
        ),
      );

      expect(
        _joined(result.errors),
        contains('present but null'),
      );
    });

    test('an empty sources list is flagged', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources: []
''',
          ),
        ),
      );

      expect(result.errors.single.message, contains('`sources` is empty'));
    });

    test('a bundle-absolute source resource is resolved in the bundle', () {
      // Checked by nothing before: validateRepoReferences skips `/` prefixes
      // because for a link that means bundle-relative, and the body-link
      // scanner never sees frontmatter.
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: gone
    resource: /domain/missing.md
''',
          ),
        ),
      );

      // Not `.single`: a source set that is entirely bundle-internal also trips
      // the provenance rule, which is correct for this fixture.
      expect(
        _joined(result.issues),
        allOf(
          contains('`sources[].resource`'),
          contains('does not exist in the bundle'),
        ),
      );
    });

    test('a non-string source resource is flagged', () {
      // `resource: 123` passed the presence check and was then skipped by
      // _resourceTargets (which only yields strings), so a present entry could
      // carry no usable code attribution.
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: repo
    resource: 123
''',
          ),
        ),
      );

      expect(
        result.errors.single.message,
        contains('`sources[].resource` must be a non-empty string'),
      );
    });

    test('a source entry without a resource is flagged', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: repo
    title: No resource here
''',
          ),
        ),
      );

      expect(
        result.errors.single.message,
        contains('`resource` is required'),
      );
    });
  });

  group('dates are real calendar values, not just the right shape', () {
    test('an out-of-range stale_after month is rejected', () {
      // DateTime.tryParse ROLLS OVER rather than rejecting: 2026-99-99 parses
      // as 2034-06-07, so a shape-only check accepted it.
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-99-99'))),
      );

      expect(
        result.errors.single.message,
        contains('absolute `YYYY-MM-DD` date'),
      );
    });

    test('a non-existent calendar day is rejected', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-02-30'))),
      );

      expect(
        result.errors.single.message,
        contains('absolute `YYYY-MM-DD` date'),
      );
    });

    test('a real leap day is accepted', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2028-02-29'))),
      );

      expect(result.issues, isEmpty);
    });

    test('an out-of-range generated.at time is rejected', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-01-01T99:99:99Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: https://example.com/src
''',
          ),
        ),
      );

      expect(result.errors.single.message, contains('ISO 8601 datetime'));
    });

    test('an offset-bearing timestamp is accepted', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00+02:00 }
stale_after: 2027-01-31
sources:
  - id: src
    resource: https://example.com/src
''',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a sources last_modified that is not a real date is flagged', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: https://example.com/src
    last_modified: 2026-13-45
''',
          ),
        ),
      );

      expect(
        result.errors.single.message,
        contains('`sources[].last_modified` must be `YYYY-MM-DD`'),
      );
    });

    test('a log heading that is not a real date is an error', () {
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          extra: {'log.md': '# Log\n\n## 2026-13-01\n* **Update**: x\n'},
        ),
      );

      expect(result.errors.single.message, contains('must use ISO 8601'));
    });
  });

  group('Attested Computation (§10)', () {
    test('missing runtime and computation are both flagged', () {
      final result = validateBundle(
        _bundle(
          _concept(type: 'Attested Computation', body: 'No computation here.'),
        ),
      );

      // Warnings on purpose: nothing in this bundle uses the type, so a missing
      // field is not worth failing a build over. Pinned, so an accidental
      // promotion to error is caught rather than silently accepted.
      final messages = _joined(result.warnings);
      expect(messages, contains('`runtime` is required'));
      expect(messages, contains('`# Computation` body section'));
      expect(result.errors, isEmpty);
    });

    test('a body computation section satisfies the requirement', () {
      final result = validateBundle(
        _bundle(
          _concept(
            type: 'Attested Computation',
            extra: 'runtime: bigquery\n',
            body: '# Computation\n\n    SELECT 1',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a non-path computation value does not satisfy the file form', () {
      // `computation: false` is non-null, so a presence test accepted it and
      // suppressed the "needs a computation" warning while pointing at nothing.
      for (final value in ['false', '[]', "''"]) {
        final result = validateBundle(
          _bundle(
            _concept(
              type: 'Attested Computation',
              extra: 'runtime: bigquery\ncomputation: $value\n',
              body: 'No computation section.',
            ),
          ),
        );

        final messages = _joined(result.warnings);
        expect(
          messages,
          contains('`computation` must be a path'),
          reason: 'computation: $value should be rejected as a path',
        );
        expect(result.errors, isEmpty, reason: 'stays advisory');
        expect(
          messages,
          contains('`# Computation` body section'),
          reason: 'computation: $value must not satisfy the file form',
        );
      }
    });

    test('a computation path satisfies the file form', () {
      final result = validateBundle(
        _bundle(
          _concept(
            type: 'Attested Computation',
            extra: 'runtime: bigquery\ncomputation: query.sql\n',
            body: 'No computation section.',
          ),
          extra: {'features/query.sql': ''},
        ),
      );

      expect(_joined(result.issues), isNot(contains('computation')));
    });
  });

  group('link resolution (§6)', () {
    test('a bundle-internal link with no target warns but does not fail', () {
      final result = validateBundle(
        _bundle(_concept(body: 'See [the sync feature](./sync.md).')),
      );

      expect(result.isConformant, isTrue);
      expect(
        result.warnings.single.message,
        contains('does not exist in the bundle'),
      );
    });

    test('a link to a sibling concept resolves', () {
      final result = validateBundle(
        _bundle(
          _concept(
            body: 'See [sync](./sync.md) and [the root](/index.md).',
          ),
          extra: {'features/sync.md': _validFrontmatter},
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a link to a directory resolves through its index.md', () {
      final result = validateBundle(
        _bundle(
          _concept(body: 'See [the architecture](../architecture/).'),
          extra: {
            'architecture/index.md':
                '# Architecture\n\n* [Overview](overview.md) - x\n',
            'architecture/overview.md': _validFrontmatter,
          },
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a link title in any of the three quotings is still scanned', () {
      // CommonMark allows "t", 't' and (t). Accepting only the double-quoted
      // form meant the whole link matched nothing, so the dangling target
      // inside it was never even offered for checking.
      for (final title in ['"source"', "'source'", '(source)']) {
        final result = validateBundle(
          _bundle(_concept(body: 'See [impl](./missing.md $title).')),
        );

        expect(
          _joined(result.issues),
          contains('`./missing.md` does not exist in the bundle'),
          reason: 'a $title title must not hide the target',
        );
      }
    });

    test('a link inside an indented code block is not resolved', () {
      // Indented blocks are code, so a link form documented in one never
      // renders as a link. Scanning them produced a false failure — the one
      // outcome worse than a miss, because it blocks a correct change.
      final result = validateBundle(
        _bundle(
          _concept(
            body:
                'Agents write pointers like this:\n\n'
                '    See [the module](./nope.md) for details.\n\n'
                'That is the form.',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('an indented list continuation still has live links', () {
      // Indentation only means code after a blank line; inside a list item it
      // is a continuation, where links do render and must resolve.
      final result = validateBundle(
        _bundle(
          _concept(
            body:
                '* A list item\n'
                '    with a [dangling](./nope.md) continuation link.\n',
          ),
        ),
      );

      expect(
        _joined(result.issues),
        contains('`./nope.md` does not exist in the bundle'),
      );
    });

    test('a link form quoted in code is not resolved as a link', () {
      final result = validateBundle(
        _bundle(
          _concept(
            body:
                'Reports may link tasks as `[Title](/tasks/<taskId>)`.\n\n'
                '```markdown\nSee [the missing one](./nope.md).\n```',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('an angle-bracket destination with whitespace is scanned', () {
      // The bracketed form exists to carry whitespace, so a whitespace-free
      // character class silently missed it.
      final result = validateBundle(
        _bundle(
          _concept(body: 'See [impl](<./missing file.md>).'),
        ),
      );

      expect(
        result.warnings.single.message,
        contains('does not exist in the bundle'),
      );
    });

    test('external URLs and anchors are not treated as bundle paths', () {
      final result = validateBundle(
        _bundle(
          _concept(
            body:
                'See [the spec](https://example.com/SPEC.md) and '
                '[above](#one-fact).',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });
  });

  group('resource and tags are required, not merely documented', () {
    // The convention has always described these as part of the frontmatter every
    // concept carries. Until they joined the required set, two architecture
    // concepts had no `resource` at all and validated clean.
    test('a concept with no resource is an error', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
tags: [speech]
$_houseKeys---

Body.
'''),
      );

      expect(
        result.errors.map((e) => e.message).single,
        contains('missing `resource`'),
      );
    });

    test('a concept with no tags is an error', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
resource: ../../lib/features/speech
$_houseKeys---

Body.
'''),
      );

      expect(
        result.errors.map((e) => e.message).single,
        contains('missing `tags`'),
      );
    });

    test('an empty resource string is an error, not just a present key', () {
      // `resource: ""` satisfied containsKey, is not null, and is skipped by both
      // reference checks — so it validated clean while the convention promised
      // that an empty value fails the build.
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
resource: ""
tags: [speech]
$_houseKeys---

Body.
'''),
      );

      expect(
        result.errors.map((e) => e.message).single,
        contains('`resource` must be a non-empty string'),
      );
    });

    test('an empty tags list is an error', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
resource: ../../lib/features/speech
tags: []
$_houseKeys---

Body.
'''),
      );

      expect(
        result.errors.map((e) => e.message).single,
        contains('`tags` must be a non-empty list'),
      );
    });

    test('a repo-wide concept may name the repository root as its subject', () {
      // `../..` from `knowledge/architecture/` normalizes to the empty string,
      // and neither `File('')` nor `Directory('')` exists — so a concept whose
      // subject genuinely is the whole repository used to read as a dangling
      // pointer.
      final issues = validateRepoReferences(
        files: {
          'architecture/platform-and-release.md':
              '---\ntype: Architecture\nresource: ../..\n---\n\nBody.\n',
        },
        bundleRoot: 'knowledge',
        repoFileExists: (path) => path == '.',
      );

      expect(issues, isEmpty);
    });
  });

  group('fenced blocks must close on their own line', () {
    // The shape that shipped: a mermaid diagram whose closing fence had a
    // sentence welded to it. CommonMark does not accept that as a close, so
    // every remaining line of the concept rendered as code — and the link
    // scanner, which is looser about where a block ends, saw nothing wrong.
    test('a closing fence with prose after it does not close the block', () {
      final result = validateBundle(
        _bundle(
          _concept(
            body: '```mermaid\nflowchart TD\n  A --> B\n``` and then prose.\n',
          ),
        ),
      );

      expect(
        result.errors.single.message,
        contains('is never closed by a line containing only the delimiter'),
      );
      // Whole-file line, not body-relative: 13 lines of frontmatter, a blank,
      // then the opening fence — so the reported number is the one an editor
      // jumps to.
      expect(result.errors.single.line, 15);
    });

    test('a properly closed block is silent', () {
      final result = validateBundle(
        _bundle(
          _concept(
            body: '```mermaid\nflowchart TD\n  A --> B\n```\n\nProse.\n',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a longer closing fence closes a shorter opener', () {
      final result = validateBundle(
        _bundle(_concept(body: '```dart\nvar x = 1;\n`````\n')),
      );

      expect(result.issues, isEmpty);
    });

    test('a four-space-indented fence is a literal, not a block', () {
      // CommonMark: at four spaces it is an indented code block — a documented
      // *example* of a fence. Trimming the indent made it open a real block, so a
      // doc showing mermaid syntax could be flagged as an unclosed diagram.
      final result = validateBundle(
        _bundle(
          _concept(
            body: 'How to write one:\n\n    ```mermaid\n    flowchart TD\n',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a three-space-indented fence is still a real block', () {
      final result = validateBundle(
        _bundle(_concept(body: '   ```mermaid\n   flowchart TD\n')),
      );

      expect(
        result.errors.single.message,
        contains('is never closed'),
      );
    });

    test('an indented closing fence still closes, up to three spaces', () {
      final result = validateBundle(
        _bundle(
          _concept(body: '```mermaid\nflowchart TD\n  A --> B\n   ```\n'),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a mixed closing run does not close the block', () {
      // CommonMark requires a uniform run; `~~ after ``` passed a "first
      // character matches, long enough" test and closed the block.
      final result = validateBundle(
        _bundle(_concept(body: '```mermaid\nflowchart TD\n`~~\n')),
      );

      expect(result.errors.single.message, contains('is never closed'));
    });

    test('a literal > inside a top-level fence does not close it', () {
      // Stripping `>` unconditionally made this marker read as the close, so an
      // unclosed fence validated clean.
      final result = validateBundle(
        _bundle(_concept(body: '```mermaid\nflowchart TD\n> ```\n')),
      );

      expect(result.errors.single.message, contains('is never closed'));
    });

    test('a blockquoted fence is recognised, and its close too', () {
      final result = validateBundle(
        _bundle(_concept(body: '> ```dart\n> var x = 1;\n> ```\n')),
      );

      expect(result.issues, isEmpty);
    });

    test('a quoted fence closes even when marker spacing varies', () {
      // The marker's trailing space is optional in CommonMark, so an exact-text
      // prefix match stripped neither the body nor the close and reported a valid
      // block as unclosed.
      final result = validateBundle(
        _bundle(_concept(body: '> ```dart\n>var x = 1;\n>```\n')),
      );

      expect(result.issues, isEmpty);
    });

    test('an unclosed blockquoted fence is still caught', () {
      final result = validateBundle(
        _bundle(_concept(body: '> ```dart\n> var x = 1;\n')),
      );

      expect(result.errors.single.message, contains('is never closed'));
    });

    test('a tilde block is not closed by backticks', () {
      final result = validateBundle(
        _bundle(_concept(body: '~~~text\nplain\n```\n')),
      );

      expect(
        result.errors.single.message,
        contains('opened with `~~~`'),
      );
    });

    test('an unterminated block at end of file is reported', () {
      final result = validateBundle(
        _bundle(_concept(body: '```mermaid\nflowchart TD\n  A --> B\n')),
      );

      expect(result.errors, hasLength(1));
    });
  });

  group('reference-style links', () {
    test('a reference definition with no bundle target warns', () {
      final result = validateBundle(
        _bundle(
          _concept(
            body: 'See [the sync feature][sync].\n\n[sync]: ./sync.md',
          ),
        ),
      );

      expect(
        result.warnings.single.message,
        contains('does not exist in the bundle'),
      );
    });

    test(
      'a reference definition escaping the bundle is resolved in the repo',
      () {
        // The anti-drift check has to see reference definitions too, or a
        // dangling code pointer passes `make okf_check`.
        final seen = <String>[];
        final issues = validateRepoReferences(
          files: {
            'features/speech.md': '''
---
type: Feature Module
title: Speech
---

Implemented by [the recorder][impl].

[impl]: ../../lib/features/speech/repository/recorder.dart
''',
          },
          bundleRoot: 'knowledge',
          repoFileExists: (path) {
            seen.add(path);
            return false;
          },
        );

        expect(seen, contains('lib/features/speech/repository/recorder.dart'));
        expect(issues.single.isError, isTrue);
        expect(issues.single.message, contains('has drifted from the code'));
      },
    );

    test(
      'an angle-bracket reference destination with whitespace is scanned',
      () {
        // The combination of the two forms: a reference definition whose
        // destination is angle-bracketed AND contains a space.
        final result = validateBundle(
          _bundle(
            _concept(
              body: 'See [impl][i].\n\n[i]: <./missing file.md>',
            ),
          ),
        );

        expect(
          result.warnings.single.message,
          contains('does not exist in the bundle'),
        );
      },
    );

    test('a relative bundle-internal source path is checked', () {
      // This fell between the two passes: `_validateBundleResources` only
      // looked at `/`-prefixed resources, and `validateRepoReferences` only
      // reports targets that *escape* the bundle. A `./missing.dart` was
      // therefore checked by nothing.
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: impl
    resource: ./missing.dart
''',
          ),
        ),
      );

      expect(
        _joined(result.issues),
        contains('`sources[].resource` `./missing.dart` does not exist'),
      );
    });

    test('a bare filename source path is checked, not read as prose', () {
      // `missing.dart` has neither a separator nor a leading dot, so the
      // path-shape test classified it as a §5.1 scope descriptor and exempted
      // it from resolution entirely.
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: impl
    resource: missing.dart
''',
          ),
        ),
      );

      expect(
        _joined(result.warnings),
        contains('`sources[].resource` `missing.dart` does not exist'),
      );
      // The severity split, pinned in one place: a bundle-internal target that
      // does not exist is a warning because §6.1 permits a forward pointer,
      // while a source set that never leaves the bundle is an error. Asserting
      // on `issues` alone would let either half flip unnoticed.
      expect(
        _joined(result.errors),
        contains('grounded in nothing the drift check can verify'),
      );
    });

    test('a source set that never leaves the bundle is not provenance', () {
      // A pointer at a sibling concept can never fail the drift check, so a
      // concept sourced only from one is grounded in nothing verifiable — the
      // exact shape `sources` exists to prevent.
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: sibling
    resource: ./sync.md
''',
          ),
          extra: {'features/sync.md': _validFrontmatter},
        ),
      );

      expect(
        _joined(result.errors),
        contains('grounded in nothing the drift check can verify'),
      );
    });

    test('one source leaving the bundle is enough', () {
      // Repo path, external URL and scope descriptor all count; the rule only
      // rejects a set that is *entirely* bundle-internal.
      for (final resource in [
        '../../lib/features/speech',
        'https://example.com/spec',
        'All queries in the analytics project',
      ]) {
        final result = validateBundle(
          _bundle(
            _concept(
              house:
                  '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: sibling
    resource: ./sync.md
  - id: real
    resource: $resource
''',
            ),
            extra: {'features/sync.md': _validFrontmatter},
          ),
        );

        expect(
          _joined(result.issues),
          isNot(contains('grounded in nothing')),
          reason: '$resource should count as provenance',
        );
      }
    });

    test('a bundle-absolute source alone is not provenance either', () {
      // `/index.md` resolves inside the bundle just like `./sync.md`.
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: root
    resource: /index.md
''',
          ),
        ),
      );

      expect(
        _joined(result.errors),
        contains('grounded in nothing the drift check can verify'),
      );
    });

    test('a prose scope descriptor ending in a period stays exempt', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: review
    resource: Discussed in the March design review.
''',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('bundle links in index.md are resolved', () {
      // Found by reverting the index link check and watching every test still
      // pass: an index whose entries point at renamed concepts is exactly the
      // drift the bundle's own navigation is supposed to surface.
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          index:
              '---\nokf_version: "0.2"\n---\n\n# Root\n\n'
              '* [Gone](features/gone.md) - x\n',
        ),
      );

      final indexIssues = result.issues.where((i) => i.path == 'index.md');
      expect(
        _joined(indexIssues),
        contains('`features/gone.md` does not exist in the bundle'),
      );
    });

    test('bundle links in log.md are resolved', () {
      // log.md was the one .md file whose bundle-internal links nothing
      // checked, though it is the file that links concepts most densely.
      final result = validateBundle(
        _bundle(
          _validFrontmatter,
          extra: {
            'log.md':
                '# Log\n\n## 2026-07-26\n\n'
                '* Split [gone](features/gone/overview.md) out.\n',
          },
        ),
      );

      final logIssues = result.issues.where((i) => i.path == 'log.md');
      expect(
        _joined(logIssues),
        contains('`features/gone/overview.md` does not exist in the bundle'),
      );
    });

    test('footnote definitions are not treated as paths (§5.1)', () {
      final result = validateBundle(
        _bundle(
          _concept(
            house: '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: rev-policy
    resource: https://example.com/policy
''',
            body:
                'The claim holds.[^rev-policy]\n\n'
                '[^rev-policy]: Revenue recognition policy',
          ),
        ),
      );

      expect(result.issues, isEmpty);
    });
  });

  group('repo references — the anti-drift check', () {
    Map<String, String> files() => {
      'features/speech.md': '''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
resource: ../../lib/features/speech
sources:
  - id: recorder
    resource: ../../lib/features/speech/repository/recorder.dart
    title: Recorder
---

Implemented by [the recorder](../../lib/features/speech/repository/recorder.dart).
''',
    };

    test('resolves concept-relative paths against the repo root', () {
      final seen = <String>[];
      final issues = validateRepoReferences(
        files: files(),
        bundleRoot: 'knowledge',
        repoFileExists: (path) {
          seen.add(path);
          return true;
        },
      );

      expect(issues, isEmpty);
      // knowledge/features/speech.md + ../../lib/... => lib/...
      expect(
        seen,
        containsAll(<String>[
          'lib/features/speech',
          'lib/features/speech/repository/recorder.dart',
        ]),
      );
    });

    test('a vanished source file is an error, not a warning', () {
      final issues = validateRepoReferences(
        files: files(),
        bundleRoot: 'knowledge',
        repoFileExists: (path) =>
            path != 'lib/features/speech/repository/recorder.dart',
      );

      expect(issues, hasLength(2)); // the source entry and the body link
      expect(issues.every((i) => i.isError), isTrue);
      expect(issues.first.message, contains('has drifted from the code'));
    });

    test('a reference climbing past the repo root is an error', () {
      final issues = validateRepoReferences(
        files: {
          'features/speech.md': '''
---
type: Feature Module
title: Speech
---

See [outside](../../../etc/passwd).
''',
        },
        bundleRoot: 'knowledge',
        repoFileExists: (_) => true,
      );

      expect(issues.single.message, contains('escapes the repository root'));
    });

    test('a path-shaped source with a space is still resolved', () {
      // Exempting every spaced string as a "scope descriptor" let a typo like
      // `../../lib/missing file.dart` skip the anti-drift check entirely.
      final seen = <String>[];
      final issues = validateRepoReferences(
        files: {
          'features/speech.md': '''
---
type: Feature Module
title: Speech
sources:
  - id: typo
    resource: ../../lib/features/speech/missing file.dart
---

Body.
''',
        },
        bundleRoot: 'knowledge',
        repoFileExists: (path) {
          seen.add(path);
          return false;
        },
      );

      expect(seen, contains('lib/features/speech/missing file.dart'));
      expect(issues.single.isError, isTrue);
    });

    test('scope-descriptor sources are not resolved as paths (§5.1)', () {
      final issues = validateRepoReferences(
        files: {
          'features/speech.md': '''
---
type: Feature Module
title: Speech
sources:
  - id: scope
    resource: all audio entries recorded on device
---

Body.
''',
        },
        bundleRoot: 'knowledge',
        repoFileExists: (_) => fail('should not resolve a scope descriptor'),
      );

      expect(issues, isEmpty);
    });

    test('bundle-internal and absolute references are left alone', () {
      final issues = validateRepoReferences(
        files: {
          'features/speech.md': '''
---
type: Feature Module
title: Speech
---

See [sync](./sync.md), [root](/index.md) and [spec](https://example.com).
''',
        },
        bundleRoot: 'knowledge',
        repoFileExists: (_) => fail('no repo lookup expected'),
      );

      expect(issues, isEmpty);
    });
  });

  group('bundle root normalisation', () {
    test('an absolute root inside the working directory becomes relative', () {
      // The validator resolves `../../lib/...` against the bundle root, so an
      // absolute root made every code pointer resolve outside the checkout and
      // a clean bundle reported hundreds of drift errors — for nothing but the
      // shape of the argument.
      expect(
        repoRelativeBundleRoot(
          '/home/me/lotti/knowledge',
          workingDirectory: '/home/me/lotti',
        ),
        'knowledge',
      );
    });

    test('the working directory itself normalises to a dot', () {
      expect(
        repoRelativeBundleRoot(
          '/home/me/lotti',
          workingDirectory: '/home/me/lotti',
        ),
        '.',
      );
    });

    test('a sibling directory sharing a name prefix is not stripped', () {
      // `/home/me/lotti-sibling` starts with `/home/me/lotti` as a string but is
      // not inside it.
      expect(
        repoRelativeBundleRoot(
          '/home/me/lotti-sibling/knowledge',
          workingDirectory: '/home/me/lotti',
        ),
        isNull,
      );
    });

    test('a relative root is handed through untouched', () {
      for (final root in ['knowledge', '../lotti/knowledge', './knowledge']) {
        expect(
          repoRelativeBundleRoot(root, workingDirectory: '/home/me/lotti'),
          root,
        );
      }
    });
  });

  group('document splitting', () {
    test('separates frontmatter from body', () {
      final document = splitDocument(_validFrontmatter);

      expect(document.frontmatterYaml, contains('type: Feature Module'));
      expect(document.body.trim(), 'Body.');
    });

    test('reports no frontmatter when the file does not open with ---', () {
      final document = splitDocument('# Heading\n\n---\n\nnot frontmatter\n');

      expect(document.frontmatterYaml, isNull);
      expect(document.body, startsWith('# Heading'));
    });

    test('handles CRLF line endings', () {
      final document = splitDocument(
        '---\r\ntype: Reference\r\n---\r\n\r\nBody.',
      );

      expect(document.frontmatterYaml, contains('type: Reference'));
      expect(document.body.trim(), 'Body.');
    });
  });

  group('the real knowledge/ bundle', () {
    test('is conformant and every code pointer resolves', () {
      final root = Directory('knowledge');
      expect(root.existsSync(), isTrue, reason: 'run from the repository root');

      final files = <String, String>{};
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File) continue;
        final relative = entity.path.substring(root.path.length + 1);
        files[relative] = entity.path.endsWith('.md')
            ? entity.readAsStringSync()
            : '';
      }

      final result = validateBundle(files);
      final repoIssues = validateRepoReferences(
        files: files,
        bundleRoot: 'knowledge',
        repoFileExists: (path) =>
            File(path).existsSync() || Directory(path).existsSync(),
      );

      expect(
        [...result.errors, ...repoIssues].map((i) => i.toString()),
        isEmpty,
      );
      expect(result.conceptCount, greaterThan(0));
    });
  });
}

/// House keys with `stale_after` replaced, for the freshness-date cases.
String _houseWithStaleAfter(String value) =>
    '''
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: $value
sources:
  - id: src
    resource: https://example.com/src
''';

/// A complete concept with [key] present but carrying no value.
///
/// Built field by field rather than by regex surgery on [_validFrontmatter]:
/// blanking the `sources:` line alone leaves its indented list items behind, so
/// the key is not actually empty. Flow style keeps every value on one line.
String _conceptWithEmpty(String key) {
  final fields = <String, String>{
    'type': 'Feature Module',
    'title': 'Speech',
    'description': 'Audio capture.',
    'status': 'stable',
    'generated': '{ by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }',
    'stale_after': '2027-01-31',
    'sources': '[{ id: src, resource: https://example.com/src }]',
  };
  final lines = fields.entries.map(
    (e) => e.key == key ? '${e.key}:' : '${e.key}: ${e.value}',
  );
  return '---\n${lines.join('\n')}\n---\n\nBody.\n';
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
