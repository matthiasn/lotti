import 'package:lotti/features/companion/model/mouth_shape.dart';

/// Something she says, as the face needs it: the mouth's shape and how loud
/// the voice is at any point of the clip.
///
/// The playhead is the clock: the view asks for the shape at the player's
/// position each frame, so a stall or a seek can never put the mouth out of
/// step with the voice.
abstract interface class MouthTrack {
  /// How long the clip runs.
  Duration get length;

  /// The mouth at [position]; the rest shape outside the clip.
  MouthShape mouthAt(Duration position);

  /// The voice's loudness at [position], 0..1; 0 outside the clip.
  double loudnessAt(Duration position);
}
