part of 'input_area.dart';

class ChatVoiceControls extends ConsumerWidget {
  const ChatVoiceControls({
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: WaveformBars(
                  key: const ValueKey('waveform_bars'),
                  amplitudesNormalized: ref
                      .watch(chatRecorderControllerProvider.notifier)
                      .getNormalizedAmplitudeHistory(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              icon: const Icon(Icons.close),
              tooltip: context.messages.chatInputCancelRecording,
              onPressed: onCancel,
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.stop),
              tooltip: context.messages.chatInputStopTranscribe,
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows live transcript text during real-time recording (no waveform).
class _RealtimeRecordingView extends StatelessWidget {
  const _RealtimeRecordingView({
    required this.partialTranscript,
    required this.onCancel,
    required this.onStop,
  });

  final String? partialTranscript;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.85,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: hasText
                    ? SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          partialTranscript!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.messages.chatInputListening,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              icon: const Icon(Icons.close),
              tooltip: context.messages.chatInputCancelRealtime,
              onPressed: onCancel,
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.stop),
              tooltip: context.messages.chatInputStopRealtime,
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows streaming transcription progress with the partial text
class _TranscriptionProgress extends StatelessWidget {
  const _TranscriptionProgress({
    required this.partialTranscript,
  });

  final String partialTranscript;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.85,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: SingleChildScrollView(
              reverse: true, // Keep latest text visible
              child: Text(
                partialTranscript,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              Icon(
                Icons.transcribe,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
