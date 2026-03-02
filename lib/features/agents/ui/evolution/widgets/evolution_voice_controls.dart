import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_cancel_stop_buttons.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Waveform bars with cancel/stop buttons during batch recording,
/// styled for the evolution dark/cyan theme.
class EvolutionVoiceControls extends ConsumerWidget {
  const EvolutionVoiceControls({
    required this.onCancel,
    required this.onStop,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            Expanded(
              child: WaveformBars(
                key: const ValueKey('evolution_waveform'),
                amplitudesNormalized: ref
                    .watch(chatRecorderControllerProvider.notifier)
                    .getNormalizedAmplitudeHistory(),
              ),
            ),
            EvolutionCancelStopButtons(
              onCancel: onCancel,
              onStop: onStop,
              cancelTooltip: context.messages.chatInputCancelRecording,
              stopTooltip: context.messages.chatInputStopTranscribe,
            ),
          ],
        ),
      ),
    );
  }
}
