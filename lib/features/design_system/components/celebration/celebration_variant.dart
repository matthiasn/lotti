/// The selectable look of the completion celebration — the particle "language"
/// thrown when a task closes, a habit is completed, or a checklist item is
/// checked off. The user picks one in Settings → Advanced → Animations and it
/// applies to every celebration site.
///
/// Each value maps to a dedicated burst painter (see `completion_burst.dart`);
/// the staging, glow, anchor pop, and overlay lifecycle around it are shared, so
/// switching variant only swaps the particle field, never the choreography.
///
/// The serialized form is [name]; persisted under `CELEBRATE_VARIANT` in
/// `SettingsDb`. [fromStorage] tolerates an absent or unrecognised value (an
/// older build, a hand-edited row) by falling back to [defaultVariant], so a bad
/// string can never crash a celebration on the frame it would fire.
enum CelebrationVariant {
  /// The original accent spark burst — fine comet motes flung radially and
  /// withering. Neutral, restrained, and the default so existing users see no
  /// change until they choose otherwise.
  sparks,

  /// Energetic: a firework shell that flies up, bursts into a coloured ring, and
  /// rains glittering fallout.
  fireworks,

  /// Playful: tumbling rectangular confetti ribbons that flutter and drift down.
  confetti,

  /// Warm / organic: glowing fire embers that surge up, flicker between amber
  /// and red, and float off as they cool.
  embers,

  /// Warm / organic: soft iridescent bubbles that swell, rise, wobble, and pop.
  bubbles;

  /// The variant applied before the user has chosen one — the existing look, so
  /// nothing changes for current users on upgrade.
  static const CelebrationVariant defaultVariant = CelebrationVariant.sparks;

  /// Parses the persisted [name] back to a variant, falling back to
  /// [defaultVariant] for `null`, empty, or any string that no longer maps to a
  /// value (a renamed/removed variant from another build).
  static CelebrationVariant fromStorage(String? value) =>
      tryFromStorage(value) ?? defaultVariant;

  /// Like [fromStorage] but returns `null` for an absent / unrecognised value
  /// instead of [defaultVariant]. Lets the per-content-type migration tell
  /// "never stored" apart from "stored as the default", so a missing per-event
  /// key can fall through to the legacy global key before defaulting.
  static CelebrationVariant? tryFromStorage(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final variant in CelebrationVariant.values) {
      if (variant.name == value) return variant;
    }
    return null;
  }

  /// Whether this variant's palette is warm (amber/red led) rather than the
  /// cool accent. Drives the glow tint so the bloom behind the burst matches its
  /// particles instead of always reading as the app accent.
  bool get isWarm => this == CelebrationVariant.embers;

  /// Multiplier on the celebration's burst duration, so a variant whose motion
  /// reads too fast at the shared timing can breathe. The base durations are
  /// tuned for the fine [sparks]/[fireworks]/[confetti] particles; the larger,
  /// slower-feeling [bubbles] membranes need longer to swell, rise, and pop, so
  /// they run [_bubblesDurationScale]× the base. Everything else is `1.0`
  /// (unchanged). Applied wherever a burst duration is chosen, so it scales the
  /// look on every surface without per-call-site tuning.
  double get durationScale =>
      this == CelebrationVariant.bubbles ? _bubblesDurationScale : 1.0;

  /// How much longer [bubbles] runs than the base burst timing.
  static const double _bubblesDurationScale = 1.4;
}
