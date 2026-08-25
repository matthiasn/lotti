/// Checks the release-note fragments in `changelog.d/`.
///
/// **Why fragments exist.** `CHANGELOG.md`, the Flathub metainfo and
/// `pubspec.yaml` are all written at the top, in the same few lines, by every
/// pull request that lands. Git merges edits in different places; it cannot
/// merge two rewrites of the same lines. So the first PR to merge left every
/// other open PR conflicted, over prose that had nothing to do with the code.
///
/// A fragment is one new file per pull request. Two files that did not exist
/// before cannot conflict, so the shared files are written exactly once — by
/// the release, which is the only change allowed to touch them.
///
/// **What this guard enforces.**
///
/// *Fragments*: a name that sorts and never collides (`YYYY-MM-DD-slug.md`),
/// and a body that is nothing but `### <Type>` sections of bullets — the exact
/// shape the release pastes into `CHANGELOG.md`. Anything the release would
/// have to rewrite by hand (a version heading, prose loose at the top of the
/// file, an unwrapped paragraph) is caught here instead, while the author who
/// wrote it is still in context.
///
/// *The released version*: `pubspec.yaml`, the top section of `CHANGELOG.md`
/// and the newest `<release>` in the metainfo must agree. Under the fragment
/// flow the three move together in one release change and are identical the
/// rest of the time, so any disagreement means a release went out half-written
/// — the metainfo lagging a version behind is what Flathub ships to users.
library;

import 'dart:io';

/// Directory holding the unreleased fragments, relative to the repository root.
const fragmentDirPath = 'changelog.d';

const changelogPath = 'CHANGELOG.md';
const metainfoPath = 'flatpak/com.matthiasn.lotti.metainfo.xml';
const pubspecPath = 'pubspec.yaml';

/// Keep a Changelog section types, in the order a release assembles them.
///
/// The order is the spec's, not this repository's history: released sections
/// used to come out in whatever order the entries were appended, and one
/// version carries `### Fixed` three separate times. Assembling from fragments
/// is the chance to fix that, so the list is ordered and the release follows it.
const sectionTypes = <String>[
  'Added',
  'Changed',
  'Deprecated',
  'Removed',
  'Fixed',
  'Security',
];

/// `YYYY-MM-DD-some-slug.md`.
///
/// The date makes collisions between two branches unlikely and sorts the
/// folder chronologically; the slug says which change it belongs to. A PR
/// number would be better at both, but is not known until after the file has
/// to be written.
final RegExp fragmentNamePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$',
);

final RegExp _sectionHeading = RegExp(r'^###\s+(.*?)\s*$');
final RegExp _pubspecVersion = RegExp(
  r'^version:\s*(\S+)\s*$',
  multiLine: true,
);
final RegExp _changelogVersion = RegExp(r'^##\s+\[([^\]]+)\]', multiLine: true);
final RegExp _metainfoRelease = RegExp(
  r'<release\s+version="([^"]*)"\s+date="([^"]*)"',
);
final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Prose in this repository wraps around 78 columns. The threshold sits well
/// above that: the point is not to police the wrap, it is to catch a paragraph
/// pasted as one long line, which reads as a 400-character diff for every later
/// edit to it.
const maxLineLength = 100;

enum Severity { error, warning }

/// One problem, phrased as something the author can act on.
class Issue {
  const Issue(this.severity, this.where, this.message);

  final Severity severity;

  /// `path` or `path:line`, so an editor can jump straight to it.
  final String where;

  final String message;

  @override
  String toString() =>
      '${severity == Severity.error ? 'error' : 'warning'}: $where: $message';
}

/// Everything one run found.
class GuardResult {
  const GuardResult(this.issues, this.fragmentCount);

  final List<Issue> issues;

  /// How many valid-named fragments were seen — the release's work queue.
  final int fragmentCount;

  List<Issue> get errors =>
      issues.where((i) => i.severity == Severity.error).toList();

  List<Issue> get warnings =>
      issues.where((i) => i.severity == Severity.warning).toList();
}

