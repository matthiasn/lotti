import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/easing.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/runtime/temporal_motion_analyzer.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

void main() {
  group('TemporalMotionAnalyzer', () {
    test('reports exact worst-frame displacement for the dance clip', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const watchedBones = [
        CatBones.hips,
        CatBones.torso,
        CatBones.head,
        CatBones.handL,
        CatBones.handR,
        CatBones.footL,
        CatBones.footR,
        CatBones.tail6,
      ];

      final report = analyzer.analyze(
        clip: CatClips.dance,
        samples: 96,
        boneIds: watchedBones,
      );
      final worst = report.worstDisplacement;

      expect(report.clipName, CatClips.dance.name);
      expect(report.segments, hasLength(96 * watchedBones.length));
      expect(worst.boneId, isIn(watchedBones));
      expect(worst.fromFrame + 1, worst.toFrame);
      expect(worst.fromPhase, closeTo(worst.fromFrame / 96, 1e-9));
      expect(worst.toPhase, closeTo(worst.toFrame / 96, 1e-9));
      expect(
        worst.distance,
        lessThan(22),
        reason:
            'the diagnostic should expose frame-addressed dance snaps before '
            'they reach panel review',
      );
    });

    test('separates acceleration spikes from large but steady travel', () {
      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      const clip = Clip(
        name: 'synthetic-root-snap',
        duration: 1,
        loop: false,
        root: KeyframeRootChannel([
          RootKeyframe(p: 0),
          RootKeyframe(p: 0.5, dx: 120, ease: Ease.linear),
          RootKeyframe(p: 1, dx: 120, ease: Ease.linear),
        ]),
        channels: {},
      );

      final report = analyzer.analyze(
        clip: clip,
        samples: 4,
        boneIds: const [CatBones.hips],
      );

      expect(report.topDisplacements(2), hasLength(2));
      expect(report.worstDisplacement.dx.abs(), closeTo(60, 1e-9));
      expect(report.worstDisplacement.distance, closeTo(60, 0.01));
      expect(report.worstAcceleration.throughFrame, 2);
      expect(report.worstAcceleration.dx.abs(), closeTo(60, 1e-9));
      expect(report.worstAcceleration.magnitude, closeTo(60, 0.01));
    });
  });
}
