import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/language_dropdown.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcribe_button.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class SpeechModalListTile extends ConsumerWidget {
  const SpeechModalListTile({
    required this.entryId,
    required this.pageIndexNotifier,
    super.key,
  });

  final String entryId;
  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item is! JournalAudio) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.transcribe_rounded),
      title: Text(context.messages.speechModalTitle),
      onTap: () => pageIndexNotifier.value = 2,
    );
  }
}

class SpeechModalContent extends StatelessWidget {
  const SpeechModalContent({
    required this.entryId,
    required this.navigateToProgressModal,
    super.key,
  });

  final String entryId;
  final void Function() navigateToProgressModal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TranscribeButton(
          entryId: entryId,
          navigateToProgressModal: navigateToProgressModal,
        ),
        LanguageDropdown(entryId: entryId),
        TranscriptsList(entryId: entryId),
      ],
    );
  }
}
