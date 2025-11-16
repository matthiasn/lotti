import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/flags/language_flag.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class TaskLanguageWidget extends StatelessWidget {
  const TaskLanguageWidget({
    required this.task,
    required this.onLanguageChanged,
    this.hideLabelWhenValueSet = false,
    this.showLabel = true,
    super.key,
  });

  final Task task;
  final LanguageCallback onLanguageChanged;
  final bool hideLabelWhenValueSet;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final languageCode = task.data.languageCode;
    final language =
        languageCode != null ? SupportedLanguage.fromCode(languageCode) : null;
    final labelVisible =
        showLabel && (!hideLabelWhenValueSet || language == null);

    return InkWell(
      onTap: () => _showLanguageSelector(context),
      child: Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labelVisible) ...[
              Text(
                context.messages.taskLanguageLabel,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.statusIndicatorPaddingHorizontal,
                vertical: AppTheme.statusIndicatorPaddingVertical,
              ),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(
                  alpha: AppTheme.alphaPrimaryContainerDark,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.statusIndicatorBorderRadius,
                ),
                border: Border.all(
                  color: context.colorScheme.primary.withValues(
                    alpha: AppTheme.alphaStatusIndicatorBorder,
                  ),
                  width: AppTheme.statusIndicatorBorderWidth,
                ),
              ),
              child: language != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppTheme.statusIndicatorBorderRadius / 2,
                      ),
                      child: buildLanguageFlag(
                        languageCode: language.code,
                        height: 20,
                        width: 30,
                        key: ValueKey('flag-${language.code}'),
                      ),
                    )
                  : Icon(
                      Icons.language,
                      size: 16,
                      color: context.colorScheme.primary.withValues(
                        alpha: AppTheme.alphaPrimaryIcon,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguageSelector(BuildContext context) async {
    final searchQuery = ValueNotifier<String>('');
    final searchController = TextEditingController();

    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        titleWidget: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: LanguageSelectionModalContent.buildHeader(
            context: context,
            controller: searchController,
            queryNotifier: searchQuery,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        builder: (BuildContext context) {
          return LanguageSelectionModalContent(
            initialLanguageCode: task.data.languageCode,
            searchQuery: searchQuery,
            onLanguageSelected: (language) {
              onLanguageChanged(language);
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
            },
          );
        },
      );
    } finally {
      searchController.dispose();
      searchQuery.dispose();
    }
  }
}
