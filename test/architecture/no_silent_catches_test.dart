import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 1-based lines in [source] where a silent catch starts: a catch clause
/// whose parameters are all underscores and whose block holds neither a
/// statement nor a comment.
///
/// It works on the parsed source, so a `catch (_) {}` quoted in a string or
/// a doc comment never counts.
List<int> silentCatchLines(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final visitor = _SilentCatchVisitor();
  result.unit.accept(visitor);
  return [
    for (final offset in visitor.offsets)
      result.lineInfo.getLocation(offset).lineNumber,
  ];
}

class _SilentCatchVisitor extends RecursiveAstVisitor<void> {
  final offsets = <int>[];

  static bool _discarded(CatchClauseParameter? parameter) =>
      parameter == null || RegExp(r'^_+$').hasMatch(parameter.name.lexeme);

  @override
  void visitCatchClause(CatchClause node) {
    final body = node.body;
    if (node.exceptionParameter != null &&
        _discarded(node.exceptionParameter) &&
        _discarded(node.stackTraceParameter) &&
        body.statements.isEmpty &&
        body.rightBracket.precedingComments == null) {
      offsets.add(node.offset);
    }
    super.visitCatchClause(node);
  }
}

/// Every swallowed exception in `lib/` says why.
///
/// `empty_catches` exempts handlers whose parameters are all underscores, so
/// such a swallow costs nothing to write and nothing to review: a failure
/// hidden that way surfaces later, far from its cause. An empty catch must
/// carry a comment naming the reason (teardown, best-effort telemetry, a
/// fallback that follows), or log what it caught.
void main() {
  test('the matcher finds every underscore-only empty handler', () {
    expect(
      silentCatchLines('''
void f() {
  try {} catch (_) {}
  try {} catch (_, _) {}
  try {} on StateError catch (_) {}
  try {} catch (_) {
  }
  try {} catch (_) {
    // A reason.
  }
  try {} catch (error) {
    log(error);
  }
  try {} on StateError {}
}
// try {} catch (_) {}
const quoted = 'try {} catch (_) {}';
'''),
      [2, 3, 4, 5],
    );
  });

  test('no underscore-only empty catch in lib/ without a reason', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('.g.dart') ||
          file.path.endsWith('.freezed.dart')) {
        continue;
      }
      for (final line in silentCatchLines(file.readAsStringSync())) {
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Give each swallowed exception a reason comment inside the block, '
          'or log it.',
    );
  });
}
