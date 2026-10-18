import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';
import 'package:material_ui/material_ui.dart';

/// The Supertonic control that reads a task's summary aloud, its mode and
/// progress derived from the app-wide [TtsPlaybackController].
///
/// [text] is whatever the summary currently shows (the TL;DR alone when
/// collapsed, the TL;DR and the full report when expanded). It reflects an
/// active state only while [sourceId] is the playing source, so several
/// controls for other tasks never animate for one utterance — and two for
/// the same task (the card's header and the companion's full-screen view)
/// show the same one.
///
/// It watches the playback itself, so the progress ring repaints this button
/// rather than the card around it, and a host on another route stays live.
class SummaryReadAloudButton extends ConsumerWidget {
  const SummaryReadAloudButton({
    required this.sourceId,
    required this.text,
    super.key,
  });

  final String sourceId;
  final String text;

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
    final notifier = ref.read(ttsPlaybackControllerProvider.notifier);
    return TtsPlayButton(
      mode: mode,
      progress: progress,
      onPlay: () => notifier.speak(sourceId: sourceId, text: text),
      onStop: notifier.stop,
    );
  }
}
