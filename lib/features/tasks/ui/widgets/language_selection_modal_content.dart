import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/flags/language_flag.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';

typedef LanguageCallback = void Function(SupportedLanguage?);

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

        final filteredLanguages = languages
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
          ..sort((a, b) => a
              .localizedName(context)
              .toLowerCase()
              .compareTo(b.localizedName(context).toLowerCase()));

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

  static Widget buildHeader({
    required BuildContext context,
    required TextEditingController controller,
    required ValueNotifier<String> queryNotifier,
  }) {
    return LottiSearchBar(
      controller: controller,
      hintText: '',
      onChanged: (value) => queryNotifier.value = value,
      onClear: () => queryNotifier.value = '',
    );
  }
}
