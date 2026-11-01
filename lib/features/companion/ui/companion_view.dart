import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/animation/companion_animator.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/tone_track.dart';
import 'package:lotti/features/companion/model/companion_flourish.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/rig/supersampled_painter.dart';

/// How close to the end of the words the voice must get for a read to
/// count as heard out: the last frames before a clip ends, which a playhead
/// that stops reporting may never show.
const _lastWordSlack = Duration(milliseconds: 250);

/// Reads where a voice's playhead is, or null while nothing plays.
typedef PlayheadReader = Duration? Function();

/// Lets the owner of a [CompanionView] cue her: a gesture now, a face now, a
/// blink now.
class CompanionController {
  CompanionAnimator? _animator;

  /// Whether a view is attached.
  bool get isAttached => _animator != null;

  /// Seconds the attached view has been animating, its own clock; 0 while
  /// detached. A silent line can be timed against it.
  double get time => _animator?.time ?? 0;

  /// The gesture the attached view is playing, or null while she stands at
  /// ready or no view is attached.
  GestureName? get gesture => _animator?.gesture;

  /// The face the attached view is pulling, or null once it has faded or
  /// no view is attached.
  CompanionFlourish? get flourishing => _animator?.flourishing;

  /// Plays [gesture] now; ignored while no view is attached.
  void play(GestureName gesture) => _animator?.play(gesture);

  /// Pulls [face] now, over whatever she is doing; ignored while no view is
  /// attached.
  void flourish(CompanionFlourish face) => _animator?.flourish(face);

  /// Blinks now.
  void blink() => _animator?.blink();
}

/// The companion, alive: she breathes, blinks, glances about and, while a
/// [track] plays, talks with her mouth on it — and, given its [tone], with
/// her face on what the words say.
///
/// Per-frame values never leave this widget's state: the [Ticker] advances a
/// [CompanionAnimator] and only the painted pose changes. What changes
/// rarely — the [look], the [mood], what she says — comes in as parameters.
class CompanionView extends StatefulWidget {
  const CompanionView({
    this.look = CompanionLook.grandma,
    this.mood = CompanionMood.calm,
    this.framing = CompanionFraming.full,
    this.stage = false,
    this.supersample,
    this.track,
    this.tone,
    this.sass = CompanionSass.warm,
    this.playhead,
    this.lookAt,
    this.autoGestures = true,
    this.controller,
    this.holding,
    this.seed = 11,
    super.key,
  });

  final CompanionLook look;
  final CompanionMood mood;
  final CompanionFraming framing;

  /// Stands her on the videos' dark stage instead of a clear background.
  final bool stage;

  /// Samples per pixel along each axis (1, 2, 4 or 8), so her edges stay
  /// smooth on a renderer that does not anti-alias paths; see
  /// [SupersampledPainter]. Null takes [platformSupersample].
  final int? supersample;

  /// The smoothing this platform needs: 4 samples per pixel on Linux, where
  /// Impeller on a GL driver without multisampling (a VM, a bare desktop)
  /// draws paths without anti-aliasing, and 1 — none — everywhere else,
  /// where the renderer anti-aliases and the extra passes would cost a large
  /// texture per frame for nothing.
  static int get platformSupersample =>
      defaultTargetPlatform == TargetPlatform.linux ? 4 : 1;

  /// What she says; she talks while [playhead] reads a position inside it.
  final MouthTrack? track;

  /// How [track]'s words land, on the same playhead. While she speaks a
  /// sentence that reads one way or the other, its [companionReaction] with
  /// [sass] takes over her face from [mood], and each change of tone cues
  /// that reaction's gesture once; between such sentences, and once she is
  /// quiet, she is in [mood] again.
  ///
  /// On top, each beat the voice reaches — a question, a "but", a
  /// "finally" — pulls its [companionBeat] face, and when the words are over
  /// she has the last word: [companionSignOff], held a moment after the
  /// voice stops.
  final ToneTrack? tone;

  /// How much sass her reactions to [tone] carry.
  final CompanionSass sass;
  final PlayheadReader? playhead;

  /// Fixes her eyes on a point (each axis about -1..1) instead of letting
  /// them wander.
  final Offset? lookAt;

  /// Lets her pick talking gestures on her own while she speaks.
  final bool autoGestures;
  final CompanionController? controller;

  /// A gesture she keeps up for as long as this is set — listening while
  /// someone records, thinking while something is worked out: played at
  /// once, and again whenever it relaxes. Null lets her stand at ready.
  final GestureName? holding;

  /// Seeds her blinks, glances and gesture picks.
  final int seed;

  @override
  State<CompanionView> createState() => _CompanionViewState();
}

