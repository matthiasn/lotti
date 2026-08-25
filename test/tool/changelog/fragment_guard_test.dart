import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: the guard is a repo tool, not part of the `lotti` package,
// so it has no `package:` URI.
import '../../../tool/changelog/fragment_guard.dart';

const _pubspec = '''
name: lotti
version: 1.0.13+4352
''';

const _changelog = '''
# Changelog

## [1.0.13]
### Fixed
- **A released thing.** Detail.

## [1.0.12]
### Fixed
- **An older thing.** Detail.
''';

const _metainfo = '''
<component type="desktop-application">
  <releases>
    <release version="1.0.13" date="2026-08-24">
      <description>
        <p>Fixed: a released thing. Detail.</p>
      </description>
    </release>
  </releases>
</component>
''';

/// A well-formed fragment, used wherever the body is not what is under test.
const _validFragment = '''
### Fixed
- **A habit reminder no longer rings in UTC.** It now uses the zone the device
  is actually in.
''';

/// Lays out a throwaway repository and scans it.
///
/// Each test gets its own directory so a stray file cannot leak between them.
GuardResult scanFixture(
  Map<String, String> fragments, {
  String pubspec = _pubspec,
  String changelog = _changelog,
  String metainfo = _metainfo,
  bool withFragmentDir = true,
}) {
  final root = Directory.systemTemp.createTempSync('changelog_guard_test');
  addTearDown(() => root.deleteSync(recursive: true));

  void write(String relative, String content) {
    File('${root.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  write(pubspecPath, pubspec);
  write(changelogPath, changelog);
  write(metainfoPath, metainfo);
  if (withFragmentDir) {
    Directory('${root.path}/$fragmentDirPath').createSync(recursive: true);
  }
  fragments.forEach(
    (name, content) => write('$fragmentDirPath/$name', content),
  );

  return scan(root: root);
}

List<String> messages(Iterable<Issue> issues) =>
    issues.map((i) => i.message).toList();

Matcher hasMessage(String needle) => predicate<Issue>(
  (i) => i.message.contains(needle),
  'an issue mentioning "$needle"',
);

void main() {
  group('fragment body', () {
    test('a well-formed fragment produces nothing at all', () {
      final result = scanFixture({
        '2026-08-25-habit-reminder.md': _validFragment,
      });

      expect(result.issues, isEmpty);
      expect(result.fragmentCount, 1);
    });

    test('one file may carry several sections', () {
      final result = scanFixture({
        '2026-08-25-two-sided.md': '''
### Added
- **A new thing.** Detail.

### Fixed
- **An old thing.** Detail.
''',
      });

      expect(result.issues, isEmpty);
    });

    test('an unknown section type is rejected, and names the valid ones', () {
      final result = scanFixture({
        '2026-08-25-typo.md': '### Improved\n- **A thing.** Detail.\n',
      });

      expect(result.errors, [hasMessage('unknown section `### Improved`')]);
      expect(result.errors.single.message, contains('Fixed'));
    });

    test('prose before the first heading is rejected', () {
      final result = scanFixture({
        '2026-08-25-loose.md':
            'This PR fixes a thing.\n\n'
            '### Fixed\n- **A thing.** Detail.\n',
      });

      expect(result.errors, [hasMessage('content before the first')]);
    });

    test('a section with no entries is rejected, named by its type', () {
      final result = scanFixture({
        '2026-08-25-hollow.md': '### Fixed\n\n### Added\n- **A thing.** X.\n',
      });

      expect(result.errors, [hasMessage('`### Fixed` has no entries')]);
    });

    test('the last section is checked for entries too', () {
      final result = scanFixture({
        '2026-08-25-trailing.md': '### Added\n- **A thing.** X.\n\n### Fixed\n',
      });

      expect(result.errors, [hasMessage('`### Fixed` has no entries')]);
    });

    test('a version heading belongs to the release, not to a fragment', () {
      final result = scanFixture({
        '2026-08-25-versioned.md':
            '## [1.0.14]\n### Fixed\n- **A thing.** Detail.\n',
      });

      expect(result.errors, [hasMessage('version heading')]);
    });

    test('an unindented continuation line is rejected', () {
      final result = scanFixture({
        '2026-08-25-unindented.md':
            '### Fixed\n- **A thing.** Detail that\nwrapped to column zero.\n',
      });

      expect(result.errors, [hasMessage('stray line')]);
    });

    test('indented continuations and nested bullets are fine', () {
      final result = scanFixture({
        '2026-08-25-nested.md': '''
### Changed
- **A thing has parts.** Namely:
  - one part
  - another part

  and a closing thought.
''',
      });

      expect(result.issues, isEmpty);
    });

    test('an empty fragment is rejected', () {
      final result = scanFixture({'2026-08-25-blank.md': '\n\n'});

      expect(result.errors, [hasMessage('empty')]);
    });

    test('an entry without a bold headline warns but does not fail', () {
      final result = scanFixture({
        '2026-08-25-plain.md': '### Fixed\n- Fixed the thing.\n',
      });

      expect(result.errors, isEmpty);
      expect(result.warnings, [hasMessage('bold headline')]);
    });

    test('a paragraph pasted as one long line warns', () {
      final result = scanFixture({
        '2026-08-25-unwrapped.md':
            '### Fixed\n- **A thing.** ${'detail ' * 30}\n',
      });

      expect(result.errors, isEmpty);
      expect(result.warnings, [hasMessage('characters')]);
    });

    test('a repeated section type warns, so the release need not merge it', () {
      final result = scanFixture({
        '2026-08-25-repeated.md':
            '### Fixed\n- **One.** X.\n\n### Fixed\n- **Two.** Y.\n',
      });

      expect(result.errors, isEmpty);
      expect(result.warnings, [hasMessage('appears twice')]);
    });
  });

  group('fragment names', () {
    test('README.md is documentation, not an unreleased note', () {
      final result = scanFixture({
        'README.md': '# Unreleased notes\n\nProse.\n',
      });

      expect(result.issues, isEmpty);
      expect(result.fragmentCount, 0);
    });

    test('a name without the date prefix is rejected', () {
      final result = scanFixture({'habit-reminder.md': _validFragment});

      expect(result.errors, [hasMessage('YYYY-MM-DD')]);
      expect(result.fragmentCount, 0);
    });

    test('a name that is not kebab-case is rejected', () {
      final result = scanFixture({
        '2026-08-25-Habit_Reminder.md': _validFragment,
      });

      expect(result.errors, [hasMessage('YYYY-MM-DD')]);
    });

    test('a badly named file is not then read for body errors', () {
      final result = scanFixture({'notes.txt': 'whatever this is'});

      expect(result.errors, hasLength(1));
      expect(result.errors.single.where, endsWith('notes.txt'));
    });

    test('a fragment hidden in a subdirectory is reported, not ignored', () {
      final result = scanFixture({
        'nested/2026-08-25-buried.md': _validFragment,
      });

      expect(result.errors, [hasMessage('subdirectory')]);
      expect(result.fragmentCount, 0);
    });

    test('several fragments are all counted and all checked', () {
      final result = scanFixture({
        '2026-08-24-first.md': _validFragment,
        '2026-08-25-second.md': _validFragment,
      });

      expect(result.fragmentCount, 2);
      expect(result.issues, isEmpty);
    });
  });

  group('released version', () {
    test('agreement across the three shared files passes', () {
      expect(scanFixture(const {}).issues, isEmpty);
    });

    test('the build number is not part of the comparison', () {
      final result = scanFixture(
        const {},
        pubspec: 'name: lotti\nversion: 1.0.13+9999\n',
      );

      expect(result.issues, isEmpty);
    });

    test('a metainfo left a version behind fails, and says why it matters', () {
      final result = scanFixture(
        const {},
        pubspec: 'name: lotti\nversion: 1.0.14+4353\n',
        changelog: '# Changelog\n\n## [1.0.14]\n### Fixed\n- **A.** B.\n',
      );

      expect(result.errors, [hasMessage('newest release is 1.0.13')]);
      expect(result.errors.single.message, contains('Flathub'));
    });

    test('a CHANGELOG left behind fails', () {
      final result = scanFixture(
        const {},
        pubspec: 'name: lotti\nversion: 1.0.14+4353\n',
        metainfo: _metainfo.replaceAll('1.0.13', '1.0.14'),
      );

      expect(messages(result.errors), [
        contains('newest section is `## [1.0.13]`'),
      ]);
    });

    test('a release date that is not YYYY-MM-DD fails', () {
      final result = scanFixture(
        const {},
        metainfo: _metainfo.replaceAll('2026-08-24', '24.08.2026'),
      );

      expect(result.errors, [hasMessage('not YYYY-MM-DD')]);
    });

    test(
      'a missing changelog.d directory fails — it must exist when empty',
      () {
        final result = scanFixture(const {}, withFragmentDir: false);

        expect(result.errors, [hasMessage('directory is missing')]);
      },
    );
  });
}
