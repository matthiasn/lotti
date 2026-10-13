import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/features/companion/animation/arm_rig.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// What she is saying this frame: the clip and where its playhead is.
typedef Speech = ({MouthTrack track, Duration position});

/// Gestures she reaches for on her own while she talks.
const List<GestureName> talkingGestures = [
  GestureName.openSmall,
  GestureName.presentRight,
  GestureName.chest,
  GestureName.palmsDown,
  GestureName.speak,
  GestureName.presentLeft,
];

/// Turns time, a mood, gestures and speech into one [CompanionPose] per
/// frame, in real time.
///
/// Gestures set targets and damped springs chase them, which gives ease-in,
/// a little overshoot and the settle for free. On top run the layers that
/// make a figure read as alive: breathing, a sway of the weight, glances,
/// blinks, a nod and a hand beat when the voice swells, and hair and hem that
/// trail the body. Everything random comes from one seeded generator, so a
/// test run is reproducible.
///
/// This is the pitch videos' `motion.py`, made live: the videos know the
/// whole timeline in advance, here the next gesture or line arrives at any
/// moment.
class CompanionAnimator {
  CompanionAnimator({int seed = 11}) : _rng = math.Random(seed) {
    _nextBlink = 0.8;
    _nextGlance = 0;
  }

  final math.Random _rng;
  final ArmRig _left = ArmRig(CompanionGesture.readyLeft, -1);
  final ArmRig _right = ArmRig(CompanionGesture.readyRight, 1);
  final Map<String, Spring> _s = {
    'lean': Spring(0, freq: 1.3),
    'roll': Spring(0, freq: 1.5, zeta: 0.7),
    'yaw': Spring(0, freq: 1.6, zeta: 0.8),
    'pitch': Spring(0, freq: 1.8, zeta: 0.7),
    'brow': Spring(0, freq: 2.6, zeta: 0.6),
    'tilt': Spring(0, freq: 2, zeta: 0.8),
    'smile': Spring(0.5, freq: 1.4, zeta: 0.9),
    'squint': Spring(0, freq: 2, zeta: 0.9),
    'lids': Spring(0, freq: 1.2, zeta: 1),
    'gx': Spring(0, freq: 5, zeta: 0.95),
    'gy': Spring(0, freq: 5, zeta: 0.95),
    'nod': Spring(0, freq: 2.6, zeta: 0.42),
    'bounce': Spring(0, freq: 2, zeta: 1),
    'hairX': Spring(0, freq: 1.5, zeta: 0.3),
    'hairY': Spring(0, freq: 1.8, zeta: 0.35),
    'hem': Spring(0, freq: 1.1, zeta: 0.3),
  };

  double _t = 0;
  double _breathPhase = 0;
  late double _nextBlink;
  double? _blinkStart;
  late double _nextGlance;
  Offset _glance = Offset.zero;
  GestureName? _gesture;
  double _gestureStart = 0;
  double _nextTalkGesture = 0;
  bool _wasSpeaking = false;
  double _lastBeat = -10;
  double _prevLoud = 0;
  Offset? _prevHead;
  double _prevPelvisX = 0;

  /// Seconds since the animator started.
  double get time => _t;

  /// The gesture in play, or null when she stands at ready.
  GestureName? get gesture => _gestureAt()?.$1;

  /// Starts [name] now; it relaxes back to ready after its hold.
  void play(GestureName name) {
    _gesture = name;
    _gestureStart = _t;
  }

  /// Blinks now, as at the end of a phrase.
  void blink() => _blinkStart = _t;

  (GestureName, CompanionGesture)? _gestureAt() {
    final g = _gesture;
    if (g == null) return null;
    final since = _t - _gestureStart;
    if (since >= g.gesture.hold) return null;
    var phase = g.gesture;
    for (final (delay, next) in g.gesture.then) {
      if (since >= delay) phase = next;
    }
    return (g, phase);
  }

  double _blinkAmount() {
    final start = _blinkStart;
    if (start == null) return 0;
    final d = _t - start;
    if (d < 0 || d >= 0.2) return 0;
    if (d < 0.07) return smoothstep(d / 0.07);
    if (d < 0.09) return 1;
    return 1 - smoothstep((d - 0.09) / 0.11);
  }

