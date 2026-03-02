import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcript_container.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Shows streaming transcription progress with partial text,
/// styled for the evolution dark/cyan theme.
class EvolutionTranscriptionProgress extends StatelessWidget {
  const EvolutionTranscriptionProgress({
    required this.partialTranscript,
    super.key,
  });

  final String partialTranscript;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(
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
                  color: GameyColors.aiCyan,
                ),
              ),
              Icon(
                Icons.transcribe,
                size: 16,
                color: GameyColors.aiCyan,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