class _CompanionViewState extends State<CompanionView>
    with SingleTickerProviderStateMixin {
  late CompanionAnimator _animator;
  late final Ticker _ticker;
  late CompanionPose _pose;
  Duration _last = Duration.zero;

  // The approval of the words she is saying now, so a change cues once.
  int? _approval;

  // The tone she is reading and the cue the voice is in, so each beat cues
  // once and the end of the read is noticed; null while she is quiet.
  ToneTrack? _reading;
  int _cue = -1;

  // How far the voice got into [_reading], and where its words are over:
  // a playhead gone after that point is a read heard out, before it one
  // stopped or paused short.
  Duration _heard = Duration.zero;
  Duration _wordsEnd = Duration.zero;

  @override
  void initState() {
    super.initState();
    _animator = CompanionAnimator(seed: widget.seed);
    widget.controller?._animator = _animator;
    _pose = _advance(0);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion holds her still in the pose she stands in; she moves
    // again once the platform allows it.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      // A restarted ticker counts from zero again.
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(CompanionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._animator = null;
      widget.controller?._animator = _animator;
    }
    final holding = widget.holding;
    if (holding != null && holding != oldWidget.holding) {
      _animator.play(holding);
    }
  }

  @override
  void dispose() {
    widget.controller?._animator = null;
    _ticker.dispose();
    super.dispose();
  }

  CompanionPose _advance(double dt) {
    final holding = widget.holding;
    if (holding != null && _animator.gesture == null) _animator.play(holding);
    final track = widget.track;
    final position = widget.playhead?.call();
    return _animator.step(
      dt,
      mood: _moodAt(track, position),
      speech: track == null || position == null
          ? null
          : (track: track, position: position),
      lookAt: widget.lookAt,
      autoGestures: widget.autoGestures,
    );
  }

  /// Her mood for the words at [position]: the reaction to their tone while
  /// they read one way or the other, the host's [CompanionView.mood]
  /// otherwise. Cues on the way what the words cue: a reaction's gesture as
  /// the tone changes, a beat's face, and her last word ([_followBeats]).
  CompanionMood _moodAt(MouthTrack? track, Duration? position) {
    final tone = widget.tone;
    final speaking =
        tone != null &&
        track != null &&
        position != null &&
        !position.isNegative &&
        position < track.length;
    _followBeats(speaking ? tone : null, track, position);
    final approval = speaking ? tone.approvalAt(position) : null;
    if (approval == null) {
      _approval = null;
      return widget.mood;
    }
    final reaction = companionReaction(approval, sass: widget.sass);
    if (approval != _approval) {
      _approval = approval;
      final gesture = reaction.gesture;
      if (gesture != null) _animator.play(gesture);
    }
    return reaction.mood;
  }

  /// Pulls the face of each beat [tone] reaches at [position], and her last
  /// word once a read is over: [tone] null after the voice got within
  /// [_lastWordSlack] of the words' end ([ToneTrack.end], or the end of
  /// [track]). The speaker's playhead goes null for a pause and for a stop
  /// alike, so how far the voice got is what tells a read heard out from
  /// one cut short; a read cut short has no last word and keeps its place,
  /// so a resume does not pull the same face again.
  void _followBeats(ToneTrack? tone, MouthTrack? track, Duration? position) {
    if (tone != null && !identical(tone, _reading)) {
      _reading = tone;
      _cue = -1;
      _heard = Duration.zero;
      _wordsEnd = (tone.end ?? track!.length) - _lastWordSlack;
    }
    if (position != null && position > _heard) _heard = position;
    final reading = _reading;
    if (reading == null) return;
    if (tone == null) {
      if (_heard < _wordsEnd) return;
      _reading = null;
      _cue = -1;
      final last = companionSignOff(
        reading.cues.map((c) => c.approval),
        sass: widget.sass,
      );
      if (last != null) _animator.flourish(last);
      return;
    }
    final index = tone.indexAt(position!);
    if (index == _cue) return;
    _cue = index;
    if (index < 0) return;
    final cue = tone.cues[index];
    final beat = cue.beat;
    if (beat == null) return;
    final face = companionBeat(beat, cue.approval, sass: widget.sass);
    if (face != null) _animator.flourish(face);
  }

  void _onTick(Duration elapsed) {
    // A long frame (a stall, a tab switch) moves her one short step, not a
    // jump.
    final dt = math.min(
      (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond,
      1 / 20,
    );
    _last = elapsed;
    setState(() => _pose = _advance(dt));
  }

  @override
  Widget build(BuildContext context) {
    // Only she is supersampled; the stage is gradients with no edges to
    // alias, painted once at device resolution behind and over her own
    // layer, which is all that repaints each frame.
    final figure = RepaintBoundary(
      child: CustomPaint(
        painter: SupersampledPainter(
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          factor: widget.supersample ?? CompanionView.platformSupersample,
          inner: CompanionPainter(
            pose: _pose,
            look: widget.look,
            framing: widget.framing,
            stage: widget.stage,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
    if (!widget.stage) return figure;
    return CustomPaint(
      painter: CompanionStageGround(framing: widget.framing),
      foregroundPainter: const CompanionStageVignette(),
      child: figure,
    );
  }
}
