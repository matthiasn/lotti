import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/face.dart';

/// A weighted expression, for blending (e.g. 70% happy + 30% surprised).
class ExpressionWeight {
  const ExpressionWeight(this.expression, this.weight);

  final Expression expression;
  final double weight;
}

/// Combines expressions and the autonomic layer into the final [FaceState] the
/// painter consumes. Blending is per-knob so emotions mix continuously; the
/// mouth shape (discrete) is taken from the dominant expression.
class FaceSolver {
  const FaceSolver();

  /// Weighted blend of expression states. Weights need not sum to 1; they are
  /// normalized. The mouth shape is the dominant (highest-weight) expression's.
  FaceState blend(List<ExpressionWeight> inputs) {
    if (inputs.isEmpty) return const FaceState();
    if (inputs.length == 1) return inputs.first.expression.state;

    var total = 0.0;
    for (final i in inputs) {
      total += i.weight;
    }
    if (total <= 0) return inputs.first.expression.state;

    var mouthOpen = 0.0;
    var browRaiseL = 0.0;
    var browRaiseR = 0.0;
    var browAngleL = 0.0;
    var browAngleR = 0.0;
    var eyeOpenL = 0.0;
    var eyeOpenR = 0.0;
    var lookX = 0.0;
    var lookY = 0.0;

    var dominant = inputs.first;
    for (final i in inputs) {
      final w = i.weight / total;
      final s = i.expression.state;
      mouthOpen += s.mouthOpen * w;
      browRaiseL += s.browRaiseLeft * w;
      browRaiseR += s.browRaiseRight * w;
      browAngleL += s.browAngleLeft * w;
      browAngleR += s.browAngleRight * w;
      eyeOpenL += s.eyeOpenLeft * w;
      eyeOpenR += s.eyeOpenRight * w;
      lookX += s.eyeLookX * w;
      lookY += s.eyeLookY * w;
      if (i.weight > dominant.weight) dominant = i;
    }

    return FaceState(
      mouthShape: dominant.expression.state.mouthShape,
      mouthOpen: mouthOpen,
      browRaiseLeft: browRaiseL,
      browRaiseRight: browRaiseR,
      browAngleLeft: browAngleL,
      browAngleRight: browAngleR,
      eyeOpenLeft: eyeOpenL,
      eyeOpenRight: eyeOpenR,
      eyeLookX: lookX,
      eyeLookY: lookY,
    );
  }

  /// Layers the autonomic [sample] onto a [base] expression: blink multiplies
  /// eyelid openness, eye-darts add to gaze. Breathing is a body signal and is
  /// applied elsewhere, not here.
  FaceState applyAutonomic(FaceState base, AutonomicSample sample) =>
      base.copyWith(
        eyeOpenLeft: base.eyeOpenLeft * sample.eyeOpen,
        eyeOpenRight: base.eyeOpenRight * sample.eyeOpen,
        eyeLookX: (base.eyeLookX + sample.eyeDartX).clamp(-1.0, 1.0),
        eyeLookY: (base.eyeLookY + sample.eyeDartY).clamp(-1.0, 1.0),
      );
}
