/// Ratchets raw visual values in `lib/` down to the design-system tokens.
///
/// AGENTS.md makes spacing, typography and colour tokens mandatory, but
/// nothing enforced it, so hundreds of numeric `EdgeInsets`, `SizedBox`
/// gaps, `TextStyle`s and colour literals accumulated beside the tokens. The
/// token definitions (`lib/features/design_system/theme/`) are the one place
/// raw values belong; everywhere else each file's count per category may
/// shrink, never grow, and a file absent from the baseline may not introduce
/// any. It mirrors the icon ratchet (`tool/icons/`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

/// Where raw values are the point: the token definitions themselves.
const tokenSource = 'lib/features/design_system/theme/';

/// The categories counted, in baseline order.
enum TokenCategory { spacing, typography, color }

/// Generated sources restate the hand-written ones.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart');

/// Counts raw spacing, typography and colour values in [source]:
///
/// - **spacing**: `EdgeInsets.*` / `EdgeInsetsDirectional.*` calls with a
///   numeric literal argument, `SizedBox` with a numeric `width` or
///   `height`, and `SizedBox.square` with a numeric `dimension`;
/// - **typography**: `TextStyle(...)` constructions, and `fontSize:`
///   arguments outside one (a `copyWith(fontSize: …)`, say), so a
///   `TextStyle(fontSize: 12)` counts once;
/// - **color**: `Color(<literal>)`, `Color.fromARGB` / `fromRGBO` with
///   literals, and `Colors.<name>` other than the neutral `Colors.transparent`.
///
/// A constructor qualified by an import prefix (`ui.Color(…)`) counts like
/// the bare one. Counting runs on the parsed source, so comments and strings
/// never count.
Map<TokenCategory, int> countRawValues(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final visitor = _RawValueVisitor();
  unit.accept(visitor);
  return visitor.counts;
}

class _RawValueVisitor extends RecursiveAstVisitor<void> {
  final Map<TokenCategory, int> counts = {
    for (final c in TokenCategory.values) c: 0,
  };

  /// How many `TextStyle(...)` constructions enclose the current node.
  int _insideTextStyle = 0;

  void _hit(TokenCategory c) => counts[c] = counts[c]! + 1;

  /// The constructor types the guard counts. Without resolution, `a.B(…)`
  /// is either a prefixed constructor (`ui.Color(…)`) or a named one
  /// (`EdgeInsets.all(…)`); whichever side names one of these types decides,
  /// so an unidiomatic prefix such as `UI.Color` still counts.
  static const _countedTypes = {
    'Color',
    'EdgeInsets',
    'EdgeInsetsDirectional',
    'SizedBox',
    'TextStyle',
  };

  /// Whether `qualifier.name(…)` is a constructor of [name] behind the import
  /// prefix [qualifier], rather than the named constructor [name] of
  /// [qualifier].
  static bool _isPrefixedType(String qualifier, String name) =>
      _countedTypes.contains(name) && !_countedTypes.contains(qualifier);

  static bool _numeric(Expression e) {
    final unwrapped = e is NamedExpression ? e.expression : e;
    return unwrapped is IntegerLiteral ||
        unwrapped is DoubleLiteral ||
        (unwrapped is PrefixExpression &&
            (unwrapped.operand is IntegerLiteral ||
                unwrapped.operand is DoubleLiteral));
  }

  /// Handles a call named [type]`.`[member]`(`[args]`)` (member may be null),
  /// whether the parser saw it as a method call or a constructor.
  void _call(String type, String? member, ArgumentList args) {
    final arguments = args.arguments;
    switch (type) {
      case 'EdgeInsets' || 'EdgeInsetsDirectional' when member != null:
        if (arguments.any(_numeric)) _hit(TokenCategory.spacing);
      case 'SizedBox' when member == null:
        final sized = arguments.whereType<NamedExpression>().any(
          (a) =>
              (a.name.label.name == 'width' || a.name.label.name == 'height') &&
              _numeric(a.expression),
        );
        if (sized) _hit(TokenCategory.spacing);
      case 'SizedBox' when member == 'square':
        final sized = arguments.whereType<NamedExpression>().any(
          (a) => a.name.label.name == 'dimension' && _numeric(a.expression),
        );
        if (sized) _hit(TokenCategory.spacing);
      case 'TextStyle' when member == null:
        _hit(TokenCategory.typography);
      case 'Color' when member == null:
        if (arguments.length == 1 && _numeric(arguments.single)) {
          _hit(TokenCategory.color);
        }
      case 'Color' when member == 'fromARGB' || member == 'fromRGBO':
        if (arguments.every(_numeric)) _hit(TokenCategory.color);
    }
  }

