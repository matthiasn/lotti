import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/clip_evaluator.dart';
import 'package:lotti/features/character/model/clip.dart';

void main() {
  const evaluator = ClipEvaluator();

  const looping = Clip(
    name: 'c',
    duration: 2,
    locomotionSpeed: 10,
    root: SineRootChannel(bobAmplitude: 4, bobHarmonic: 1),
    channels: {'b': SineChannel(amplitude: 1)},
  );

  const oneShot = Clip(name: 'o', duration: 2, loop: false, channels: {});

  group('phaseAt', () {
    test('looping clip wraps phase into 0..1', () {
      expect(evaluator.phaseAt(looping, 0), 0);
      expect(evaluator.phaseAt(looping, 1), closeTo(0.5, 1e-12));
      expect(evaluator.phaseAt(looping, 2), closeTo(0, 1e-12));
      expect(evaluator.phaseAt(looping, 3), closeTo(0.5, 1e-12));
    });

    test('negative time still wraps into 0..1', () {
      final p = evaluator.phaseAt(looping, -0.5);
      expect(p, greaterThanOrEqualTo(0));
      expect(p, lessThan(1));
      expect(p, closeTo(0.75, 1e-12));
    });

    test('one-shot clamps phase at the ends', () {
      expect(evaluator.phaseAt(oneShot, -1), 0);
      expect(evaluator.phaseAt(oneShot, 1), 0.5);
      expect(evaluator.phaseAt(oneShot, 99), 1);
    });
  });

  group('evaluate', () {
    test('samples each channel and the root at the right phase', () {
      // t=0.5 -> phase 0.25 -> sin(2π·0.25)=1.
      final pose = evaluator.evaluate(looping, 0.5);
      expect(pose.jointOf('b').rotation, closeTo(1, 1e-9));
      expect(pose.rootDy, closeTo(4, 1e-9));
    });

    test('absent bones fall back to the identity joint pose', () {
      final pose = evaluator.evaluate(looping, 0.5);
      expect(pose.jointOf('missing').rotation, 0);
      expect(pose.jointOf('missing').scaleX, 1);
    });
  });

  test('locomotionOffset scales with speed and time', () {
    expect(evaluator.locomotionOffset(looping, 3), 30);
    expect(evaluator.locomotionOffset(oneShot, 3), 0);
  });

  test('locomotionOffset freezes a one-shot at its duration', () {
    const movingOneShot = Clip(
      name: 'm',
      duration: 2,
      loop: false,
      locomotionSpeed: 10,
      channels: {},
    );
    // Travels while the clip plays...
    expect(evaluator.locomotionOffset(movingOneShot, 1), 10);
    expect(evaluator.locomotionOffset(movingOneShot, 2), 20);
    // ...then holds at the end instead of drifting forever.
    expect(evaluator.locomotionOffset(movingOneShot, 5), 20);
    expect(evaluator.locomotionOffset(movingOneShot, 100), 20);
  });

  test('locomotionOffset keeps integrating for looping clips', () {
    expect(evaluator.locomotionOffset(looping, 10), 100);
  });
}
