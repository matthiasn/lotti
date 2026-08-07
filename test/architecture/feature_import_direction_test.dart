import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _packagePrefix = 'package:lotti/';

/// The `lib/`-relative path [uri] resolves to, or `null` if it is not an edge
/// inside `lib/` at all.
///
/// Both spellings of the same dependency are resolved. `package:lotti/x.dart` is
/// the form CI enforces, but a relative `../daily_os_next/x.dart` compiles to
/// exactly the same edge — `always_use_package_imports` is what normally
/// prevents it, and this guard must not be the thing that quietly stops working
/// if that lint is ever relaxed. Same reasoning as accepting double quotes.
String? _libRelativeTarget(String uri, {required String importingFile}) {
  if (uri.startsWith(_packagePrefix)) {
    return uri.substring(_packagePrefix.length);
  }
  // `dart:`, and `package:` for any other package: never a lotti-internal edge.
  final parsed = Uri.tryParse(uri);
  if (parsed == null || parsed.hasScheme) return null;

  final resolved = p.normalize(p.join(p.dirname(importingFile), uri));
  final fromLib = p.relative(resolved, from: 'lib');
  // Left `lib/` entirely — a test helper or a tool script, not a lib edge.
  if (fromLib.startsWith('..')) return null;
  // Normalise separators so a Windows checkout compares like a POSIX one.
  return p.split(fromLib).join('/');
}

/// Every `lib/`-internal URI that [source] imports or exports, as the path
/// relative to `lib/`. [path] is the importing file, which relative directives
/// resolve against.
///
/// Parses the source rather than matching directives with a pattern. The legal
/// shapes of a directive are open-ended — split across lines, double-quoted,
/// raw, adjacent string literals, a comment sitting between the keyword and the
/// URI, a second URI behind an `if (...)` configuration — and each one a pattern
/// fails to recognise is a forbidden dependency the guard waves through while
/// still reporting green. The parser knows every form by construction, which is
/// the only way this guard stays honest as the language grows.
List<String> _lottiUris(String source, {required String path}) {
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  if (result.errors.isNotEmpty) {
    fail(
      '$path does not parse, so nothing in it was scanned. A guard that '
      'silently skips a file enforces nothing.\n'
      '${result.errors.join('\n')}',
    );
  }

  final paths = <String>[];
  for (final directive
      in result.unit.directives.whereType<NamespaceDirective>()) {
    // The directive's own URI, plus every conditional-import alternative. Each
    // `if (dart.library.io) '...'` branch is a real edge, and it is the branch
    // rather than the default URI that gets compiled on the matching platform.
    for (final uri in [
      directive.uri,
      ...directive.configurations.map((c) => c.uri),
    ]) {
      // Null only for an interpolated literal, which is not a legal URI.
      final value = uri.stringValue;
      if (value == null) continue;
      final target = _libRelativeTarget(value, importingFile: path);
      if (target != null) paths.add(target);
    }
  }
  return paths;
}

/// Every `lib/`-internal import or export in [file], as the path relative to
/// `lib/`.
List<String> _lottiImports(File file) =>
    _lottiUris(file.readAsStringSync(), path: file.path);

