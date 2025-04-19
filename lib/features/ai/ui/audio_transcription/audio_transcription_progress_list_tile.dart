import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/audio_transcription.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class AudioTranscriptionProgressListTile extends ConsumerWidget {
  const AudioTranscriptionProgressListTile({
    required this.journalAudio,
    required this.onTap,
    this.linkedFromId,
    super.key,
  });

  final JournalAudio journalAudio;
  final String? linkedFromId;
  final void Function() onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.assistant),
      title: Text(
        context.messages.aiAssistantTranscribeAudio,
      ),
      onTap: () {
        final provider =
            audioTranscriptionControllerProvider(id: journalAudio.id);
        ref.invalidate(provider);
        ref.read(provider.notifier).transcribeAudio();
        onTap();
      },
    );
  }
}
