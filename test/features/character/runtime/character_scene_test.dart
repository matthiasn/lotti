import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

void main() {
  group('CharacterScene', () {
    test('frameAt resolves a world transform for every bone', () {
      final rig = buildCatInSuitRig();
      final scene = CharacterScene(rig);
      final frame = scene.frameAt(clip: CatClips.walk, timeSeconds: 0.4);
      expect(frame.world.length, rig.bones.length);
      for (final bone in rig.bones) {
        expect(frame.world.containsKey(bone.id), isTrue);
      }
    });

    test('locomotionX advances with a constant-speed clip (run)', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final frame = scene.frameAt(clip: CatClips.run, timeSeconds: 2);
      expect(
        frame.locomotionX,
        closeTo(CatClips.run.locomotionSpeed * 2, 1e-9),
      );
    });

    test('foot-locked walk travel advances one stride per cycle', () {
      final scene = CharacterScene(buildCatInSuitRig());
      // duration is 1s, so t=1 is one full cycle and t=2 two cycles; foot-lock
      // travel is periodic, so two cycles cover exactly twice the stride.
      final oneCycle = scene.locomotionOffset(CatClips.walk, 1);
      final twoCycles = scene.locomotionOffset(CatClips.walk, 2);
      expect(oneCycle, greaterThan(0));
      expect(twoCycles, closeTo(2 * oneCycle, 1e-6));
    });

    test('is deterministic: identical scenes resolve identical frames', () {
      final a = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(),
      );
      final b = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(),
      );
      final fa = a.frameAt(clip: CatClips.run, timeSeconds: 0.7);
      final fb = b.frameAt(clip: CatClips.run, timeSeconds: 0.7);
      expect(fa.world['head'], fb.world['head']);
      expect(fa.world['hand.L'], fb.world['hand.L']);
      expect(fa.face.eyeOpenLeft, fb.face.eyeOpenLeft);
    });

    test('blink reaches the face via the autonomic layer', () {
      final scene = CharacterScene(buildCatInSuitRig());
      var minOpen = 1.0;
      for (var i = 0; i < 600; i++) {
        final f = scene.frameAt(clip: CatClips.idle, timeSeconds: i * 0.05);
        if (f.face.eyeOpenLeft < minOpen) minOpen = f.face.eyeOpenLeft;
      }
      expect(minOpen, lessThan(0.1));
    });
  });
}
