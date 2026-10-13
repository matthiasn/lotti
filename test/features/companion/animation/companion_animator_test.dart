import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/companion_animator.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';

const double _dt = 1 / 60;

/// Steps [a] for [seconds], returning every pose.
List<CompanionPose> _run(
  CompanionAnimator a,
  double seconds, {
  CompanionMood mood = CompanionMood.calm,
  Speech? Function(double t)? speech,
  Offset? lookAt,
  bool autoGestures = false,
}) => [
  for (var i = 0; i < (seconds / _dt).round(); i++)
    a.step(
      _dt,
      mood: mood,
      speech: speech?.call(a.time + _dt),
      lookAt: lookAt,
      autoGestures: autoGestures,
    ),
];

Duration _s(double t) => Duration(microseconds: (t * 1e6).round());

void main() {
  test('she breathes and blinks on her own while idle', () {
    final poses = _run(CompanionAnimator(), 8);
    final breaths = poses.map((p) => p.breath);
    expect(breaths.reduce((a, b) => a > b ? a : b), greaterThan(0.9));
    expect(breaths.reduce((a, b) => a < b ? a : b), lessThan(-0.9));
    final shut = poses.where((p) => p.blink > 0.95).length;
    expect(shut, greaterThan(0));
    // A blink is brief: the eyes are open nearly all the time.
    expect(shut, lessThan(poses.length ~/ 10));
    expect(poses.every((p) => p.mouth.open == 0), isTrue);
  });

  test('the same seed gives the same performance', () {
    final a = _run(CompanionAnimator(seed: 3), 3);
    final b = _run(CompanionAnimator(seed: 3), 3);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].blink, b[i].blink);
      expect(a[i].gaze, b[i].gaze);
    }
  });

  test('a gesture plays, holds and lets go', () {
    final a = CompanionAnimator()..play(GestureName.wave);
    expect(a.gesture, GestureName.wave);
    final during = _run(a, 1);
    expect(during.last.right.wrist.dy, lessThan(-130));
    _run(a, 3);
    expect(a.gesture, isNull);
    expect(a.step(_dt).right.wrist.dy, greaterThan(-80));
  });

  test('a hand-to-face gesture draws the hand over the face', () {
    final a = CompanionAnimator()..play(GestureName.think);
    expect(_run(a, 0.3).last.handInFrontOfFace, isTrue);
  });

  test('a gesture with phases moves on to its later phase', () {
    final a = CompanionAnimator()..play(GestureName.apart);
    final early = _run(a, 0.25).last.left.wrist.dx;
    final late = _run(a, 0.9).last.left.wrist.dx;
    // "apart" starts with the hands together and spreads them.
    expect(late, lessThan(early - 20));
  });

  test('she talks while the playhead is inside the clip, and only then', () {
    final track = TextLipSync('Good morning! Four things today.');
    final a = CompanionAnimator();
    final poses = _run(
      a,
      track.length.inMicroseconds / 1e6 + 1,
      speech: (t) => (track: track, position: _s(t)),
    );
    final talking = poses.take(poses.length - 70);
    expect(
      talking.map((p) => p.mouth.open).reduce((x, y) => x > y ? x : y),
      greaterThan(5),
    );
    expect(poses.last.mouth.open, 0);
  });

  test('a loud voice nods the head', () {
    final env = SpeechEnvelope([
      for (var i = 0; i < 30; i++) 0.0,
      for (var i = 0; i < 90; i++) 1.0,
    ]);
    final a = CompanionAnimator();
    final quiet = _run(a, 0.4, speech: (t) => (track: env, position: _s(t)));
    final loud = _run(
      a,
      0.4,
      speech: (t) => (track: env, position: _s(t + 0.4)),
    );
    expect(
      loud.map((p) => p.headPitch).reduce((x, y) => x > y ? x : y),
      greaterThan(quiet.last.headPitch + 0.1),
    );
  });

  test('while talking with auto gestures, she reaches for one on her own', () {
    final track = TextLipSync(
      'One two three four five six seven eight nine.' * 2,
    );
    final a = CompanionAnimator();
    final picked = <GestureName>{};
    for (var i = 0; i < 240; i++) {
      a.step(
        _dt,
        speech: (track: track, position: _s(a.time)),
      );
      if (a.gesture != null) picked.add(a.gesture!);
    }
    expect(picked, isNotEmpty);
    expect(talkingGestures.toSet().containsAll(picked), isTrue);
  });

  test('lookAt fixes the eyes', () {
    final poses = _run(CompanionAnimator(), 2, lookAt: const Offset(0.8, 0.2));
    expect(poses.last.gaze.dx, closeTo(0.8, 0.01));
    expect(poses.last.gaze.dy, closeTo(0.2, 0.01));
  });

  test('a mood shows on the face', () {
    final calm = _run(CompanionAnimator(), 3).last;
    final sleepy = _run(
      CompanionAnimator(),
      3,
      mood: CompanionMood.sleepy,
    ).last;
    final frazzled = _run(
      CompanionAnimator(),
      3,
      mood: CompanionMood.frazzled,
    ).last;
    final bright = _run(
      CompanionAnimator(),
      3,
      mood: CompanionMood.bright,
    ).last;
    expect(sleepy.blink, greaterThan(0.35));
    expect(frazzled.browTilt, greaterThan(calm.browTilt + 0.5));
    expect(bright.smile, greaterThan(calm.smile + 0.2));
  });

  test('the hair trails a moving head and settles when it stops', () {
    final a = CompanionAnimator()..play(GestureName.celebrate);
    final poses = _run(a, 1.5);
    expect(
      poses.map((p) => p.hairLag.distance).reduce((x, y) => x > y ? x : y),
      greaterThan(0.2),
    );
  });

  test('a manual blink shuts the eyes at once', () {
    final a = CompanionAnimator();
    _run(a, 0.3);
    a.blink();
    final poses = _run(a, 0.12);
    expect(poses.any((p) => p.blink > 0.95), isTrue);
  });
}
