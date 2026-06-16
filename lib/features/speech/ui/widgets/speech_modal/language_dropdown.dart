import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Dropdown for choosing the transcription language of an audio entry.
///
/// Watches the entry via `entryControllerProvider`, renders nothing for
/// non-audio entries, and offers `auto`/English/German. Selecting a value
/// persists it through the entry controller's `setLanguage`.
class LanguageDropdown extends ConsumerWidget {
  const LanguageDropdown({
    required this.entryId,
    super.key,
  });

  /// Id of the `JournalAudio` entry whose language is edited.
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.messages.speechModalSelectLanguage),
        const SizedBox(width: 10),
        DropdownButton(
          value: item.data.language,
          iconEnabledColor: context.colorScheme.outline,
          items: const [
            DropdownMenuItem(
              value: '',
              child: Text('auto'),
            ),
            DropdownMenuItem(
              value: 'en',
              child: Text('English'),
            ),
            DropdownMenuItem(
              value: 'de',
              child: Text('Deutsch'),
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              notifier.setLanguage(value);
            }
          },
        ),
      ],
    );
  }
}
