import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A dropdown widget for selecting category default language.
///
/// This widget displays the current language selection and allows users to
/// select a new language. It's designed to be independent of Riverpod for better testability.
class CategoryLanguageDropdown extends StatelessWidget {
  const CategoryLanguageDropdown({
    required this.languageCode,
    required this.onTap,
    super.key,
  });

  final String? languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final language =
        languageCode != null ? SupportedLanguage.fromCode(languageCode!) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.messages.defaultLanguage,
          hintText: context.messages.selectLanguage,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          prefixIcon: const Icon(Icons.translate),
        ),
        child: Row(
          children: [
            if (language != null) ...[
              CountryFlag.fromLanguageCode(
                language.code,
                height: 20,
                width: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  language.localizedName(context),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ] else
              Expanded(
                child: Text(
                  context.messages.noDefaultLanguage,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