/// Checks one fragment's body.
///
/// [path] is used only for reporting. [content] is the file verbatim.
List<Issue> validateFragmentBody({
  required String path,
  required String content,
}) {
  final issues = <Issue>[];
  void err(int line, String message) =>
      issues.add(Issue(Severity.error, '$path:$line', message));
  void warn(int line, String message) =>
      issues.add(Issue(Severity.warning, '$path:$line', message));

  if (content.trim().isEmpty) {
    return [Issue(Severity.error, path, 'the fragment is empty')];
  }

  final lines = content.split('\n');
  final seenTypes = <String>{};
  String? currentType;
  var currentTypeLine = 0;
  var bulletsInSection = 0;

  void closeSection() {
    if (currentType != null && bulletsInSection == 0) {
      err(
        currentTypeLine,
        '`### $currentType` has no entries — every section needs at least one '
        '`- ` bullet',
      );
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineNo = i + 1;
    if (line.trim().isEmpty) continue;

    if (line.length > maxLineLength) {
      warn(
        lineNo,
        'line is ${line.length} characters — wrap prose at about 78 columns, '
        'the way CHANGELOG.md does',
      );
    }

    final heading = _sectionHeading.firstMatch(line);
    if (heading != null) {
      final type = heading.group(1)!;
      if (!sectionTypes.contains(type)) {
        err(
          lineNo,
          'unknown section `### $type` — use one of ${sectionTypes.join(', ')}',
        );
      } else if (!seenTypes.add(type)) {
        warn(
          lineNo,
          '`### $type` appears twice in one fragment — fold the entries into '
          'the first section',
        );
      }
      closeSection();
      currentType = type;
      currentTypeLine = lineNo;
      bulletsInSection = 0;
      continue;
    }

    if (line.startsWith('#')) {
      err(
        lineNo,
        'a fragment carries `### <Type>` sections only — the version heading '
        'belongs to the release that assembles it',
      );
      continue;
    }

    if (currentType == null) {
      err(
        lineNo,
        'content before the first `### <Type>` heading — a fragment opens with '
        'its section',
      );
      continue;
    }

    if (line.startsWith('- ')) {
      bulletsInSection++;
      if (!line.startsWith('- **')) {
        warn(
          lineNo,
          'entry does not open with a bold headline — the house style is '
          '`- **What changed, in one sentence.** Then the detail.`',
        );
      }
      continue;
    }

    // Continuation prose and nested bullets, both indented, both fine.
    if (line.startsWith('  ')) continue;

    err(
      lineNo,
      'stray line — an entry is a `- ` bullet and its continuation lines are '
      'indented by two spaces',
    );
  }

  closeSection();

  return issues;
}

/// Checks that the released version agrees across the three shared files.
List<Issue> validateReleasedVersion({
  required String pubspec,
  required String changelog,
  required String metainfo,
}) {
  final issues = <Issue>[];

  final pubspecMatch = _pubspecVersion.firstMatch(pubspec);
  if (pubspecMatch == null) {
    return [const Issue(Severity.error, pubspecPath, 'no `version:` line')];
  }
  // `1.0.13+4352` — the build number rides along on the tag, not on the notes.
  final version = pubspecMatch.group(1)!.split('+').first;

  final changelogMatch = _changelogVersion.firstMatch(changelog);
  if (changelogMatch == null) {
    issues.add(
      const Issue(
        Severity.error,
        changelogPath,
        'no `## [version]` section at all',
      ),
    );
  } else if (changelogMatch.group(1) != version) {
    issues.add(
      Issue(
        Severity.error,
        changelogPath,
        'newest section is `## [${changelogMatch.group(1)}]` but pubspec.yaml '
        'says $version — the release left one of them behind',
      ),
    );
  }

  final metainfoMatch = _metainfoRelease.firstMatch(metainfo);
  if (metainfoMatch == null) {
    issues.add(
      const Issue(
        Severity.error,
        metainfoPath,
        'no `<release version="..." date="...">` entry',
      ),
    );
    return issues;
  }
  if (metainfoMatch.group(1) != version) {
    issues.add(
      Issue(
        Severity.error,
        metainfoPath,
        'newest release is ${metainfoMatch.group(1)} but pubspec.yaml says '
        '$version — Flathub would ship notes for the wrong version',
      ),
    );
  }
  if (!_isoDate.hasMatch(metainfoMatch.group(2)!)) {
    issues.add(
      Issue(
        Severity.error,
        metainfoPath,
        'release date "${metainfoMatch.group(2)}" is not YYYY-MM-DD',
      ),
    );
  }

  return issues;
}

/// Runs every check against the repository rooted at [root].
GuardResult scan({required Directory root}) {
  final issues = <Issue>[];
  var fragmentCount = 0;

  final dir = Directory('${root.path}/$fragmentDirPath');
  if (!dir.existsSync()) {
    issues.add(
      const Issue(
        Severity.error,
        fragmentDirPath,
        'directory is missing — it holds the unreleased notes and must exist '
        'even when empty',
      ),
    );
  } else {
    final entries = dir.listSync()..sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final reportPath = '$fragmentDirPath/$name';
      if (entry is! File) {
        issues.add(
          Issue(
            Severity.error,
            reportPath,
            'only fragment files live here — a note inside a subdirectory is '
            'read by nobody and would never ship',
          ),
        );
        continue;
      }
      final file = entry;
      if (name == 'README.md' || name == '.gitkeep') continue;
      if (!fragmentNamePattern.hasMatch(name)) {
        issues.add(
          Issue(
            Severity.error,
            reportPath,
            'name does not match YYYY-MM-DD-lower-kebab-slug.md',
          ),
        );
        continue;
      }
      fragmentCount++;
      issues.addAll(
        validateFragmentBody(
          path: reportPath,
          content: file.readAsStringSync(),
        ),
      );
    }
  }

  String? read(String relative) {
    final file = File('${root.path}/$relative');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  final pubspec = read(pubspecPath);
  final changelog = read(changelogPath);
  final metainfo = read(metainfoPath);
  if (pubspec == null || changelog == null || metainfo == null) {
    for (final missing in {
      pubspecPath: pubspec,
      changelogPath: changelog,
      metainfoPath: metainfo,
    }.entries.where((e) => e.value == null)) {
      issues.add(Issue(Severity.error, missing.key, 'file not found'));
    }
  } else {
    issues.addAll(
      validateReleasedVersion(
        pubspec: pubspec,
        changelog: changelog,
        metainfo: metainfo,
      ),
    );
  }

  return GuardResult(issues, fragmentCount);
}
