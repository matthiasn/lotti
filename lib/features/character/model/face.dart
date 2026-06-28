/// The discrete mouth shapes the face can display.
///
/// Phase 1 uses shape-swap mouths (the plan's cheap, expressive approach):
/// expression selects one of these, and the painter draws the matching shape.
/// Registration is guaranteed by drawing every shape about the same anchor.
enum MouthShape {
  neutral,
  smileClosed,
  smileOpen,
  sad,
  surprised,
  angry,

  /// Singing visemes: a crafted open-mouth cavity (dark interior + pink tongue)
  /// whose jaw drops with [FaceState.mouthOpen], anchored at the top lip so it
  /// opens downward like a real jaw. Below a small opening they collapse to a
  /// thin closed lip line, so word-to-word motion reads as discrete syllables.
  /// The three differ only in width/proportion for vowel variety:
  /// [singAh] wide (the workhorse), [singOh] narrow/round, [singEe] widest/flat.
  singAh,
  singOh,
  singEe,

  /// The "F/V" viseme: the lower lip tucked under the upper teeth (a light teeth
  /// strip resting on a near-closed mouth). The one non-vowel singing shape; it
  /// is what makes audio-driven lip-sync read as real consonants.
  teethOnLip,
}

/// Static geometry of a face, anchored to a bone (the head).
///
/// All positions are in the anchor bone's local space. The face solver does not
/// mutate this; it produces a [FaceState] of control values that the painter
/// combines with this geometry.
class FaceRig {
  const FaceRig({
    required this.anchorBoneId,
    required this.eyeOffsetX,
    required this.eyeOffsetY,
    required this.eyeRadiusX,
    required this.eyeRadiusY,
    required this.pupilRadius,
    required this.browOffsetY,
    required this.browWidth,
    required this.mouthOffsetY,
    required this.mouthWidth,
    required this.mouthHeight,
    required this.eyeColor,
    required this.pupilColor,
    required this.browColor,
    required this.mouthColor,
    required this.muzzleWidth,
    required this.muzzleHeight,
    required this.muzzleColor,
    required this.noseWidth,
    required this.noseHeight,
    required this.noseColor,
    required this.whiskerColor,
    required this.whiskerLength,
  });

  /// Bone the face is parented to (typically the head).
  final String anchorBoneId;

  /// Horizontal distance of each eye from the face centre (mirrored L/R).
  final double eyeOffsetX;
  final double eyeOffsetY;
  final double eyeRadiusX;
  final double eyeRadiusY;
  final double pupilRadius;

  final double browOffsetY;
  final double browWidth;

  final double mouthOffsetY;
  final double mouthWidth;
  final double mouthHeight;

  final int eyeColor;
  final int pupilColor;
  final int browColor;
  final int mouthColor;

  /// A lighter snout patch the nose/mouth sit on.
  final double muzzleWidth;
  final double muzzleHeight;
  final int muzzleColor;

  /// A small downward-pointing nose.
  final double noseWidth;
  final double noseHeight;
  final int noseColor;

  /// Whiskers fan out from beside the nose.
  final int whiskerColor;
  final double whiskerLength;
}

/// The expressive control values of a face at an instant — the ~8 "knobs" the
/// plan calls for. Continuous so expressions can be blended and the autonomic
/// layer (blink, eye-darts) can be layered on top.
class FaceState {
  const FaceState({
    this.mouthShape = MouthShape.neutral,
    this.mouthOpen = 0,
    this.browRaiseLeft = 0,
    this.browRaiseRight = 0,
    this.browAngleLeft = 0,
    this.browAngleRight = 0,
    this.eyeOpenLeft = 1,
    this.eyeOpenRight = 1,
    this.eyeLookX = 0,
    this.eyeLookY = 0,
  });

  /// Which mouth shape to draw.
  final MouthShape mouthShape;

  /// Extra jaw opening, 0..1, scales the mouth vertically.
  final double mouthOpen;

  /// Brow vertical raise, -1 (lowered/angry) .. 1 (raised/surprised).
  final double browRaiseLeft;
  final double browRaiseRight;

  /// Inner-brow tilt, -1 (inner down / angry) .. 1 (inner up / sad).
  final double browAngleLeft;
  final double browAngleRight;

  /// Eyelid openness, 0 (closed) .. 1 (open). Blink drives this toward 0.
  final double eyeOpenLeft;
  final double eyeOpenRight;

  /// Pupil gaze offset, -1..1 in each axis, within the eye.
  final double eyeLookX;
  final double eyeLookY;

  FaceState copyWith({
    MouthShape? mouthShape,
    double? mouthOpen,
    double? browRaiseLeft,
    double? browRaiseRight,
    double? browAngleLeft,
    double? browAngleRight,
    double? eyeOpenLeft,
    double? eyeOpenRight,
    double? eyeLookX,
    double? eyeLookY,
  }) => FaceState(
    mouthShape: mouthShape ?? this.mouthShape,
    mouthOpen: mouthOpen ?? this.mouthOpen,
    browRaiseLeft: browRaiseLeft ?? this.browRaiseLeft,
    browRaiseRight: browRaiseRight ?? this.browRaiseRight,
    browAngleLeft: browAngleLeft ?? this.browAngleLeft,
    browAngleRight: browAngleRight ?? this.browAngleRight,
    eyeOpenLeft: eyeOpenLeft ?? this.eyeOpenLeft,
    eyeOpenRight: eyeOpenRight ?? this.eyeOpenRight,
    eyeLookX: eyeLookX ?? this.eyeLookX,
    eyeLookY: eyeLookY ?? this.eyeLookY,
  );
}

/// A named emotional preset — a point in [FaceState] space.
class Expression {
  const Expression(this.name, this.state);

  final String name;
  final FaceState state;

  /// Built-in presets covering the six v1 expressions.
  static const Expression neutral = Expression('neutral', FaceState());

  static const Expression happy = Expression(
    'happy',
    FaceState(
      mouthShape: MouthShape.smileOpen,
      mouthOpen: 0.4,
      browRaiseLeft: 0.3,
      browRaiseRight: 0.3,
    ),
  );

  static const Expression content = Expression(
    'content',
    FaceState(
      mouthShape: MouthShape.smileClosed,
      browRaiseLeft: 0.1,
      browRaiseRight: 0.1,
    ),
  );

  static const Expression sad = Expression(
    'sad',
    FaceState(
      mouthShape: MouthShape.sad,
      browRaiseLeft: -0.2,
      browRaiseRight: -0.2,
      browAngleLeft: 0.8,
      browAngleRight: 0.8,
      eyeOpenLeft: 0.75,
      eyeOpenRight: 0.75,
    ),
  );

  static const Expression surprised = Expression(
    'surprised',
    FaceState(
      mouthShape: MouthShape.surprised,
      mouthOpen: 0.7,
      browRaiseLeft: 1,
      browRaiseRight: 1,
    ),
  );

  static const Expression angry = Expression(
    'angry',
    FaceState(
      mouthShape: MouthShape.angry,
      browRaiseLeft: -0.6,
      browRaiseRight: -0.6,
      browAngleLeft: -1,
      browAngleRight: -1,
    ),
  );

  static const List<Expression> presets = [
    neutral,
    content,
    happy,
    surprised,
    sad,
    angry,
  ];
}
