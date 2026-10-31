import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 1-based lines in [source] that present a Wolt sheet directly — a
/// `WoltModalSheet.show…` call — rather than through
/// `ModalUtils.showWoltModal`.
///
/// It works on the parsed source, so a call quoted in a comment or a string
/// never counts.
List<int> directWoltShowLines(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final visitor = _DirectWoltShowVisitor();
  result.unit.accept(visitor);
  return [
    for (final offset in visitor.offsets)
      result.lineInfo.getLocation(offset).lineNumber,
  ];
}

class _DirectWoltShowVisitor extends RecursiveAstVisitor<void> {
  final offsets = <int>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is SimpleIdentifier &&
        target.name == 'WoltModalSheet' &&
        node.methodName.name.startsWith('show')) {
      offsets.add(node.offset);
    }
    super.visitMethodInvocation(node);
  }
}

/// Every Wolt sheet in `lib/` opens through `ModalUtils.showWoltModal`.
///
/// That entry point is what puts a `ModalEscapeScope` around the page
/// content. Wolt lays the page inside two scaffolds whose disabled
/// drawer-dismiss handler swallows Escape whenever a field in the sheet has
/// focus; a sheet opened straight through `WoltModalSheet.show` closes on a
/// barrier tap but ignores Escape — the inconsistency this rule exists to
/// stop coming back.
void main() {
  const entryPoint = 'lib/widgets/modal/modal_utils.dart';

  test('the matcher finds direct calls and ignores quoted ones', () {
    expect(
      directWoltShowLines('''
void f(BuildContext c) {
  WoltModalSheet.show<void>(context: c, pageListBuilder: (_) => []);
  WoltModalSheet.showWithDynamicPath<void>(context: c);
  // WoltModalSheet.show<void>(...)
  final s = 'WoltModalSheet.show';
  ModalUtils.showWoltModal<void>(context: c, pageListBuilder: (_) => []);
  WoltModalSheet.of(c).popPage();
}
'''),
      [2, 3],
    );
  });

  test('only ModalUtils.showWoltModal presents a Wolt sheet', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      if (path == entryPoint || path.endsWith('.g.dart')) continue;
      for (final line in directWoltShowLines(file.readAsStringSync())) {
        offenders.add('$path:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Open Wolt sheets through ModalUtils.showWoltModal (or a helper '
          'built on it) so Escape closes them like a barrier tap does.',
    );
  });

  test('the entry point itself still calls Wolt, exactly once', () {
    expect(
      directWoltShowLines(File(entryPoint).readAsStringSync()),
      hasLength(1),
    );
  });
}
