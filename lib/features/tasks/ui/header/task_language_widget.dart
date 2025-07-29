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

    return InkWell(
      onTap: () => _showLanguageSelector(context),
      child: Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.messages.taskLanguageLabel,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            if (language != null)
              Container(
                width: 32,
                height: 24,
                decoration: BoxDecoration(
                  color: context.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: context.colorScheme.primary.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: CountryFlag.fromLanguageCode(
                    language.code,
                    height: 20,
                    width: 30,
                  ),
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: context.colorScheme.outline.withAlpha(51),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.language,
                  size: 16,
                  color: context.colorScheme.outline,
                ),
              ),
          ],
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