  /// Advances by [dt] seconds and returns the pose for this frame.
  ///
  /// [speech] is what she is saying, if anything; [lookAt] fixes her eyes
  /// (each axis about -1..1) instead of letting them wander; [autoGestures]
  /// lets her pick talking gestures on her own while she speaks.
  CompanionPose step(
    double dt, {
    CompanionMood mood = CompanionMood.calm,
    Speech? speech,
    Offset? lookAt,
    bool autoGestures = true,
  }) {
    _t += dt;
    final t = _t;
    final s = _s;
    final loud = speech == null
        ? 0.0
        : speech.track.loudnessAt(speech.position);
    final speaking =
        speech != null &&
        !speech.position.isNegative &&
        speech.position < speech.track.length;
    final mouth = speaking
        ? speech.track.mouthAt(speech.position)
        : Viseme.x.shape;

    if (speaking && !_wasSpeaking) _nextTalkGesture = t + 0.4;
    if (!speaking && _wasSpeaking) blink();
    _wasSpeaking = speaking;
    if (speaking && autoGestures && t >= _nextTalkGesture) {
      if (_gestureAt() == null) {
        play(talkingGestures[_rng.nextInt(talkingGestures.length)]);
      }
      _nextTalkGesture = t + 2.2 + _rng.nextDouble() * 1.8;
    }

    // A nod and a small hand beat when the voice swells.
    var kick = 0.0;
    if (speaking && loud > 0.55 && _prevLoud <= 0.55 && t - _lastBeat > 0.75) {
      s['nod']!.v += 2.4;
      kick = 55;
      _lastBeat = t;
    }
    _prevLoud = loud;
    final nod = s['nod']!.step(0, dt);

    if (t >= _nextBlink) {
      _blinkStart = t;
      _nextBlink = t + (2.4 + _rng.nextDouble() * 2.2) / mood.blinkRate;
    }
    if (t >= _nextGlance) {
      _glance = Offset(
        (_rng.nextDouble() * 2 - 1) * 0.14,
        -0.1 + _rng.nextDouble() * 0.16,
      );
      _nextGlance = t + (0.6 + _rng.nextDouble() * 1.3) / mood.glanceRate;
    }

    final current = _gestureAt();
    final g = current?.$2 ?? CompanionGesture.ready;
    final gaze =
        lookAt ?? (g.gaze == null ? _glance : Offset(g.gaze!.$1, g.gaze!.$2));
    final bounceEnv = s['bounce']!.step(g.bounce + mood.bounce, dt);
    final bounce = -bounceEnv * math.sin(2 * math.pi * 1.6 * t).abs();
    _breathPhase += dt * 2 * math.pi / 4 * mood.breathRate;
    final pelvisX = 3.2 * noise1(t * 0.35, 1);
    final baseSmile = (speaking ? 0.3 : 0.5) + mood.smile;
    final lids = s['lids']!.step(mood.lids, dt);
    final pulse = _blinkAmount();

    final pose = CompanionPose(
      pelvis: Offset(pelvisX, bounce + 0.8 * noise1(t * 0.6, 4)),
      lean: s['lean']!.step(g.lean + 0.012 * noise1(t * 0.3, 2), dt),
      breath: math.sin(_breathPhase),
      headRoll: s['roll']!.step(g.roll + 0.025 * noise1(t * 0.5, 3), dt),
      headYaw: s['yaw']!.step(g.yaw + 0.08 * noise1(t * 0.4, 5), dt),
      headPitch:
          s['pitch']!.step(g.pitch + mood.pitch, dt) + nod * 0.6 + 0.12 * loud,
      headOffset: Offset(0, nod * 2 - 0.6 * loud),
      gaze: Offset(s['gx']!.step(gaze.dx, dt), s['gy']!.step(gaze.dy, dt)),
      blink: lids + (1 - lids) * pulse,
      squint: s['squint']!.step(g.squint + mood.squint, dt),
      browRaise: s['brow']!.step(
        g.brow + mood.brow + (speaking ? 0.35 * loud : 0),
        dt,
      ),
      browTilt: s['tilt']!.step(g.tilt + mood.tilt, dt),
      smile: s['smile']!.step(clampUnit(baseSmile + g.smile), dt),
      mouth: mouth,
      left: _left.step(
        g.left ?? CompanionGesture.readyLeft,
        g.oscLeft,
        t,
        dt,
        beatKick: g.left == null ? kick : 0,
      ),
      right: _right.step(
        g.right ?? CompanionGesture.readyRight,
        g.oscRight,
        t,
        dt,
        beatKick: g.right == null ? kick : 0,
      ),
      handInFrontOfFace: g.faceHand,
    );

    // Secondary motion: the hair and the hem trail the body.
    final head = RigFrame(pose).head.origin;
    final prevHead = _prevHead ?? head;
    _prevHead = head;
    final v = dt > 0 ? (head - prevHead) / dt : Offset.zero;
    final pvx = dt > 0 ? (pelvisX - _prevPelvisX) / dt : 0.0;
    _prevPelvisX = pelvisX;
    return _withTrail(
      pose,
      Offset(
        s['hairX']!.step(clampUnit(-v.dx * 0.09, -7, 7), dt),
        s['hairY']!.step(clampUnit(-v.dy * 0.06, -4, 4), dt),
      ),
      s['hem']!.step(clampUnit(-pvx * 0.6, -5, 5), dt),
    );
  }
}

CompanionPose _withTrail(CompanionPose p, Offset hairLag, double hemLag) =>
    CompanionPose(
      pelvis: p.pelvis,
      lean: p.lean,
      breath: p.breath,
      headRoll: p.headRoll,
      headYaw: p.headYaw,
      headPitch: p.headPitch,
      headOffset: p.headOffset,
      hairLag: hairLag,
      hemLag: hemLag,
      left: p.left,
      right: p.right,
      gaze: p.gaze,
      blink: p.blink,
      squint: p.squint,
      browRaise: p.browRaise,
      browTilt: p.browTilt,
      smile: p.smile,
      mouth: p.mouth,
      handInFrontOfFace: p.handInFrontOfFace,
    );
