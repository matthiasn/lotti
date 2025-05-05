import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';
import 'package:lotti/features/ai/ui/settings/prompt_edit_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class PromptSettingsPage extends StatelessWidget {
  const PromptSettingsPage({super.key});

  static const String routeName = '/settings/ai/prompts';

  @override
  Widget build(BuildContext context) {
    return AiConfigListPage(
      configType: AiConfigType.prompt,
      title: context.messages.promptSettingsPageTitle,
      onAddPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => const PromptEditPage(),
          ),
        );
      },
      onItemTap: (config) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => PromptEditPage(
              configId: config.id,
            ),
          ),
        );
      },
    );
  }
}
