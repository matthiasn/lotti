import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/tts_model_download_prompt.dart';
import 'package:lotti/features/tts/ui/widgets/tts_source_play_button.dart';
import 'package:material_ui/material_ui.dart';

/// The control that reads a summary aloud — with the host's [cloudRoute]
/// when its profile names a cloud voice, else the on-device voice — its mode
/// and progress derived from the app-wide [TtsPlaybackController].
///
/// [text] is whatever the summary currently shows (the TL;DR alone when
/// collapsed, the TL;DR and the full report when expanded). It reflects an
/// active state only while [sourceId] is the playing source, so several
/// controls for other tasks never animate for one utterance — and two for
/// the same task (the card's header and the companion's full-screen view)
/// show the same one.
class SummaryReadAloudButton extends StatelessWidget {
  const SummaryReadAloudButton({
    required this.sourceId,
    required this.text,
    this.cloudRoute,
    super.key,
  });

  final String sourceId;
  final String text;

  /// The cloud voice to speak with, or `null` for the on-device voice.
  final TtsCloudRoute? cloudRoute;

  @override
  Widget build(BuildContext context) {
    return TtsSourcePlayButton(
      sourceId: sourceId,
      onPlay: (controller) => controller.speak(
        sourceId: sourceId,
        text: text,
        cloudRoute: cloudRoute,
        confirmModelDownload: (model) =>
            confirmTtsModelDownload(context, model),
      ),
    );
  }
}
