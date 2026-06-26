import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/dance_phrase.dart';

void main() {
  group('DancePhrase', () {
    const phrase = DancePhrase(
      frameCount: 32,
      supports: [
        DanceSupportSpan(
          footBoneId: 'foot.L',
          startFrame: 0,
          endFrame: 16,
          label: 'left pocket',
        ),
        DanceSupportSpan(
          footBoneId: 'foot.R',
          startFrame: 16,
          endFrame: 32,
          label: 'right pocket',
        ),
      ],
    );

    test('maps authored frames to normalized clip phase', () {
      expect(phrase.phaseOf(0), 0);
      expect(phrase.phaseOf(4), 0.125);
      expect(phrase.phaseOf(16), 0.5);
      expect(phrase.phaseOf(32), 1);
    });

    test('compiles labelled support windows into ground spans', () {
      final spans = phrase.contactSpans();

      expect(spans.map((span) => span.bone), ['foot.L', 'foot.R']);
      expect(spans.map((span) => span.start), [0, 0.5]);
      expect(spans.map((span) => span.end), [0.5, 1]);
      expect(phrase.supports.map((support) => support.label), [
        'left pocket',
        'right pocket',
      ]);
    });

    test('builds joint channels from frame-addressed keys', () {
      final channel = phrase.jointChannel(
        const [
          DanceJointKey(0, rotation: -0.2),
          DanceJointKey(8, rotation: 0.4, scaleX: 1.1, scaleY: 0.9),
          DanceJointKey(32, rotation: -0.2),
        ],
      );

      expect(channel.sample(0).rotation, closeTo(-0.2, 1e-9));
      expect(channel.sample(0.25).rotation, closeTo(0.4, 1e-9));
      expect(channel.sample(0.25).scaleX, closeTo(1.1, 1e-9));
      expect(channel.sample(1).rotation, closeTo(-0.2, 1e-9));
    });

    test('builds root channels from frame-addressed keys', () {
      final channel = phrase.rootChannel(
        const [
          DanceRootKey(0, dx: -8, dy: 18),
          DanceRootKey(16, dx: 8, dy: 12, rotation: 0.02),
          DanceRootKey(32, dx: -8, dy: 18),
        ],
      );

      expect(channel.sample(0).dx, closeTo(-8, 1e-9));
      expect(channel.sample(0.5).dx, closeTo(8, 1e-9));
      expect(channel.sample(0.5).dy, closeTo(12, 1e-9));
      expect(channel.sample(0.5).rotation, closeTo(0.02, 1e-9));
      expect(channel.sample(1).dx, closeTo(-8, 1e-9));
    });

    test('rejects keys outside the authored phrase', () {
      expect(() => phrase.phaseOf(-1), throwsRangeError);
      expect(() => phrase.jointKey(33), throwsRangeError);
      expect(
        () => const DanceSupportSpan(
          footBoneId: 'foot.L',
          startFrame: 20,
          endFrame: 40,
          label: 'bad',
        ).toGroundSpan(phrase),
        throwsRangeError,
      );
    });
  });
}
