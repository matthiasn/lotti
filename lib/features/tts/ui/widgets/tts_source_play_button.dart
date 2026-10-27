import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';
import 'package:material_ui/material_ui.dart';

/// A [TtsPlayButton] bound to the app-wide [TtsPlaybackController] for one
/// [sourceId]: it shows preparing or playing, with progress, only while that
/// source holds the utterance, so controls for other content never animate
/// for it. A tap while idle calls [onPlay]; any other tap stops.
///
/// It watches the playback itself, so the progress ring repaints this button
/// rather than whatever hosts it.
class TtsSourcePlayButton extends ConsumerWidget {
  const TtsSourcePlayButton({
    required this.sourceId,
    required this.onPlay,
    super.key,
  });

  final String sourceId;

  /// Starts the utterance, typically `controller.speak(sourceId: …)`.
  final void Function(TtsPlaybackController controller) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(ttsPlaybackControllerProvider);
    final active = playback.isActiveFor(sourceId);
    final mode = !active
        ? TtsButtonMode.idle
        : switch (playback.status) {
            TtsPlaybackStatus.downloadingModel ||
            TtsPlaybackStatus.synthesizing => TtsButtonMode.preparing,
            TtsPlaybackStatus.playing => TtsButtonMode.playing,
            _ => TtsButtonMode.idle,
          };
    final durationMs = playback.duration.inMilliseconds;
    final progress = (mode == TtsButtonMode.playing && durationMs > 0)
        ? playback.position.inMilliseconds / durationMs
        : null;
    final controller = ref.read(ttsPlaybackControllerProvider.notifier);
    return TtsPlayButton(
      mode: mode,
      progress: progress,
      onPlay: () => onPlay(controller),
      onStop: controller.stop,
    );
  }
}
