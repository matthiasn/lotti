/// A face she pulls for a moment, on top of her mood and whatever her hands
/// are doing: a wink, a side-eye, the look over the glasses.
///
/// A flourish moves only the face and the head, never the arms, so it lands
/// in the middle of a talking gesture or a held reaction without
/// interrupting either. It rises, holds, and fades back by itself over
/// [duration]; the animator (`CompanionAnimator.flourish`) adds its values to
/// the mood's and the gesture's, and pulls her eyes towards its [gaze].
///
/// They are the beats of her sass while she reads (`companionBeat`) and the
/// last word once she has finished (`companionSignOff`). None of them is
/// ever hurt: they tease.
enum CompanionFlourish {
  /// "Oh!": both brows jump and the eyes open wide.
  browPop(brow: 0.95, smile: 0.15, lids: -0.1, pitch: -0.04, duration: 0.7),

  /// "Mm-hm.": one brow climbs as far as it goes, a corner of the mouth
  /// follows.
  oneBrow(
    browSkew: 1.9,
    smileSkew: 0.35,
    lids: 0.12,
    roll: 0.05,
    duration: 1.1,
  ),

  /// The look: the eyes slide to one side under lowered lids, the head
  /// turns the other way, and the mouth flattens to a corner.
  sideEye(
    gaze: (0.9, 0.05),
    lids: 0.38,
    yaw: -0.16,
    roll: -0.04,
    smile: -0.25,
    smileSkew: -0.4,
    browSkew: -0.5,
    duration: 1.25,
  ),

  /// The grandmother's classic: chin down, eyes up, brows high — as if over
  /// a pair of reading glasses.
  overTheGlasses(
    gaze: (0, -0.75),
    pitch: 0.2,
    brow: 0.75,
    tilt: -0.3,
    smile: -0.3,
    duration: 1.4,
  ),

  /// "Told you so": the right eye shuts quickly under a lopsided smile.
  wink(
    oneEye: 1,
    smile: 0.3,
    smileSkew: 0.7,
    squint: 0.3,
    roll: 0.07,
    browSkew: -0.3,
    duration: 0.65,
  ),

  /// A smile that only one side of her mouth agrees to.
  smirk(smileSkew: 1, lids: 0.22, browSkew: 0.4, pitch: -0.05, duration: 1),

  /// Suspicion: the eyes narrow, the brows come down and in.
  narrow(
    squint: 0.65,
    lids: 0.3,
    brow: -0.55,
    tilt: -0.6,
    smile: -0.2,
    gaze: (-0.2, 0),
    duration: 1.1,
  ),

  /// "Oh, honey": the head tipped to one side, chin up, a patient smile.
  headTilt(
    roll: 0.16,
    pitch: -0.06,
    brow: 0.3,
    browSkew: 0.5,
    smile: 0.2,
    duration: 1.2,
  );

  const CompanionFlourish({
    required this.duration,
    this.brow = 0,
    this.browSkew = 0,
    this.tilt = 0,
    this.smile = 0,
    this.smileSkew = 0,
    this.squint = 0,
    this.lids = 0,
    this.oneEye = 0,
    this.gaze,
    this.roll = 0,
    this.yaw = 0,
    this.pitch = 0,
  });

  /// Seconds from its start until it has faded away.
  final double duration;
  final double brow;

  /// Lifts the right brow (screen right) and lowers the left.
  final double browSkew;

  /// Inner brow ends up: worry; below zero, drawn down: sternness.
  final double tilt;
  final double smile;

  /// Lifts the right corner of the mouth and lowers the left: a smirk.
  final double smileSkew;
  final double squint;

  /// How far the upper lids close, added to the resting lids; below zero
  /// lifts lids a mood has lowered.
  final double lids;

  /// Shuts the right eye (screen right) at 1, the left at -1, and leaves the
  /// other one open: a wink.
  final double oneEye;

  /// Where her eyes go while it holds, each axis about -1..1; null leaves
  /// them where they were.
  final (double, double)? gaze;
  final double roll;
  final double yaw;
  final double pitch;

  /// How strongly it shows [since] seconds after it started: rising quickly,
  /// holding, and fading over the last third; 0 before and after.
  double envelope(double since) {
    if (since < 0 || since >= duration) return 0;
    final attack = duration * 0.18;
    final release = duration / 3;
    if (since < attack) return _ease(since / attack);
    if (since > duration - release) {
      return _ease((duration - since) / release);
    }
    return 1;
  }

  static double _ease(double t) => t * t * (3 - 2 * t);
}
