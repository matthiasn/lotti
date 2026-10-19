import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/animation/companion_animator.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/tone_track.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/rig/supersampled_painter.dart';

/// Reads where a voice's playhead is, or null while nothing plays.
typedef PlayheadReader = Duration? Function();

/// Lets the owner of a [CompanionView] cue her: a gesture now, a blink now.
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

  /// Plays [gesture] now; ignored while no view is attached.
  void play(GestureName gesture) => _animator?.play(gesture);

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

  @override
  void initState() {
    super.initState();
    _animator = CompanionAnimator(seed: widget.seed);
    widget.controller?._animator = _animator;
    _pose = _advance(0);
    _ticker = createTicker(_onTick)..start();
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
  /// otherwise.
  CompanionMood _moodAt(MouthTrack? track, Duration? position) {
    final tone = widget.tone;
    final speaking =
        tone != null &&
        track != null &&
        position != null &&
        !position.isNegative &&
        position < track.length;
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
