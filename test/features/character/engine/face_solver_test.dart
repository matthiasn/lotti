import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/engine/face_solver.dart';
import 'package:lotti/features/character/model/face.dart';

void main() {
  const solver = FaceSolver();

  group('blend', () {
    test('empty input is the neutral face', () {
      expect(solver.blend([]).mouthShape, MouthShape.neutral);
    });

    test('single input returns that expression unchanged', () {
      final s = solver.blend([const ExpressionWeight(Expression.happy, 1)]);
      expect(s.mouthShape, MouthShape.smileOpen);
      expect(s.browRaiseLeft, Expression.happy.state.browRaiseLeft);
    });

    test('weighted blend averages knobs and keeps the dominant mouth', () {
      final s = solver.blend([
        const ExpressionWeight(Expression.happy, 0.7),
        const ExpressionWeight(Expression.surprised, 0.3),
      ]);
      // Dominant is happy -> its mouth shape wins.
      expect(s.mouthShape, MouthShape.smileOpen);
      // browRaise = 0.7·0.3 + 0.3·1.0 = 0.51.
      expect(s.browRaiseLeft, closeTo(0.51, 1e-9));
    });

    test('non-positive total weight falls back to the first input', () {
      final s = solver.blend([
        const ExpressionWeight(Expression.angry, 0),
        const ExpressionWeight(Expression.sad, 0),
      ]);
      expect(s.mouthShape, MouthShape.angry);
    });
  });

  group('applyAutonomic', () {
    test('blink multiplies eyelid openness', () {
      const base = FaceState();
      final blinked = solver.applyAutonomic(
        base,
        const AutonomicSample(
          eyeOpen: 0.4,
          eyeDartX: 0,
          eyeDartY: 0,
          breath: 0,
        ),
      );
      expect(blinked.eyeOpenLeft, closeTo(0.4, 1e-9));
      expect(blinked.eyeOpenRight, closeTo(0.4, 1e-9));
    });

    test('eye-darts add to gaze and clamp to -1..1', () {
      const base = FaceState(eyeLookX: 0.8);
      final darted = solver.applyAutonomic(
        base,
        const AutonomicSample(
          eyeOpen: 1,
          eyeDartX: 0.5,
          eyeDartY: -2,
          breath: 0,
        ),
      );
      expect(darted.eyeLookX, closeTo(1, 1e-9)); // 0.8 + 0.5 clamped
      expect(darted.eyeLookY, closeTo(-1, 1e-9)); // 0 + (-2) clamped
    });
  });
}
