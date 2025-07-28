import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class TaskLanguageWidget extends StatelessWidget {
  const TaskLanguageWidget({
    required this.task,
    required this.onLanguageChanged,
    super.key,
  });

  final Task task;
  final LanguageCallback onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final languageCode = task.data.languageCode;
    final language =
        languageCode != null ? SupportedLanguage.fromCode(languageCode) : null;

    if (language == null) {
      return InkWell(
        onTap: () => _showLanguageSelector(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.language,
            color: context.colorScheme.outline.withAlpha(128),
            size: 32,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showLanguageSelector(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 40,
          height: 30,
          child: CountryFlag.fromLanguageCode(
            language.code,
            height: 30,
            width: 40,
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageSelector(BuildContext context) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.taskLanguageLabel,
      builder: (BuildContext context) {
        return LanguageSelectionModalContent(
          initialLanguageCode: task.data.languageCode,
          onLanguageSelected: (language) {
            onLanguageChanged(language);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
