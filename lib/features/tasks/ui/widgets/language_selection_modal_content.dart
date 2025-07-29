import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

typedef LanguageCallback = void Function(SupportedLanguage?);

class LanguageSelectionModalContent extends ConsumerStatefulWidget {
  const LanguageSelectionModalContent({
    required this.onLanguageSelected,
    this.initialLanguageCode,
    super.key,
  });

  final LanguageCallback onLanguageSelected;
  final String? initialLanguageCode;

  @override
  ConsumerState<LanguageSelectionModalContent> createState() =>
      LanguageSelectionModalContentState();
}

class LanguageSelectionModalContentState
    extends ConsumerState<LanguageSelectionModalContent> {
  final searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const languages = SupportedLanguage.values;
    final filteredLanguages = languages
        .where(
          (language) =>
              language.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              language.code.toLowerCase().contains(searchQuery.toLowerCase()) ||
              language
                  .localizedName(context)
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()),
        )
        .toList();

    final selectedLanguage = widget.initialLanguageCode != null
        ? SupportedLanguage.fromCode(widget.initialLanguageCode!)
        : null;

    final languagesWithoutSelected = filteredLanguages
        .where((language) => language.code != widget.initialLanguageCode)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: context.messages.categorySearchPlaceholder,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedLanguage != null)
                        SettingsCard(
                          onTap: () => Navigator.pop(context),
                          title: selectedLanguage.localizedName(context),
                          leading: SizedBox(
                            width: 32,
                            height: 24,
                            child: CountryFlag.fromLanguageCode(
                              selectedLanguage.code,
                              height: 24,
                              width: 32,
                            ),
                          ),
                        ),
                      ...languagesWithoutSelected.map(
                        (language) => SettingsCard(
                          onTap: () => widget.onLanguageSelected(language),
                          title: language.localizedName(context),
                          leading: SizedBox(
                            width: 32,
                            height: 24,
                            child: CountryFlag.fromLanguageCode(
                              language.code,
                              height: 24,
                              width: 32,
                            ),
                          ),
                        ),
                      ),
                      if (widget.initialLanguageCode != null)
                        SettingsCard(
                          onTap: () => widget.onLanguageSelected(null),
                          title: context.messages.aiSettingsClearFiltersButton,
                          titleColor: context.colorScheme.outline,
                          leading: Icon(
                            Icons.clear,
                            color: context.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
