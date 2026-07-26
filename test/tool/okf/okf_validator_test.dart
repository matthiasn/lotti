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

    test('a minimal concept carrying only type is conformant (§4.1)', () {
      final result = validateBundle(
        _bundle('---\ntype: Reference\n---\n\nx\n'),
      );

      expect(result.isConformant, isTrue);
      // ... but the house rules still ask for every recommended key.
      expect(
        _joined(result.warnings),
        allOf(
          contains('`title`'),
          contains('`description`'),
          contains('`status`'),
          contains('`generated`'),
          contains('`stale_after`'),
          contains('`sources`'),
        ),
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

      expect(result.isConformant, isTrue);
      expect(
        result.warnings.single.message,
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
        result.warnings.single.message,
        contains('draft, stable, deprecated'),
      );
    });

    test('stale_after must be an absolute date, not a duration', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('90d'))),
      );

      expect(
        result.warnings.single.message,
        contains('absolute `YYYY-MM-DD` date'),
      );
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

      expect(result.warnings.single.message, contains('ISO 8601 datetime'));
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
        result.warnings.single.message,
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
        _joined(result.warnings),
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

      expect(result.warnings.single.message, contains('`sources` is empty'));
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

      expect(
        result.warnings.single.message,
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
        result.warnings.single.message,
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
        result.warnings.single.message,
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
        result.warnings.single.message,
        contains('absolute `YYYY-MM-DD` date'),
      );
    });

    test('a non-existent calendar day is rejected', () {
      final result = validateBundle(
        _bundle(_concept(house: _houseWithStaleAfter('2026-02-30'))),
      );

      expect(
        result.warnings.single.message,
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

      expect(result.warnings.single.message, contains('ISO 8601 datetime'));
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
        result.warnings.single.message,
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

      final messages = _joined(result.issues);
      expect(messages, contains('`runtime` is required'));
      expect(messages, contains('`# Computation` body section'));
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

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
