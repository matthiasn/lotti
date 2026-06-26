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

    test('harmonic multiplier controls the secondary pulse frequency', () {
      const ch = SineChannel(harmonicAmplitude: 1, harmonicMultiplier: 4);
      // sin(2π·4·0.0625) = sin(π/2) = 1.
      expect(ch.sample(0.0625).rotation, closeTo(1, 1e-9));
    });

    test('scaleY oscillation defaults to a flat 1', () {
      const ch = SineChannel(amplitude: 1);
      expect(ch.sample(0.3).scaleY, 1);
    });
  });

  group('LayeredJointChannel', () {
    test('adds rotations and multiplies scale pulses', () {
      const ch = LayeredJointChannel([
        KeyframeChannel([
          Keyframe(p: 0, rotation: 0.1, scaleX: 1.1, scaleY: 0.9),
          Keyframe(
            p: 1,
            rotation: 0.1,
            scaleX: 1.1,
            scaleY: 0.9,
            ease: Ease.linear,
          ),
        ]),
        SineChannel(
          bias: 0.2,
          scaleXAmplitude: 0.1,
          scaleYAmplitude: -0.1,
        ),
      ]);

      final pose = ch.sample(0.25);
      expect(pose.rotation, closeTo(0.3, 1e-9));
      expect(pose.scaleX, closeTo(1.21, 1e-9));
      expect(pose.scaleY, closeTo(0.81, 1e-9));
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

    group('smooth (periodic spline)', () {
      // A sine-shaped closed loop: peaks at 0.25/0.75, zero-crossings (but
      // moving) at 0/0.5/1.
      const keys = [
        Keyframe(p: 0),
        Keyframe(p: 0.25, rotation: 1),
        Keyframe(p: 0.5),
        Keyframe(p: 0.75, rotation: -1),
        Keyframe(p: 1),
      ];
      const smooth = KeyframeChannel(keys, smooth: true);
      const eased = KeyframeChannel(keys);

      test('still passes through every key value', () {
        expect(smooth.sample(0).rotation, closeTo(0, 1e-6));
        expect(smooth.sample(0.25).rotation, closeTo(1, 1e-6));
        expect(smooth.sample(0.5).rotation, closeTo(0, 1e-6));
        expect(smooth.sample(0.75).rotation, closeTo(-1, 1e-6));
      });

      double speedAt(KeyframeChannel c, double p) =>
          (c.sample(p + 0.01).rotation - c.sample(p - 0.01).rotation).abs();

      test('flows THROUGH a pass-through key (no stop), unlike eased', () {
        // At p=0.5 the value is 0 but the motion is sweeping +1 -> -1, so a real
        // continuous curve is moving fast there. The smooth spline keeps its
        // speed; the eased channel decelerates to ~0 (stops at the key) — the
        // stutter this mode exists to remove.
        expect(speedAt(smooth, 0.5), greaterThan(0.05));
        expect(speedAt(eased, 0.5), lessThan(0.02));
      });
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

    test('sway and lean can use harmonic multipliers', () {
      const root = SineRootChannel(
        swayAmplitude: 2,
        swayHarmonic: 2,
        leanAmplitude: 0.5,
        leanHarmonic: 2,
      );
      final s = root.sample(0.125);
      expect(s.dx, closeTo(2, 1e-9));
      expect(s.rotation, closeTo(0.5, 1e-9));
    });
  });

  group('LayeredRootChannel', () {
    test('adds root samples from all child channels', () {
      const root = LayeredRootChannel([
        KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 1, dx: 4, dy: 6, rotation: 0.2, ease: Ease.linear),
        ]),
        SineRootChannel(bobAmplitude: 2, bobHarmonic: 1),
      ]);

      final s = root.sample(0.25);
      expect(s.dx, closeTo(1, 1e-9));
      expect(s.dy, closeTo(3.5, 1e-9));
      expect(s.rotation, closeTo(0.05, 1e-9));
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

    test('smooth cyclic root passes through authored beats', () {
      const smooth = KeyframeRootChannel([
        RootKeyframe(p: 0),
        RootKeyframe(p: 0.25, dx: 10, dy: -2),
        RootKeyframe(p: 0.5),
        RootKeyframe(p: 0.75, dx: -10, dy: -2),
        RootKeyframe(p: 1),
      ], smooth: true);

      expect(smooth.sample(0.25).dx, closeTo(10, 1e-9));
      expect(smooth.sample(0.75).dx, closeTo(-10, 1e-9));
      expect(smooth.sample(0.125).dx, greaterThan(0));
      expect(smooth.sample(0.625).dx, lessThan(0));
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
    expect(const LayeredJointChannel([]), isA<JointChannel>());
  });

  group('Clip', () {
    test('contact spans do not make an in-place clip locomote', () {
      const clip = Clip(
        name: 'tap',
        duration: 1,
        channels: {},
        contactSpans: [GroundSpan('foot.L', 0, 1)],
      );

      expect(clip.contactSpans.single.bone, 'foot.L');
      expect(clip.groundSpans, isEmpty);
      expect(clip.locomotes, isFalse);
      expect(clip.contactPinning, ContactPinning.activeSpan);
    });

    test('can declare lowest-contact pinning for dance-style clips', () {
      const clip = Clip(
        name: 'dance-role',
        duration: 1,
        channels: {},
        contactSpans: [GroundSpan('foot.L', 0, 1)],
        contactPinning: ContactPinning.lowestContact,
      );

      expect(clip.contactPinning, ContactPinning.lowestContact);
      expect(clip.locomotes, isFalse);
    });
  });
}
