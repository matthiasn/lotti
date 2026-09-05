import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Returns source lines of property tests missing an explicit `glados` tag.
List<int> untaggedPropertyTests(String source) {
  final parsed = parseString(content: source);
  final visitor = _PropertyTestVisitor();
  parsed.unit.accept(visitor);
  return [
    for (final offset in visitor.offsets)
      parsed.lineInfo.getLocation(offset).lineNumber,
  ];
}

class _PropertyTestVisitor extends RecursiveAstVisitor<void> {
  final offsets = <int>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (const {'test', 'testWithRandom'}.contains(node.methodName.name)) {
      final constructor = _GladosConstructorVisitor();
      node.target?.accept(constructor);
      if (constructor.found) {
        final tags = node.argumentList.arguments
            .whereType<NamedExpression>()
            .where((argument) => argument.name.label.name == 'tags');
        final tagged = tags.any((argument) {
          final expression = argument.expression;
          return _isGlados(expression) ||
              (expression is ListLiteral && expression.elements.any(_isGlados));
        });
        if (!tagged) offsets.add(node.offset);
      }
    }
    super.visitMethodInvocation(node);
  }

  bool _isGlados(AstNode node) =>
      node is StringLiteral && node.stringValue == 'glados';
}

class _GladosConstructorVisitor extends RecursiveAstVisitor<void> {
  bool found = false;
  static final _name = RegExp(r'^Glados\d*$');

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_name.hasMatch(node.methodName.name)) found = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_name.hasMatch(node.constructorName.type.name.lexeme)) found = true;
    super.visitInstanceCreationExpression(node);
  }
}

void main() {
  final files =
      Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('_test.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  var violations = 0;
  for (final file in files) {
    for (final line in untaggedPropertyTests(file.readAsStringSync())) {
      stderr.writeln('${file.path}:$line: property test requires tags: glados');
      violations++;
    }
  }
  if (violations > 0) exitCode = 1;
}
