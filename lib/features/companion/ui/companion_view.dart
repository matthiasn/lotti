import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/companion/animation/companion_animator.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
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

  /// Plays [gesture] now; ignored while no view is attached.
  void play(GestureName gesture) => _animator?.play(gesture);

  /// Blinks now.
  void blink() => _animator?.blink();
}

/// The companion, alive: she breathes, blinks, glances about and, while a
/// [track] plays, talks with her mouth on it.
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
    this.playhead,
    this.lookAt,
    this.autoGestures = true,
    this.controller,
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
  final PlayheadReader? playhead;

  /// Fixes her eyes on a point (each axis about -1..1) instead of letting
  /// them wander.
  final Offset? lookAt;

  /// Lets her pick talking gestures on her own while she speaks.
  final bool autoGestures;
  final CompanionController? controller;

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
  }

  @override
  void dispose() {
    widget.controller?._animator = null;
    _ticker.dispose();
    super.dispose();
  }

  CompanionPose _advance(double dt) {
    final track = widget.track;
    final position = widget.playhead?.call();
    return _animator.step(
      dt,
      mood: widget.mood,
      speech: track == null || position == null
          ? null
          : (track: track, position: position),
      lookAt: widget.lookAt,
      autoGestures: widget.autoGestures,
    );
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
