import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/flags/language_flag.dart';

/// Invoked when a language is chosen in the picker; `null` signals clearing
/// the current selection.
typedef LanguageCallback = void Function(SupportedLanguage?);

/// Modal body for picking a task language. Filters [SupportedLanguage] values
/// by the live `searchQuery` (matching name, code, or localized name) and lists
/// them sorted by localized name. Pins the currently selected language as a
/// highlighted card at the top and appends a "clear" row when one is selected.
class LanguageSelectionModalContent extends ConsumerWidget {
  const LanguageSelectionModalContent({
    required this.onLanguageSelected,
    required this.searchQuery,
    this.initialLanguageCode,
    super.key,
  });

  final LanguageCallback onLanguageSelected;
  final ValueListenable<String> searchQuery;
  final String? initialLanguageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const languages = SupportedLanguage.values;

    return ValueListenableBuilder<String>(
      valueListenable: searchQuery,
      builder: (context, query, _) {
        final lowerQuery = query.toLowerCase();

        final filteredLanguages =
            languages
                .where(
                  (language) =>
                      language.name.toLowerCase().contains(lowerQuery) ||
                      language.code.toLowerCase().contains(lowerQuery) ||
                      language
                          .localizedName(context)
                          .toLowerCase()
                          .contains(lowerQuery),
                )
                .toList()
              ..sort(
                (a, b) => a
                    .localizedName(context)
                    .toLowerCase()
                    .compareTo(b.localizedName(context).toLowerCase()),
              );

        final selectedLanguage = initialLanguageCode != null
            ? SupportedLanguage.fromCode(initialLanguageCode!)
            : null;

        final languagesWithoutSelected = filteredLanguages
            .where((language) => language.code != initialLanguageCode)
            .toList();

        final colorScheme = context.colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedLanguage != null)
              SettingsCard(
                onTap: () => Navigator.pop(context),
                title: selectedLanguage.localizedName(context),
                subtitle: Text(
                  context.messages.taskLanguageSelectedLabel,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                leading: SizedBox(
                  width: 32,
                  height: 24,
                  child: buildLanguageFlag(
                    languageCode: selectedLanguage.code,
                    height: 24,
                    width: 32,
                    key: ValueKey('flag-${selectedLanguage.code}'),
                  ),
                ),
                trailing: Icon(
                  Icons.check_rounded,
                  color: colorScheme.primary,
                ),
              ),
            if (selectedLanguage != null) const SizedBox(height: 8),
            ...languagesWithoutSelected.map(
              (language) => SettingsCard(
                onTap: () => onLanguageSelected(language),
                title: language.localizedName(context),
                leading: SizedBox(
                  width: 32,
                  height: 24,
                  child: buildLanguageFlag(
                    languageCode: language.code,
                    height: 24,
                    width: 32,
                    key: ValueKey('flag-${language.code}'),
                  ),
                ),
              ),
            ),
            if (initialLanguageCode != null)
              SettingsCard(
                onTap: () => onLanguageSelected(null),
                title: context.messages.aiSettingsClearFiltersButton,
                titleColor: context.colorScheme.outline,
                leading: Icon(
                  Icons.clear,
                  color: context.colorScheme.outline,
                ),
              ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  /// Builds the modal's sticky search header — a `DesignSystemSearch` that pushes
  /// its text into `queryNotifier`, which the body listens to for filtering.
  static Widget buildHeader({
    required BuildContext context,
    required TextEditingController controller,
    required ValueNotifier<String> queryNotifier,
  }) {
    return DesignSystemSearch(
      controller: controller,
      hintText: '',
      onChanged: (value) => queryNotifier.value = value,
      onClear: () => queryNotifier.value = '',
    );
  }
}
