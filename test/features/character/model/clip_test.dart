import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/easing.dart';

void main() {
  group('SineChannel', () {
    test('amplitude and phase shape the rotation', () {
      const ch = SineChannel(amplitude: 2);
      expect(ch.sample(0).rotation, closeTo(0, 1e-9));
      expect(ch.sample(0.25).rotation, closeTo(2, 1e-9));
      expect(ch.sample(0.5).rotation, closeTo(0, 1e-9));
      expect(ch.sample(0.75).rotation, closeTo(-2, 1e-9));
    });

    test('bias offsets every sample', () {
      const ch = SineChannel(amplitude: 1, bias: 0.5);
      expect(ch.sample(0).rotation, closeTo(0.5, 1e-9));
      expect(ch.sample(0.5).rotation, closeTo(0.5, 1e-9));
    });

    test('second harmonic adds a double-frequency term', () {
      const ch = SineChannel(harmonicAmplitude: 1);
      // sin(4π·0.125) = sin(π/2) = 1.
      expect(ch.sample(0.125).rotation, closeTo(1, 1e-9));
    });

    test('scaleY oscillation defaults to a flat 1', () {
      const ch = SineChannel(amplitude: 1);
      expect(ch.sample(0.3).scaleY, 1);
    });
  });

  group('KeyframeChannel', () {
    const ch = KeyframeChannel([
      Keyframe(p: 0),
      Keyframe(p: 0.5, rotation: 1, ease: Ease.linear),
      Keyframe(p: 1, ease: Ease.linear),
    ]);

    test('hits the keys exactly', () {
      expect(ch.sample(0).rotation, 0);
      expect(ch.sample(0.5).rotation, closeTo(1, 1e-9));
      expect(ch.sample(1).rotation, closeTo(0, 1e-9));
    });

    test('linearly interpolates between keys', () {
      expect(ch.sample(0.25).rotation, closeTo(0.5, 1e-9));
      expect(ch.sample(0.75).rotation, closeTo(0.5, 1e-9));
    });

    test('clamps before the first and after the last key', () {
      expect(ch.sample(-1).rotation, 0);
      expect(ch.sample(2).rotation, closeTo(0, 1e-9));
    });

    test('empty channel is the identity', () {
      const empty = KeyframeChannel(<Keyframe>[]);
      expect(empty.sample(0.5).rotation, 0);
      expect(empty.sample(0.5).scaleY, 1);
    });
  });

  group('SineRootChannel', () {
    test('bob uses the harmonic multiplier', () {
      const root = SineRootChannel(bobAmplitude: 3);
      // Default harmonic 2: dy = 3·sin(2·2π·0.125) = 3·sin(π/2) = 3.
      expect(root.sample(0.125).dy, closeTo(3, 1e-9));
    });

    test('sway and lean track the base frequency', () {
      const root = SineRootChannel(swayAmplitude: 2, leanAmplitude: 0.5);
      final s = root.sample(0.25);
      expect(s.dx, closeTo(2, 1e-9));
      expect(s.rotation, closeTo(0.5, 1e-9));
    });
  });

  group('KeyframeRootChannel', () {
    const root = KeyframeRootChannel([
      RootKeyframe(p: 0),
      RootKeyframe(p: 1, dy: 10, ease: Ease.linear),
    ]);

    test('interpolates the body offset', () {
      expect(root.sample(0).dy, 0);
      expect(root.sample(0.5).dy, closeTo(5, 1e-9));
      expect(root.sample(1).dy, closeTo(10, 1e-9));
    });

    test('empty channel yields no motion', () {
      const empty = KeyframeRootChannel(<RootKeyframe>[]);
      final s = empty.sample(0.4);
      expect(s.dx, 0);
      expect(s.dy, 0);
      expect(s.rotation, 0);
    });
  });

  test('both channel kinds belong to the sealed JointChannel hierarchy', () {
    expect(const SineChannel(amplitude: 1), isA<JointChannel>());
    expect(const KeyframeChannel(<Keyframe>[]), isA<JointChannel>());
  });
}
