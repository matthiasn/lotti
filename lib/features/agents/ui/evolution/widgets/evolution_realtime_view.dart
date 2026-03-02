import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_cancel_stop_buttons.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcript_container.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Live partial transcript view during realtime recording,
/// styled for the evolution dark/cyan theme.
class EvolutionRealtimeView extends StatelessWidget {
  const EvolutionRealtimeView({
    required this.partialTranscript,
    required this.onCancel,
    required this.onStop,
    super.key,
  });

  final String? partialTranscript;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final hasText = partialTranscript != null && partialTranscript!.isNotEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            Expanded(
              child: EvolutionTranscriptContainer(
                child: hasText
                    ? SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          partialTranscript!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: GameyColors.aiCyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.messages.chatInputListening,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            EvolutionCancelStopButtons(
              onCancel: onCancel,
              onStop: onStop,
              cancelTooltip: context.messages.chatInputCancelRealtime,
              stopTooltip: context.messages.chatInputStopRealtime,
            ),
          ],
        ),
      ),
    );
  }
}
