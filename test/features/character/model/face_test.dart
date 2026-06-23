import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/face.dart';

void main() {
  group('Expression presets', () {
    test('there are six built-in presets with distinct names', () {
      expect(Expression.presets.length, 6);
      final names = Expression.presets.map((e) => e.name).toSet();
      expect(names.length, 6);
    });

    test('emotions map to different mouth shapes', () {
      expect(Expression.happy.state.mouthShape, MouthShape.smileOpen);
      expect(Expression.sad.state.mouthShape, MouthShape.sad);
      expect(Expression.surprised.state.mouthShape, MouthShape.surprised);
      expect(Expression.angry.state.mouthShape, MouthShape.angry);
      expect(Expression.neutral.state.mouthShape, MouthShape.neutral);
    });

    test('sad lowers eyelids and tilts inner brows up', () {
      expect(Expression.sad.state.eyeOpenLeft, lessThan(1));
      expect(Expression.sad.state.browAngleLeft, greaterThan(0));
    });
  });

  group('FaceState.copyWith', () {
    test('overrides only the named field', () {
      const base = FaceState(mouthOpen: 0.5, eyeLookX: 0.2);
      final next = base.copyWith(mouthOpen: 1);
      expect(next.mouthOpen, 1);
      expect(next.eyeLookX, 0.2);
      expect(next.mouthShape, base.mouthShape);
    });
  });
}
