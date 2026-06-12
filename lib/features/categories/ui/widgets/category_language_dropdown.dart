import 'package:flutter/material.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/flags/language_flag.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Default-language picker for the category editor, rendered as a
/// [SettingsPickerField] so it matches the design-system fields around
/// it. The widget shows the current selection (flag + localized name) or
/// a hint when none is set; the actual picking happens in whatever modal
/// [onTap] opens (the page wires it to `LanguageSelectionModalContent`).
/// It's independent of Riverpod for better testability.
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
    final code = languageCode;
    final language = code != null ? SupportedLanguage.fromCode(code) : null;

    return SettingsPickerField(
      // The hosting section header already says "Language" — repeating
      // it as a field label reads as a stutter.
      semanticsLabel: context.messages.taskLanguageLabel,
      valueText: language?.localizedName(context),
      hintText: context.messages.selectLanguage,
      leading: language != null
          ? buildLanguageFlag(
              languageCode: language.code,
              height: 24,
              width: 32,
            )
          : null,
      onTap: onTap,
    );
  }
}
