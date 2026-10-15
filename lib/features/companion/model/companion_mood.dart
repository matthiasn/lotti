/// How the companion carries herself, reflecting the record without guilt:
/// a missed day reads as tired, never as hurt, and no mood ever asks you to
/// come back.
///
/// These are the states proposed in
/// `docs/implementation_plans/2026-10-12_in_app_agent_avatar.md`. Nothing
/// derives them from the record yet: in this proof of concept the mood is
/// chosen by hand.
enum CompanionMood {
  /// The default: an easy smile.
  calm(),

  /// The plan is done or a streak holds: a bigger smile, a small bounce.
  bright(smile: 0.3, squint: 0.25, brow: 0.25, bounce: 1.2),

  /// The plan is over capacity: brows a touch knit, eyes a little quicker.
  busy(smile: -0.1, tilt: 0.25, glanceRate: 1.6, blinkRate: 1.3),

  /// Overdue tasks pile up: a worried brow and a quick blink, never a scold.
  frazzled(
    smile: -0.2,
    tilt: 0.7,
    brow: 0.2,
    glanceRate: 2.2,
    blinkRate: 1.9,
    breathRate: 1.4,
  ),

  /// A day with nothing recorded: heavy lids, slow breath, head a little
  /// low.
  sleepy(
    smile: -0.1,
    lids: 0.42,
    pitch: 0.14,
    glanceRate: 0.5,
    blinkRate: 0.6,
    breathRate: 0.7,
  );

  const CompanionMood({
    this.smile = 0,
    this.squint = 0,
    this.brow = 0,
    this.tilt = 0,
    this.lids = 0,
    this.pitch = 0,
    this.bounce = 0,
    this.glanceRate = 1,
    this.blinkRate = 1,
    this.breathRate = 1,
  });

  /// Added to the base smile.
  final double smile;
  final double squint;
  final double brow;

  /// Inner brow ends up: worry.
  final double tilt;

  /// How far the upper lids rest closed, 0..1.
  final double lids;
  final double pitch;
  final double bounce;

  /// Multipliers on the idle glance, blink and breath frequencies.
  final double glanceRate;
  final double blinkRate;
  final double breathRate;
}
