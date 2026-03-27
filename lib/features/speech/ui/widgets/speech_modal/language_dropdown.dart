import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Language codes supported by the speech dropdown.
/// The empty string represents automatic language detection.
const _languageCodes = ['', 'en', 'de'];

class LanguageDropdown extends ConsumerWidget {
  const LanguageDropdown({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;
    final item = entryState?.entry;

    if (item == null || item is! JournalAudio) {
      return const SizedBox.shrink();
    }

    final currentLanguage = item.data.language ?? '';
    final messages = context.messages;

    return DesignSystemDropdown(
      label: messages.speechModalSelectLanguage,
      inputLabel: _labelForLanguage(currentLanguage, messages),
      items: [
        for (final code in _languageCodes)
          DesignSystemDropdownItem(
            id: code,
            label: _labelForLanguage(code, messages),
            selected: currentLanguage == code,
          ),
      ],
      onItemPressed: (item) {
        notifier.setLanguage(item.id);
      },
    );
  }
}

String _labelForLanguage(String language, AppLocalizations messages) =>
    switch (language) {
      '' => messages.speechModalLanguageAuto,
      'en' => messages.taskLanguageEnglish,
      'de' => messages.taskLanguageGerman,
      _ => language,
    };
