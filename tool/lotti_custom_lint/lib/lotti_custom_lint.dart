import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'package:lotti_custom_lint/src/no_get_it_in_sync_rule.dart';

PluginBase createPlugin() => _LottiLintPlugin();

class _LottiLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const NoGetItInSyncRule(),
      ];
}
