import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcript_container.dart';

/// Shows streaming transcription progress with partial text.
class EvolutionTranscriptionProgress extends StatelessWidget {
  const EvolutionTranscriptionProgress({
    required this.partialTranscript,
    super.key,
  });

  final String partialTranscript;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: EvolutionTranscriptContainer(
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                partialTranscript,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              Icon(
                Icons.transcribe,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
