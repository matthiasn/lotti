import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/playhead_clock.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/state/tts_settings_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

/// The companion, speaking what the on-device voice speaks for [sourceId].
///
/// The host asks the voice to speak under [sourceId], as it would without
/// her. While that utterance plays, she reads its clip once to shape her mouth
/// ([loadSpokenTrack]) — the WAV and the words it was made from, both taken
/// from the playback state, so what the host shows now cannot put other words
/// in her mouth — and each frame her mouth follows the player's playhead.
/// Another source playing, or none, leaves her silent but alive. The voice
/// knows nothing about her.
///
/// Only the start and end of an utterance pass through Riverpod; the
/// per-frame playhead is read straight from the playback state, never
/// watched.
class CompanionSpeaker extends ConsumerStatefulWidget {
  const CompanionSpeaker({
    required this.sourceId,
    this.look = CompanionLook.grandma,
    this.mood = CompanionMood.calm,
    this.framing = CompanionFraming.full,
    this.stage = false,
    this.controller,
    this.holding,
    super.key,
  });

  /// The utterance she speaks: the `sourceId` the host passes to
  /// [TtsPlaybackController.speak].
  final String sourceId;

  final CompanionLook look;
  final CompanionMood mood;
  final CompanionFraming framing;

  /// Passed through to [CompanionView]: stands her on the dark stage.
  final bool stage;

  /// Passed through to [CompanionView]: cues a gesture now.
  final CompanionController? controller;

  /// Passed through to [CompanionView]: a gesture she keeps up.
  final GestureName? holding;

  @override
  ConsumerState<CompanionSpeaker> createState() => _CompanionSpeakerState();
}

class _CompanionSpeakerState extends ConsumerState<CompanionSpeaker> {
  PlayheadClock _clock = PlayheadClock();
  ProviderSubscription<TtsClip?>? _clip;
  MouthTrack? _track;

  // Bumped by every utterance start or end, so a slow load for an utterance
  // that is already over never lands.
  int _utterance = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(CompanionSpeaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceId != widget.sourceId) {
      _clip?.close();
      _listen();
    }
  }

  /// Follows the clip of [CompanionSpeaker.sourceId]'s utterance while it
  /// plays, null otherwise.
  void _listen() {
    final sourceId = widget.sourceId;
    _clip = ref.listenManual(
      ttsPlaybackControllerProvider.select(
        (s) => _isSpeaking(s, sourceId) ? s.clip : null,
      ),
      // Nothing waits for her mouth: the voice plays either way, and
      // [_speak] handles its own failure, so its future is dropped on purpose.
      (_, clip) => _speak(clip).ignore(),
      fireImmediately: true,
    );
  }

  static bool _isSpeaking(TtsPlaybackState state, String sourceId) =>
      state.status == TtsPlaybackStatus.playing && state.sourceId == sourceId;

  /// Takes up the mouth for [clip], or none when it is null. A load that
  /// fails is logged and leaves her silent, while the voice plays on.
  Future<void> _speak(TtsClip? clip) async {
    final utterance = ++_utterance;
    // Each utterance starts its own playhead: two clips can both open at
    // zero, and a clock that kept the first one's report would start the
    // second partway into its words.
    _clock = PlayheadClock();
    MouthTrack? track;
    if (clip != null) {
      final logger = ref.read(domainLoggerProvider);
      try {
        track = await ref.read(spokenTrackLoaderProvider)(
          clip.path,
          clip.text,
        );
      } catch (error, stackTrace) {
        logger.error(
          LogDomain.speech,
          error,
          stackTrace: stackTrace,
          subDomain: 'companionSpeaker',
          message: 'Could not shape her mouth for the clip',
        );
      }
    }
    if (!mounted || utterance != _utterance || identical(track, _track)) {
      return;
    }
    setState(() => _track = track);
  }

  Duration? _playhead() {
    final playback = ref.read(ttsPlaybackControllerProvider);
    if (!_isSpeaking(playback, widget.sourceId)) return null;
    final speed = ref.read(ttsSettingsControllerProvider).speed;
    return _clock.at(playback.position, speed: speed);
  }

  @override
  Widget build(BuildContext context) => CompanionView(
    look: widget.look,
    mood: widget.mood,
    framing: widget.framing,
    stage: widget.stage,
    controller: widget.controller,
    holding: widget.holding,
    track: _track,
    playhead: _playhead,
  );
}