  /// Visits [node]'s children, marking them as inside a `TextStyle(...)`
  /// when [type] is one.
  void _descend(
    String type,
    String? member,
    AstNode node,
    void Function() visit,
  ) {
    final isTextStyle = type == 'TextStyle' && member == null;
    if (isTextStyle) _insideTextStyle++;
    visit();
    if (isTextStyle) _insideTextStyle--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final method = node.methodName.name;
    final (type, member) = switch (target) {
      null => (method, null),
      // `ui.Color(…)`: a prefixed constructor, not a static call.
      SimpleIdentifier(:final name) when _isPrefixedType(name, method) => (
        method,
        null,
      ),
      SimpleIdentifier(:final name) => (name, method),
      // `ui.Color.fromARGB(…)`.
      PrefixedIdentifier(:final prefix, :final identifier)
          when _isPrefixedType(prefix.name, identifier.name) =>
        (identifier.name, method),
      _ => ('', null),
    };
    if (type.isNotEmpty) _call(type, member, node.argumentList);
    _descend(type, member, node, () => super.visitMethodInvocation(node));
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName;
    // Unresolved, `const EdgeInsets.all(8)` parses as type `all` under an
    // import prefix `EdgeInsets`, with no constructor name, just as
    // `const ui.Color(1)` parses as type `Color` under the prefix `ui`.
    final prefix = name.type.importPrefix?.name.lexeme;
    final (
      type,
      member,
    ) = name.name == null &&
            prefix != null &&
            !_isPrefixedType(prefix, name.type.name.lexeme)
        ? (prefix, name.type.name.lexeme)
        : (name.type.name.lexeme, name.name?.name);
    _call(type, member, node.argumentList);
    _descend(
      type,
      member,
      node,
      () => super.visitInstanceCreationExpression(node),
    );
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'fontSize' && _insideTextStyle == 0) {
      _hit(TokenCategory.typography);
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'Colors' && node.identifier.name != 'transparent') {
      _hit(TokenCategory.color);
    }
    super.visitPrefixedIdentifier(node);
  }
}

/// A file that grew in some category.
class TokenViolation {
  const TokenViolation(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The result of a scan: each file's counts, and the files that grew.
class GuardResult {
  const GuardResult(this.counts, this.violations);

  final Map<String, Map<TokenCategory, int>> counts;
  final List<TokenViolation> violations;

  int total(TokenCategory c) =>
      counts.values.fold(0, (sum, m) => sum + (m[c] ?? 0));
}

/// Counts raw visual values in every Dart file under [root] outside
/// [tokenSource], and compares each category against [baseline].
GuardResult scan({
  required Directory root,
  required Map<String, Map<TokenCategory, int>> baseline,
  required String repoRoot,
}) {
  final counts = <String, Map<TokenCategory, int>>{};
  final violations = <TokenViolation>[];
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
    if (isGenerated(rel) || rel.startsWith(tokenSource)) continue;
    final found = countRawValues(file.readAsStringSync());
    if (found.values.every((n) => n == 0)) continue;
    counts[rel] = found;
    final allowed = baseline[rel] ?? const {};
    for (final c in TokenCategory.values) {
      final now = found[c]!;
      final before = allowed[c] ?? 0;
      if (now > before) {
        violations.add(
          TokenViolation(
            rel,
            before == 0
                ? 'introduces $now raw ${c.name} value'
                      '${now == 1 ? '' : 's'}. Use the design-system tokens '
                      '(tokens.spacing, tokens.typography, tokens.colors).'
                : 'raw ${c.name} values grew from $before to $now. This file '
                      'is mid-migration; it may shrink, not grow.',
          ),
        );
      }
    }
  }
  return GuardResult(counts, violations);
}

/// Reads a baseline file, treating a missing one as "none tolerated".
Map<String, Map<TokenCategory, int>> readBaseline(File file) {
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) return const {};
  final files = decoded['files'];
  if (files is! Map) return const {};
  return {
    for (final MapEntry(:key, :value) in files.entries)
      key as String: {
        for (final c in TokenCategory.values)
          c: value is Map ? ((value[c.name] as num?) ?? 0).toInt() : 0,
      },
  };
}

/// Serialises a baseline deterministically, leaving out zero counts.
String encodeBaseline(Map<String, Map<TokenCategory, int>> counts) {
  final keys = counts.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('{')
    ..writeln(
      '  "_comment": "Raw spacing, typography and colour values outside the '
      'design-system token definitions. Regenerate with: dart run '
      'tool/design_tokens/validate.dart --update-baseline. These numbers '
      'only ever go down.",',
    )
    ..writeln('  "files": {');
  for (var i = 0; i < keys.length; i++) {
    final m = counts[keys[i]]!;
    final fields = {
      for (final c in TokenCategory.values)
        if ((m[c] ?? 0) > 0) c.name: m[c],
    };
    final comma = i == keys.length - 1 ? '' : ',';
    buffer.writeln('    ${jsonEncode(keys[i])}: ${jsonEncode(fields)}$comma');
  }
  buffer
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}
