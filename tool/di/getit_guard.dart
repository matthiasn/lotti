/// Ratchets service location through `getIt` down to the composition root.
///
/// GetIt is where a service generation is *built*: `lib/get_it*.dart`,
/// `lib/app_bootstrap.dart` and `lib/main.dart` construct and register the
/// singletons, and `buildProviderOverrides` hands them to Riverpod. Everywhere
/// else a `getIt<T>()` lookup is a hidden dependency — invisible in the
/// constructor, unreachable by a `ProviderScope` override, and the reason tests
/// register 1,800 singletons by hand. Widgets and controllers should `ref.watch`
/// a provider; plain services should take what they need as constructor
/// arguments.
///
/// Two counts per file, both ratcheted:
///
/// - **lookups** — `getIt<T>()`, `getIt.get<T>()` and `GetIt.I` / `GetIt.instance`.
/// - **isRegistered** — `getIt.isRegistered<T>()`. Almost every one of these is
///   a test seam ("use the logger if one is wired") rather than a genuinely
///   optional service, and each disappears with the lookup it guards.
///
/// **The ratchet.** A thousand lookups cannot move in one pull request, and a
/// check that is expected to fail teaches everyone to ignore it. The baseline
/// records what each file still carries: a file may shrink or disappear, never
/// grow, and a file absent from the baseline may not introduce any.
library;

import 'dart:convert';
import 'dart:io';

final RegExp _lookup = RegExp(
  r'(?<![A-Za-z0-9_$])(?:getIt(?:\.get)?\s*<|GetIt\.(?:I|instance)\b)',
);
final RegExp _isRegistered = RegExp(r'(?<![A-Za-z0-9_$])getIt\.isRegistered\b');

/// Whole-line `//` comments, doc comments included: prose that mentions
/// `getIt<Foo>()` is not a lookup.
final RegExp _lineComment = RegExp(r'^\s*//.*$', multiLine: true);

/// The files that build a service generation, and so are allowed to read and
/// register through GetIt.
const compositionRoot = <String>{
  'lib/app_bootstrap.dart',
  'lib/get_it.dart',
  'lib/get_it_helpers.dart',
  'lib/get_it_sync.dart',
  'lib/main.dart',
};

/// Generated sources restate the hand-written ones and would make the
/// baseline drift on every `build_runner` run.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart');

/// What one file still owes.
typedef GetItDebt = ({int lookups, int isRegistered});

/// A file that grew, phrased as something the reader can act on.
class GetItViolation {
  const GetItViolation(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The result of a scan: each file's debt, and the files that grew.
class GuardResult {
  const GuardResult(this.debt, this.violations);

  final Map<String, GetItDebt> debt;
  final List<GetItViolation> violations;

  int get totalLookups => debt.values.fold(0, (a, d) => a + d.lookups);
  int get totalIsRegistered =>
      debt.values.fold(0, (a, d) => a + d.isRegistered);
}

/// Counts GetIt use in every Dart file under [root] outside the composition
/// root, and compares each file against [baseline] (repo-relative path to its
/// last known debt).
GuardResult scan({
  required Directory root,
  required Map<String, GetItDebt> baseline,
  required String repoRoot,
}) {
  final debt = <String, GetItDebt>{};
  final violations = <GetItViolation>[];

  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final rel = _relative(file.path, repoRoot);
    if (isGenerated(rel) || compositionRoot.contains(rel)) continue;

    final source = file.readAsStringSync().replaceAll(_lineComment, '');
    final found = (
      lookups: _lookup.allMatches(source).length,
      isRegistered: _isRegistered.allMatches(source).length,
    );
    if (found.lookups == 0 && found.isRegistered == 0) continue;
    debt[rel] = found;

    final allowed = baseline[rel] ?? (lookups: 0, isRegistered: 0);
    if (found.lookups > allowed.lookups) {
      violations.add(
        GetItViolation(
          rel,
          allowed.lookups == 0
              ? 'introduces ${found.lookups} `getIt` lookup'
                    '${found.lookups == 1 ? '' : 's'}. Watch a provider from '
                    '`lib/providers/service_providers.dart` in widgets and '
                    'controllers, or take the service as a constructor '
                    'argument in a plain class.'
              : '`getIt` lookups grew from ${allowed.lookups} to '
                    '${found.lookups}. This file is mid-migration; it may '
                    'shrink, not grow.',
        ),
      );
    }
    if (found.isRegistered > allowed.isRegistered) {
      violations.add(
        GetItViolation(
          rel,
          '`getIt.isRegistered` checks grew from ${allowed.isRegistered} to '
          '${found.isRegistered}. A service a test does not wire is a '
          'provider the test should override, not a branch in production '
          'code.',
        ),
      );
    }
  }

  return GuardResult(debt, violations);
}

String _relative(String path, String repoRoot) {
  final normalizedRoot = repoRoot.endsWith('/') ? repoRoot : '$repoRoot/';
  return path.startsWith(normalizedRoot)
      ? path.substring(normalizedRoot.length)
      : path;
}

/// Reads a baseline file, treating a missing one as "no debt is tolerated".
Map<String, GetItDebt> readBaseline(File file) {
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) return const {};
  final files = decoded['files'];
  if (files is! Map) return const {};
  int count(Object? entry, String key) =>
      entry is Map ? (entry[key] as num? ?? 0).toInt() : 0;
  return {
    for (final MapEntry(:key, :value) in files.entries)
      key as String: (
        lookups: count(value, 'lookups'),
        isRegistered: count(value, 'isRegistered'),
      ),
  };
}

/// Serialises a baseline deterministically, so a re-run produces no diff.
/// Zero counts are left out to keep the file readable.
String encodeBaseline(Map<String, GetItDebt> debt) {
  final keys = debt.keys.toList()..sort();
  final lookups = debt.values.fold(0, (a, d) => a + d.lookups);
  final isRegistered = debt.values.fold(0, (a, d) => a + d.isRegistered);
  final buffer = StringBuffer()
    ..writeln('{')
    ..writeln(
      '  "_comment": "getIt lookups and isRegistered checks outside the '
      'composition root, still to be migrated to providers or constructor '
      'arguments. Regenerate with: dart run tool/di/validate.dart '
      '--update-baseline. These numbers only ever go down.",',
    )
    ..writeln(
      '  "_total": {"lookups": $lookups, "isRegistered": $isRegistered},',
    )
    ..writeln('  "files": {');
  for (var i = 0; i < keys.length; i++) {
    final d = debt[keys[i]]!;
    final fields = [
      if (d.lookups > 0) '"lookups": ${d.lookups}',
      if (d.isRegistered > 0) '"isRegistered": ${d.isRegistered}',
    ].join(', ');
    final comma = i == keys.length - 1 ? '' : ',';
    buffer.writeln('    ${jsonEncode(keys[i])}: {$fields}$comma');
  }
  buffer
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}
