import 'package:flutter/material.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/language_dropdown.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/transcripts_list.dart';

class SpeechModalContent extends StatelessWidget {
  const SpeechModalContent({
    required this.entryId,
    super.key,
  });

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
