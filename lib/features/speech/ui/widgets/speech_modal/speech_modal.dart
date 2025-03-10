import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/language_dropdown.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcribe_button.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/modals.dart';

class SpeechModalListTile extends ConsumerWidget {
  const SpeechModalListTile({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item is! JournalAudio) {
      return const SizedBox.shrink();
    }

    void onTapAdd() => ModalUtils.showSinglePageModal<void>(
          context: context,
          title: context.messages.speechModalTitle,
          builder: (_) => Column(
            children: [
              const SizedBox(height: 20),
              TranscribeButton(entryId: entryId),
              LanguageDropdown(entryId: entryId),
              TranscriptsList(entryId: entryId),
            ],
          ),
        );

    return ListTile(
      leading: const Icon(Icons.transcribe_rounded),
      title: Text(context.messages.speechModalTitle),
      onTap: onTapAdd,
    );
  }
}
