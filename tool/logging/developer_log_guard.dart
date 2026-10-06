/// Keeps `dart:developer` logging in `lib/` inside the logging layer.
///
/// `DomainLogger` is the app's logging channel: it writes domain-gated,
/// PII-reviewed telemetry to the log files, and its class doc sets the rule
/// that messages carry ids, counts and lengths, never titles, prompts or
/// model output. `developer.log` is a second, unreviewed channel beside it
/// that reaches only an attached debugger, so a failure logged there leaves
/// no trace a user or maintainer would find. The files that implement
/// logging (`lib/services/`) may use it; no other file may.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as p;

/// Directories whose files implement logging and may call `dart:developer`.
const loggingLayer = <String>{'lib/services/'};

/// Generated sources restate the hand-written ones.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart');

/// Counts references to `dart:developer`'s `log` in [source] — calls and
/// tear-offs alike, so `final emit = developer.log;` counts too.
///
/// The import decides the spelling: `import 'dart:developer' as dev;` makes it
/// `dev.log`, an unprefixed import makes it a bare `log` (not a named
/// argument's `log:` label). A `part` file has
/// no imports of its own — pass its library's source as [librarySource] and
/// its imports apply. Counting runs on the token stream, so comments and
/// strings never count. A file whose library does not import
/// `dart:developer` counts zero.
int countDeveloperLogs(String source, {String? librarySource}) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final importing = librarySource == null
      ? unit
      : parseString(content: librarySource, throwIfDiagnostics: false).unit;
  final imports = importing.directives.whereType<ImportDirective>().where(
    (d) => d.uri.stringValue == 'dart:developer',
  );
  if (imports.isEmpty) return 0;
  final prefixes = {
    for (final d in imports)
      if (d.prefix != null) d.prefix!.name,
  };
  final bare = imports.any((d) => d.prefix == null);

  var count = 0;
  for (Token? t = unit.beginToken; t != null && !t.isEof; t = t.next) {
    if (t.type != TokenType.IDENTIFIER) continue;
    final previous = t.previous;
    final afterDot =
        previous != null &&
        (previous.type == TokenType.PERIOD ||
            previous.type == TokenType.QUESTION_PERIOD);
    final next = t.next;
    if (prefixes.contains(t.lexeme) &&
        !afterDot &&
        next?.type == TokenType.PERIOD &&
        next?.next?.lexeme == 'log') {
      count++;
    } else if (bare &&
        t.lexeme == 'log' &&
        !afterDot &&
        next?.type != TokenType.COLON) {
      count++;
    }
  }
  return count;
}

/// A file that logs through `dart:developer`, phrased as something the reader
/// can act on.
class DeveloperLogViolation {
  const DeveloperLogViolation(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The result of a scan: each offending file's count, and a violation per
/// file.
class GuardResult {
  const GuardResult(this.counts, this.violations);

  final Map<String, int> counts;
  final List<DeveloperLogViolation> violations;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// Counts `dart:developer` logging in every Dart file under [root] outside
/// [loggingLayer]; every file with a call is a violation.
GuardResult scan({required Directory root, required String repoRoot}) {
  final counts = <String, int>{};
  final violations = <DeveloperLogViolation>[];
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final rel = p.posix.joinAll(
      p.split(p.relative(file.path, from: repoRoot)),
    );
    if (isGenerated(rel) || loggingLayer.any(rel.startsWith)) continue;
    final source = file.readAsStringSync();
    final found = countDeveloperLogs(
      source,
      librarySource: _librarySourceOf(file, source),
    );
    if (found == 0) continue;
    counts[rel] = found;
    violations.add(
      DeveloperLogViolation(
        rel,
        'has $found `dart:developer` log call${found == 1 ? '' : 's'}. Log '
        'through `DomainLogger` — `error` with the stack trace in a catch '
        'block, `log` otherwise (ids, counts and lengths, never content).',
      ),
    );
  }
  return GuardResult(counts, violations);
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
