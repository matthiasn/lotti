import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the validator is a repo tool, not part of the `lotti`
// package, so it has no `package:` URI.
import '../../../tool/okf/okf_validator.dart';

/// Minimal valid frontmatter, used as the baseline every negative case mutates.
const _validFrontmatter = '''
---
type: Feature Module
title: Speech
description: Audio capture and playback.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

Body.
''';

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
        _bundle('''
---
type: [unclosed
---

Body.
'''),
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
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

Body.
'''),
      );

      expect(
        result.errors.map((e) => e.message).single,
        contains('missing the required `type`'),
      );
    });

    test('an empty type string is rejected as firmly as a missing one', () {
      final result = validateBundle(
        _bundle('''
---
type: "   "
---

Body.
'''),
      );

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

      expect(
        result.errors.single.path,
        'features/index.md',
      );
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
      // ... but the house rules still ask for the recommended keys.
      expect(
        result.warnings.map((w) => w.message).join(' '),
        allOf(
          contains('`title`'),
          contains('`description`'),
          contains('`status`'),
          contains('`generated`'),
        ),
      );
    });
  });

  group('trust and lifecycle fields (§5)', () {
    test('a bare verified mapping is accepted as a one-element list', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
verified: { by: human:matthiasn, at: 2026-07-25T09:00:00Z }
---

Body.
'''),
      );

      expect(result.issues, isEmpty);
    });

    test('a verified list with several entries is accepted', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
verified:
  - { by: human:matthiasn, at: 2026-07-25T09:00:00Z }
  - { by: process:nightly-audit, at: 2026-07-26T02:00:00Z }
---

Body.
'''),
      );

      expect(result.issues, isEmpty);
    });

    test('an actor outside the convention is flagged', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: someone, at: 2026-07-25T22:30:00Z }
---

Body.
'''),
      );

      expect(result.isConformant, isTrue);
      expect(
        result.warnings.single.message,
        contains('does not follow the actor convention'),
      );
    });

    test('an unknown status value is flagged', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: provisional
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

Body.
'''),
      );

      expect(
        result.warnings.single.message,
        contains('draft, stable, deprecated'),
      );
    });

    test('stale_after must be an absolute date, not a duration', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 90d
---

Body.
'''),
      );

      expect(
        result.warnings.single.message,
        contains('absolute `YYYY-MM-DD` date'),
      );
    });

    test('generated.at must be a datetime, not a bare date', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25 }
---

Body.
'''),
      );

      expect(
        result.warnings.single.message,
        contains('ISO 8601 datetime'),
      );
    });

    test('duplicate source ids are flagged because footnotes join on them', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
sources:
  - id: repo
    resource: https://example.com/a
  - id: repo
    resource: https://example.com/b
---

Body.
'''),
      );

      expect(
        result.warnings.single.message,
        contains('duplicate `sources[].id`'),
      );
    });

    test('a source entry without a resource is flagged', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
sources:
  - id: repo
    title: No resource here
---

Body.
'''),
      );

      expect(
        result.warnings.single.message,
        contains('`resource` is required'),
      );
    });
  });

  group('Attested Computation (§10)', () {
    test('missing runtime and computation are both flagged', () {
      final result = validateBundle(
        _bundle('''
---
type: Attested Computation
title: Revenue
description: Revenue for a year.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

No computation here.
'''),
      );

      final messages = _messages(result).join(' ');
      expect(messages, contains('`runtime` is required'));
      expect(messages, contains('`# Computation` body section'));
    });

    test('a body computation section satisfies the requirement', () {
      final result = validateBundle(
        _bundle('''
---
type: Attested Computation
title: Revenue
description: Revenue for a year.
status: stable
runtime: bigquery
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

# Computation

    SELECT 1
'''),
      );

      expect(result.issues, isEmpty);
    });
  });

  group('link resolution (§6)', () {
    test('a bundle-internal link with no target warns but does not fail', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

See [the sync feature](./sync.md).
'''),
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
          '''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

See [the sync feature](./sync.md) and [the root](/index.md).
''',
          extra: {'features/sync.md': _validFrontmatter},
        ),
      );

      expect(result.issues, isEmpty);
    });

    test('a link to a directory resolves through its index.md', () {
      final result = validateBundle(
        _bundle(
          '''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

See [the architecture](../architecture/).
''',
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
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

Reports may link tasks as `[Title](/tasks/<taskId>)`.

```markdown
See [the missing one](./nope.md).
```
'''),
      );

      expect(result.issues, isEmpty);
    });

    test('external URLs and anchors are not treated as bundle paths', () {
      final result = validateBundle(
        _bundle('''
---
type: Feature Module
title: Speech
description: Audio capture.
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
---

See [the spec](https://example.com/SPEC.md) and [above](#one-fact).
'''),
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
      expect(
        root.existsSync(),
        isTrue,
        reason: 'run from the repository root',
      );

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
