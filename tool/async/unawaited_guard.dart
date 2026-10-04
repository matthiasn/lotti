/// Ratchets fire-and-forget futures in `lib/` (`unawaited(...)`).
///
/// `unawaited` is the explicit way to start a future nobody awaits: its
/// errors go to the zone, not to a caller, and nothing waits for it to finish
/// before the next step runs. Some of that is right — telemetry, warm-ups —
/// but the count kept growing (575 to 582 between two assessments) with no
/// check, so each file's count may now shrink, never grow, and a file absent
/// from the baseline may not introduce one. A file whose count falls below
/// its entry fails too, until the baseline is tightened: the change that
/// awaits a future records it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

/// Generated sources restate the hand-written ones.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart');

/// Counts calls of `dart:async`'s `unawaited(...)` in [source]: an invocation
/// named `unawaited` with no target, or behind a `dart:async` import prefix
/// (`async.unawaited(...)`). A method of another object (`foo.unawaited()`,
/// or the cascade `foo..unawaited()`, whose target the analyzer leaves null)
/// and comments or strings never count. A `part` file has no imports of its
/// own — pass its library's source as [librarySource] and its prefixes apply.
int countUnawaited(String source, {String? librarySource}) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final importing = librarySource == null
      ? unit
      : parseString(content: librarySource, throwIfDiagnostics: false).unit;
  final prefixes = {
    for (final d in importing.directives.whereType<ImportDirective>())
      if (d.uri.stringValue == 'dart:async' && d.prefix != null) d.prefix!.name,
  };
  final visitor = _UnawaitedVisitor(prefixes);
  unit.accept(visitor);
  return visitor.count;
}

class _UnawaitedVisitor extends RecursiveAstVisitor<void> {
  _UnawaitedVisitor(this.prefixes);

  /// The names `dart:async` is imported under in this library.
  final Set<String> prefixes;
  int count = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (node.methodName.name == 'unawaited' &&
        ((target == null && !node.isCascaded) ||
            (target is SimpleIdentifier && prefixes.contains(target.name)))) {
      count++;
    }
    super.visitMethodInvocation(node);
  }
}

/// The source of the library [file] is a `part of`, or null if it is a
/// library itself (or its library cannot be read).
String? _librarySourceOf(File file, String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final partOf = unit.directives.whereType<PartOfDirective>().firstOrNull;
  final uri = partOf?.uri?.stringValue;
  if (uri == null) return null;
  final library = File(p.join(p.dirname(file.path), uri));
  return library.existsSync() ? library.readAsStringSync() : null;
}

/// A file whose count no longer matches its baseline entry.
class UnawaitedViolation {
  const UnawaitedViolation(this.path, this.message, {required this.grew});

  final String path;
  final String message;

  /// True when the file grew (or is new); false when it shrank and only the
  /// baseline needs tightening.
  final bool grew;

  @override
  String toString() => '$path: $message';
}

/// The result of a scan: each file's count, and the files out of step.
class GuardResult {
  const GuardResult(this.counts, this.violations);

  final Map<String, int> counts;
  final List<UnawaitedViolation> violations;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// Counts `unawaited(...)` in every Dart file under [root] and compares each
/// against [baseline], both ways.
GuardResult scan({
  required Directory root,
  required Map<String, int> baseline,
  required String repoRoot,
}) {
  final counts = <String, int>{};
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final rel = p.posix.joinAll(p.split(p.relative(file.path, from: repoRoot)));
    if (isGenerated(rel)) continue;
    final source = file.readAsStringSync();
    final found = countUnawaited(
      source,
      librarySource: _librarySourceOf(file, source),
    );
    if (found > 0) counts[rel] = found;
  }
  final violations = <UnawaitedViolation>[];
  for (final path in {...counts.keys, ...baseline.keys}.toList()..sort()) {
    final now = counts[path] ?? 0;
    final allowed = baseline[path] ?? 0;
    if (now > allowed) {
      violations.add(
        UnawaitedViolation(
          path,
          allowed == 0
              ? 'introduces $now unawaited future${now == 1 ? '' : 's'}. '
                    'Await it, or handle its errors and keep the reason next '
                    'to the call.'
              : 'unawaited futures grew from $allowed to $now; it may '
                    'shrink, not grow.',
          grew: true,
        ),
      );
    } else if (now < allowed) {
      violations.add(
        UnawaitedViolation(
          path,
          'shrank from $allowed to $now — tighten the baseline with '
          '--update-baseline.',
          grew: false,
        ),
      );
    }
  }
  return GuardResult(counts, violations);
}

/// Reads a baseline file, treating a missing one as "none tolerated".
Map<String, int> readBaseline(File file) {
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map || decoded['files'] is! Map) return const {};
  return {
    for (final MapEntry(:key, :value) in (decoded['files'] as Map).entries)
      key as String: (value as num).toInt(),
  };
}

/// Serialises a baseline deterministically.
String encodeBaseline(Map<String, int> counts) {
  final keys = counts.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('{')
    ..writeln(
      '  "_comment": "unawaited(...) calls in lib/. Each file must match its '
      'entry: it may shrink, never grow, and a shrink is recorded with dart '
      'run tool/async/validate.dart --update-baseline.",',
    )
    ..writeln('  "files": {');
  for (var i = 0; i < keys.length; i++) {
    final comma = i == keys.length - 1 ? '' : ',';
    buffer.writeln('    ${jsonEncode(keys[i])}: ${counts[keys[i]]}$comma');
  }
  buffer
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}
