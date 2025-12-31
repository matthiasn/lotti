import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class NoGetItInSyncRule extends DartLintRule {
  const NoGetItInSyncRule()
      : super(
          code: const LintCode(
            name: 'no_get_it_in_sync',
            problemMessage:
                'Avoid using getIt in sync modules. Prefer provider-based or constructor injection.',
            correctionMessage:
                'Inject dependencies via matrixServiceProvider or other scoped providers.',
          ),
        );

  bool _isInSyncModule(String path) =>
      path.contains('lib/features/sync/') || path.contains('lib/widgets/sync/');

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isInSyncModule(resolver.path)) {
      return;
    }

    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      final element = node.element;
      if (element == null || element.displayName != 'getIt') {
        return;
      }

      reporter.atNode(node, code);
    });
  }
}
