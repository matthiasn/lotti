import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    final autoLabel = context.messages.speechModalLanguageAuto;

    return DesignSystemDropdown(
      label: context.messages.speechModalSelectLanguage,
      inputLabel: _labelForLanguage(currentLanguage, autoLabel: autoLabel),
      items: [
        for (final lang in _languages)
          DesignSystemDropdownItem(
            id: lang.id,
            label: lang.id.isEmpty ? autoLabel : lang.label,
            selected: currentLanguage == lang.id,
          ),
      ],
      onItemPressed: (item) {
        notifier.setLanguage(item.id);
      },
    );
  }

  static const List<({String id, String label})> _languages = [
    (id: '', label: 'auto'),
    (id: 'en', label: 'English'),
    (id: 'de', label: 'Deutsch'),
  ];

  static String _labelForLanguage(
    String language, {
    required String autoLabel,
  }) {
    for (final lang in _languages) {
      if (lang.id == language) {
        return lang.id.isEmpty ? autoLabel : lang.label;
      }
    }
    return autoLabel;
  }
}
