/// How the companion carries herself: her face, and how quickly she
/// breathes, blinks and glances.
///
/// The first five reflect the record without guilt: a missed day reads as
/// tired, never as hurt, and no mood ever asks you to come back. These are the
/// states proposed in
/// `docs/implementation_plans/2026-10-12_in_app_agent_avatar.md`.
///
/// The rest are reactions: how she takes a piece of work, from [delighted]
/// down to [stern], warm or sassy. A host reaches them through
/// `companionReaction` rather than by name, which pairs each with a gesture.
/// Disapproval is sass — a raised brow, a flat look, a frown — never hurt,
/// and never attached to a notification.
///
/// The goal card derives a mood from a goal's track status
/// (`goalCompanionPose`); every other host leaves her [calm]. A mood changes
/// her face by a few pixels at avatar sizes, so a host that needs its verdict
/// read at a glance pairs it with a held gesture, as the goal card does.
///
/// [smileSkew] and [browSkew] are the asymmetric faces: positive lifts her
/// right mouth corner or brow (screen right) and lowers the left by as much.
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
  ),

  /// Well done, and she knows you know it: chin up, a contented smile.
  proud(smile: 0.2, squint: 0.2, brow: 0.15, pitch: -0.12, bounce: 0.6),

  /// Beaming: the widest smile, eyes creased, a bounce.
  delighted(smile: 0.5, squint: 0.45, brow: 0.6, bounce: 2, glanceRate: 1.3),

  /// "Well, look at you": a one-sided smile under lowered lids, one brow up.
  smug(
    smile: -0.2,
    smileSkew: 0.9,
    browSkew: 0.8,
    lids: 0.28,
    pitch: -0.08,
    glanceRate: 0.7,
  ),

  /// "Really?": one brow high, the mouth pulled flat to one side.
  skeptical(
    smile: -0.8,
    smileSkew: -0.6,
    brow: 0.3,
    browSkew: 2.2,
    lids: 0.15,
    glanceRate: 0.6,
    blinkRate: 0.8,
  ),

  /// Deadpan: heavy lids, a flat mouth, eyes that barely move.
  unimpressed(
    smile: -0.9,
    brow: -0.4,
    lids: 0.5,
    glanceRate: 0.35,
    blinkRate: 0.5,
    breathRate: 0.85,
  ),

  /// Let down, gently: the corners down, the inner brows up, head a little
  /// low.
  disappointed(
    smile: -1.2,
    tilt: 1.1,
    brow: 0.2,
    pitch: 0.12,
    glanceRate: 0.8,
    breathRate: 0.9,
  ),

  /// The look over the glasses: brows down and drawn in, a firm mouth.
  stern(smile: -1.3, brow: -1, tilt: -1.4, squint: 0.3, glanceRate: 0.5);

  const CompanionMood({
    this.smile = 0,
    this.smileSkew = 0,
    this.squint = 0,
    this.brow = 0,
    this.browSkew = 0,
    this.tilt = 0,
    this.lids = 0,
    this.pitch = 0,
    this.bounce = 0,
    this.glanceRate = 1,
    this.blinkRate = 1,
    this.breathRate = 1,
  });

  /// Added to the base smile; below zero turns the corners down.
  final double smile;

  /// Lifts the right corner of the mouth and lowers the left: a smirk.
  final double smileSkew;
  final double squint;

  /// Below zero lowers the brows.
  final double brow;

  /// Lifts the right brow and lowers the left.
  final double browSkew;

  /// Inner brow ends up: worry; below zero, drawn down: sternness.
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
