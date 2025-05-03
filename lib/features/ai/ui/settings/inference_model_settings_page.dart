import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class InferenceModelSettingsPage extends ConsumerWidget {
  const InferenceModelSettingsPage({super.key});

  static const String routeName = '/settings/ai/models';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AiConfigListPage(
      configType: AiConfigType.model,
      title: context.messages.modelsSettingsPageTitle,
      onAddPressed: () => _navigateToEditPage(context, null),
      onItemTap: (config) => _navigateToEditPage(context, config),
    );
  }

  void _navigateToEditPage(BuildContext context, AiConfig? config) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => InferenceModelEditPage(
          configId: config?.id,
        ),
      ),
    );
  }
}
