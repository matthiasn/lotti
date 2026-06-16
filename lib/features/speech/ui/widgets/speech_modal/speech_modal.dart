import 'package:flutter/material.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/language_dropdown.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list.dart';

/// Body of the per-audio-entry speech modal: stacks the transcription
/// [LanguageDropdown] over the [TranscriptsList] for the audio entry
/// identified by [entryId].
class SpeechModalContent extends StatelessWidget {
  const SpeechModalContent({
    required this.entryId,
    super.key,
  });

  /// Id of the `JournalAudio` entry whose language and transcripts are shown.
  final String entryId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LanguageDropdown(entryId: entryId),
        TranscriptsList(entryId: entryId),
      ],
    );
  }
}