/// Dart sources under `lib/<relative>`, generated files excluded.
///
/// Generated output is excluded because it is a build product: a part file
/// inherits its parent library's imports, so it cannot introduce an edge the
/// hand-written source does not already declare.
List<File> _sourcesUnder(String relative) {
  final dir = Directory('lib/$relative');
  if (!dir.existsSync()) {
    fail(
      'lib/$relative does not exist — this guard is pinned to a path that '
      'moved. Update the guard rather than deleting it.',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart'),
      )
      .toList();
}

/// Files under `lib/$from` that import anything under `lib/$to`.
List<String> _offenders({required String from, required String to}) {
  final offenders = <String>[];
  for (final file in _sourcesUnder(from)) {
    final bad = _lottiImports(file).where((i) => i.startsWith('$to/'));
    if (bad.isNotEmpty) {
      offenders.add('${file.path}\n    -> ${bad.join('\n    -> ')}');
    }
  }
  return offenders;
}

void main() {
  group('feature import direction', () {
    // The invariant DD-1 restored. `features/agents` owns the shared agent
    // runtime; `features/daily_os_next` owns one agent kind that plugs into it.
    // The dependency must point inward only, or the two features cannot be
    // built, tested, or removed independently.
    test('features/agents does not import features/daily_os_next', () {
      final offenders = _offenders(
        from: 'features/agents',
        to: 'features/daily_os_next',
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'features/agents must not depend on features/daily_os_next.\n'
            'Contribute the behaviour through a registry in '
            'agent_runtime_registry.dart (wake runners, runtime maintenance, '
            'setup-sheet launcher) or prompt_log_wrap.dart (payload formats) '
            'and override it in buildProviderOverrides, or move the shared '
            'vocabulary into lib/classes/.\n'
            'Offending files:\n${offenders.join('\n')}',
      );
    });

    // The direct edge above is only half the invariant. The refactor moved the
    // day vocabulary both features need into `lib/classes/`, which breaks the
    // cycle *only while that layer stays neutral*: if `lib/classes/` imported
    // `features/daily_os_next`, then `features/agents` would reach Daily OS
    // through the very types introduced to decouple them, and the guard above
    // would still report green.
    //
    // Deliberately a one-hop check on the mediating layer rather than a
    // transitive walk of the whole graph. Measured on this tree, a transitive
    // scan reports 38 paths, and they run through `services/nav_service.dart`
    // -> `beamer/` -> `app_root.dart` — the composition root, which reaches
    // every feature by construction in a Flutter app. A guard that fires on
    // that is one nobody can keep green, and it would be suppressed until it
    // meant nothing. `lib/classes/` is where the decoupling actually lives, so
    // it is where the second assertion belongs.
    //
    // `lib/classes/` does import `features/sync`, `features/ai`,
    // `features/ai_consumption` and `features/categories`, so this is
    // deliberately not a blanket "imports no feature" rule — only the two
    // features it mediates between are forbidden.
    test('lib/classes stays neutral between the two features', () {
      final offenders = [
        ..._offenders(from: 'classes', to: 'features/agents'),
        ..._offenders(from: 'classes', to: 'features/daily_os_next'),
      ];

      expect(
        offenders,
        isEmpty,
        reason:
            'lib/classes/ is the shared vocabulary that lets features/agents '
            'and features/daily_os_next stop depending on each other. It must '
            'depend on neither, or the cycle re-forms through it while the '
            'direct-edge guard still passes.\n'
            'Offending files:\n${offenders.join('\n')}',
      );
    });

    // Guards the guard. If the scanner silently matched nothing — wrong glob,
    // parser drift, renamed directory — the assertion above would pass while
    // enforcing nothing. The allowed direction is densely populated in
    // practice, so a healthy scanner always finds edges here.
    test('detects the allowed direction, proving the scanner works', () {
      final allowed = _offenders(
        from: 'features/daily_os_next',
        to: 'features/agents',
      );

      expect(
        allowed,
        isNotEmpty,
        reason:
            'features/daily_os_next is expected to import features/agents '
            '(the allowed direction). Finding none means this scanner has '
            'stopped detecting imports, so the guard above proves nothing.',
      );
    });

    test('reads every directive form, and nothing that only looks like one', () {
      // Each entry is a shape the guard has to get right. A false negative is
      // the dangerous direction: it makes the assertion above pass while
      // enforcing nothing, so the forbidden feature appears wherever a shape
      // could plausibly be used to smuggle the dependency back in.
      final uris = _lottiUris('''
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
export 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
  import 'package:lotti/classes/day_plan.dart';
import "package:lotti/classes/double_quoted.dart";
import
    'package:lotti/features/daily_os_next/agents/domain/split_across_lines.dart';
import /* between keyword and URI */ 'package:lotti/features/daily_os_next/agents/domain/inline_comment.dart';
import // a line comment ends the line, not the directive
    'package:lotti/features/daily_os_next/agents/domain/line_comment.dart';
import 'package:lotti/classes/conditional_default.dart'
    if (dart.library.io) 'package:lotti/features/daily_os_next/agents/domain/conditional_io.dart'
    if (dart.library.js_interop) 'package:lotti/features/daily_os_next/agents/domain/conditional_web.dart';
import r'package:lotti/classes/raw_string.dart';
import 'package:lotti/' 'classes/adjacent_strings.dart';
import 'package:lotti/classes/aliased.dart' as aliased;
import 'package:lotti/classes/shown.dart' show Thing;
import '../daily_os_next/agents/domain/relative_import.dart';
export '../../classes/relative_export.dart';
import 'sibling.dart';
import '../../../test/helpers/outside_lib.dart';
part 'package:lotti/classes/not_a_namespace_directive.dart';
// import 'package:lotti/features/agents/commented_out.dart';
final s = "import 'package:lotti/not/an/import.dart'";
''', path: 'lib/features/agents/fixture.dart');

      expect(uris, <String>[
        'features/agents/model/agent_constants.dart',
        'features/daily_os_next/agents/domain/day_agent_slots.dart',
        'classes/day_plan.dart',
        // `prefer_single_quotes` would reject a double-quoted directive in this
        // repo, but the guard must not depend on another lint holding.
        'classes/double_quoted.dart',
        // Split across lines — invisible to a per-line scan.
        'features/daily_os_next/agents/domain/split_across_lines.dart',
        // Dart permits comments between the keyword and the URI, in both forms.
        'features/daily_os_next/agents/domain/inline_comment.dart',
        'features/daily_os_next/agents/domain/line_comment.dart',
        // A conditional import contributes every branch, not just the default:
        // the `dart.library.io` branch is what actually compiles on mobile and
        // desktop, so scanning only the default URI would miss the real edge.
        'classes/conditional_default.dart',
        'features/daily_os_next/agents/domain/conditional_io.dart',
        'features/daily_os_next/agents/domain/conditional_web.dart',
        // Raw and adjacent string literals are both legal URI syntax.
        'classes/raw_string.dart',
        'classes/adjacent_strings.dart',
        'classes/aliased.dart',
        'classes/shown.dart',
        // Relative directives resolve to the same edge a package: URI names.
        // `always_use_package_imports` normally keeps these out of the repo,
        // but the guard resolves them rather than trusting that lint to hold.
        'features/daily_os_next/agents/domain/relative_import.dart',
        'classes/relative_export.dart',
        'features/agents/sibling.dart',
        // Absent from the list: the relative directive that climbs out of
        // `lib/` (`../../../test/helpers/outside_lib.dart`), which is not a lib
        // edge; `part`, which imports nothing of its own; the commented-out
        // directive; and the import-shaped string in an expression.
      ]);
    });
  });
}
