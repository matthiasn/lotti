/// A small "virtual director" for the dance-to-track demo's camera. Instead of
/// looping one push-in move every phrase, it gives each song section its own
/// treatment, scheduled against the bar grid and the section's own progress:
///
/// - calm intro/outro: a wide establish with a slow breathe;
/// - pre-chorus: a strictly monotonic crane-push that builds tension into the drop;
/// - verse: a grounded, centred medium with a slow continuous push and gentle
///   drift — the calm pocket that contrasts the favouring choruses and the
///   swinging bridge, alive rather than frozen;
/// - chorus: each refrain owns a DISTINCT, STABLE home held WIDE enough for the
///   vista and legwork to breathe — the first chorus centred, the second a
///   committed LEFT two-shot (silver), the third a committed RIGHT two-shot
///   (dark), all capped well under the climax. The rig CUTS into each chorus on
///   the downbeat (the Afrobeats cut-on-the-"1") and holds the home;
/// - bridge (background-only): the lead is silent and the backups trade the
///   vocal, so the camera follows the VOICE — it CUTS onto the silver singer for
///   the first half, then CUTS to the brown singer for the second, two committed
///   singer-feature two-shots rather than one wide sweep that spotlights neither;
/// - post-chorus (closing hook): the climax — a centred COIL that visibly LOADS
///   off-centre (with one motivated mid-coil push so the long load breathes), then
///   the reserved climax CUT onto the money LEGWORK-hero: a low push that lifts the
///   lead's legwork to frame centre (Afrobeats peaks on the legs), the single
///   tightest framing in the whole piece, backups flung to edge-slivers;
/// - outro: a de-escalation that settles down into the establish.
///
/// The painter pins the dance camera's zoom pivot at the dancers' feet, so a
/// push-in plants the feet on the deck and grows the cast UP into the sky rather
/// than craning the feet off the bottom edge — which lets the hooks zoom in HARD
/// (the lead reads as a real close-up) with feet, shadows and low hand-swings all
/// still in frame, and no leftover dead sky above the heads. Because the trio
/// stays centred on the lead, a side cat only reaches frame-centre at an extreme
/// zoom (the lead clips the stage edge first), so feature shots are *leaning
/// two-shots* that weight the frame toward a backup while the lead — always
/// centred by the painter — stays the readable star. Most dance shots ride
/// `dy: 0`; the calm idle/outro wides carry a small positive `dy` trim, and the
/// climax legwork-hero carries a shallow NEGATIVE `dy` ([kHeroLegworkLiftRef])
/// that lifts the lead just enough to fill the frame head-to-toe with the legwork
/// while keeping the cast shadow under the feet (the painter rescales `dy` against
/// the stage height, so it frames the same fraction at any size).
///
/// Pure and deterministic so it is unit-testable and renders identically offline
/// and live. The output `(zoom, dx, dy)` is the camera's TARGET for the frame.
/// The demo does not apply it raw: a stateful `DanceCameraRig` eases the live
/// camera toward this target every tick, so a change of section/home reads as a
/// motivated DOLLY rather than a snap (a sustained dolly reads as higher
/// production value than a cut). The exceptions are the genre CUTS: the rig snaps
/// on the downbeat into each chorus ([isChorusDrop]), onto each bridge
/// singer-feature ([isBridgeCut]), and onto the reserved climax hero
/// ([isHardCut]); verses stay dollies. The eased shot is what reaches
/// `CharacterPainter.cameraOverride`.
library;

import 'dart:math' as math;

/// One framing: zoom about the frame centre plus a pan/crane offset. `dx` is in
/// 2560-wide reference px and `dy` in 1440-ref px (the painter rescales both to
/// the live stage so they frame the same FRACTION at any size): positive `dy`
/// pushes content down (heads clear the seam), negative lifts it (the legwork
/// climax). These are *intent* values — the painter clamps the pan to what the
/// zoom can hide.
typedef Shot = ({double zoom, double dx, double dy});

/// Reference-px horizontal pan (per unit of zoom) that brings a side dancer from
/// its rest position to frame centre. Derived from the trio layout: a side cat
/// sits ~0.167·stageWidth from centre (`_trioSpacing·_trioScaleFactor`), so
/// fully centring it at zoom z needs `z · 0.167 · 2560 ≈ z · 428` reference px.
/// Feature shots use a small FRACTION of this so they lean the frame toward a cat
/// without slinging it lopsided or clipping the third (the composition panel
/// flagged full-amplitude pans as off-balance).
const double kSideCatCentreRef = 428;

/// Small vertical trim (1440-ref px) for the WIDE/calm framings only. With the
/// dance camera's pivot pinned at the feet, a push-in already plants the feet and
/// grows the cast up into the sky, so `dy` is no longer needed to keep feet in
/// frame — the dance shots ride `dy: 0`. This positive nudge just drops the
/// idle/outro wide a touch so the heads clear the waterline seam at z~1.06.
const double kHorizonDropPx = 8;

/// The climax legwork-hero's vertical lift, in 1440-ref px. NEGATIVE lifts the
/// content UP a touch so the lead fills the frame head-to-toe — the bent-knee
/// legwork (planted feet, the groove squat) dominates the lower-centre while the
/// head tops the frame, ears at the upper edge and the eyes still engaging the
/// lens. A shallow lift (paired with the deep ~2.30 zoom) keeps the cast SHADOW
/// and a deck sliver under the feet for ground contact instead of floating the
/// legs in dead foreground deck — the panel found a deeper lift over-raised the
/// cast and lost the floor. The painter rescales this against the live height, so
/// it frames the same fraction (~0.15 of the height) at any window size.
const double kHeroLegworkLiftRef = -220;

class DanceCameraContext {
  const DanceCameraContext({
    required this.section,
    required this.energetic,
    required this.build,
    required this.phrasePhase,
    required this.sectionPhase,
  });

  /// Section label (lower-case: intro/verse/pre-chorus/chorus/post-chorus/
  /// bridge/outro), or '' if unknown.
  final String section;

  /// Whether this section dances (camera performs) vs calm (wide establish).
  final bool energetic;

  /// Overall progress/intensity 0..1 — grows toward the end so the late choruses
  /// get the tightest treatment and the final money shot.
  final double build;

  /// Phase within the current 3-bar phrase, 0..1 — drives the gentle per-phrase
  /// breathe/drift that keeps a held home alive without parking dead-still.
  final double phrasePhase;

  /// Progress through the CURRENT section, 0..1 — drives the continuous moves (the
  /// pre-chorus push, the bridge hand-off swing, the chorus push, the outro
  /// de-escalation) that a per-phrase value would saw-tooth instead of build.
  final double sectionPhase;
}

/// Builds the context from the absolute (fractional) beat and the loop binding.
/// [sectionPhase] describes where we are inside the current lyric section and
/// must be supplied by the caller (which knows the section timeline); pass `0`
/// when unknown. The beat + loop length give the per-phrase phase.
DanceCameraContext cameraContext({
  required double beat,
  required double anchorBeat,
  required double loopLengthBeats,
  required String section,
  required bool energetic,
  required double build,
  double sectionPhase = 0,
}) {
  final rel = beat - anchorBeat;
  var phrase = loopLengthBeats > 0 ? (rel / loopLengthBeats) % 1.0 : 0.0;
  if (phrase < 0) phrase += 1.0;
  return DanceCameraContext(
    section: section,
    energetic: energetic,
    build: build.clamp(0.0, 1.0),
    phrasePhase: phrase,
    sectionPhase: sectionPhase.clamp(0.0, 1.0),
  );
}

const Shot _establish = (zoom: 1.06, dx: 0, dy: kHorizonDropPx);

/// Reference-px pan that leans the frame toward a side cat by [frac] of the way
/// to fully centring it at zoom [z]. Positive favours the LEFT (silver) backup,
/// negative the RIGHT (dark) backup. Homes lean gently (`frac` ~0.5, lead +
/// favoured backup symmetric about centre); the committed deep leans go further
/// (`frac` ~0.66) but PAIR a tighter zoom so the favoured pair fills and the
/// third cat clears the edge cleanly instead of hanging on as a sliver.
double _lean(double z, double frac, {required bool left}) =>
    (left ? 1.0 : -1.0) * frac * z * kSideCatCentreRef;

/// The director's shot for a frame.
Shot cameraShot(DanceCameraContext c) {
  // Calm parts: a composed wide establish with a slow breath, heads off the
  // seam. The backups-only intro/outro tails stay here too.
  if (!c.energetic) {
    final breathe = math.sin(c.phrasePhase * 2 * math.pi) * 0.02;
    return (zoom: _establish.zoom + breathe, dx: 0, dy: kHorizonDropPx);
  }

  switch (c.section) {
    case 'chorus':
    case 'post-chorus':
      return _chorusShot(c);
    case 'bridge':
      return _bridgeShot(c);
    case 'pre-chorus':
      return _preChorusShot(c);
    case 'outro':
      return _outroShot(c);
    default:
      return _verseShot(c);
  }
}

/// The reserved climax cut: the money legwork-hero's arrival. The demo's
/// `DanceCameraRig` snaps to the shot on the frame this is true and dollies
/// toward it otherwise, so the climax lands as a cut. Mirrors the
/// `sectionPhase > 0.93` hero gate in [_chorusShot]'s closing hook (and only
/// fires while energetic, so the calm establish is never cut to).
bool isHardCut(DanceCameraContext c) =>
    c.energetic &&
    c.section == 'post-chorus' &&
    c.build > 0.74 &&
    c.sectionPhase > 0.93;

/// The Afrobeats downbeat cut INTO a chorus: a hard cut on the "1" of each
/// refrain. The rig SNAPS to the chorus home instead of dollying into it, giving
/// the choruses the genre's punchy cut-on-the-drop while verses stay dollies.
/// Fires only on the opening beats of a chorus section; the director's chorus
/// target itself stays continuous — this just tells the rig to arrive by a cut
/// rather than a truck.
bool isChorusDrop(DanceCameraContext c) =>
    c.energetic && c.section == 'chorus' && c.sectionPhase < 0.03;

/// The bridge singer-feature cuts. The bridge is background-only — the lead is
/// SILENT while the two backups trade the vocal — so the camera follows the
/// VOICE: it CUTS onto the silver singer at the bridge's open and CUTS again to
/// the brown singer at the mid-bridge hand-off, instead of sliding the wide
/// three-shot between them (which spotlighted neither). The rig snaps on these
/// two frames; [_bridgeShot] holds a committed singer-feature two-shot between
/// them. Mirrors the two segment boundaries in [_bridgeShot] (open ~0, hand-off
/// ~0.5).
bool isBridgeCut(DanceCameraContext c) =>
    c.energetic &&
    c.section == 'bridge' &&
    (c.sectionPhase < 0.03 || (c.sectionPhase >= 0.5 && c.sectionPhase < 0.53));

/// Chorus / post-chorus: the hook. Each refrain owns a DISTINCT, STABLE home held
/// WIDE enough that the golden-hour vista and the legwork both breathe, and the
/// rig CUTS into it on the downbeat (the Afrobeats cut-on-the-"1"; see
/// [isChorusDrop]) while verses stay dollies:
///   - chorus 1 (build < 0.30): centred and the widest of the hooks;
///   - chorus 2 (0.30..0.62): a committed LEFT two-shot (silver backup);
///   - chorus 3 (build > 0.62): a committed RIGHT two-shot (dark backup);
///   - closing post-chorus (build > 0.74): a centred COIL that loads off-centre
///     (with one motivated mid-coil push so the long load breathes), then the
///     reserved climax CUT onto the money legwork-hero — the single tightest
///     framing in the piece, a low push that lifts the lead's legwork to centre.
/// The mid choruses are capped well under the climax, and the closing hook spends
/// NO 1.6+ register before the hero, so the cut to ~2.30 is a whole new framing
/// rather than the tallest point on a plateau. Side cats are favoured by a
/// committed PAN with the lead on a third-line.
Shot _chorusShot(DanceCameraContext c) {
  // CLOSING HOOK (final post-chorus): the single climax of the piece. A centred
  // coil (capped ~1.56) COILS tension, then a slow push ARRIVES on the money hero
  // — the ONE reserved framing (tightest sustained CENTRED hold). Every earlier
  // chorus and the coil sit lower, so this lands as the peak by contrast.
  if (c.section == 'post-chorus' && c.build > 0.74) {
    // MONEY LEGWORK-HERO: a hard CUT-IN — the ONE place the camera abandons the
    // wide groove for an intimate hero shot. Afrobeats peaks on the LEGS, so the
    // hero is a low push that fills the frame with the lead head-to-toe: the
    // bent-knee legwork (planted feet, the squat, the swinging low hands)
    // DOMINATES the lower-centre while the head tops the frame, ears at the upper
    // edge and the eyes still engaging — the footwork is the subject but the face
    // (this chibi cast's whole charm) is kept, and the cast shadow stays under the
    // feet for ground contact (a shallow [kHeroLegworkLiftRef] lift, not a deep
    // one). The coil holds flat at 1.56; then the zoom JUMPS straight to the
    // reserved ~2.30 register with NO intermediate value surviving on screen, so
    // it lands as a cut, not a push. Every earlier hook is capped ~1.61, so this
    // is a whole register the eye has not seen, and it flings the backups to
    // edge-SLIVERS so the lead DOMINATES.
    if (c.sectionPhase > 0.93) {
      return (zoom: 2.30, dx: 0, dy: kHeroLegworkLiftRef); // legwork money-shot
    }
    // COIL: the run-up. The zoom settles to the ~1.56 ceiling, with ONE motivated
    // mid-coil push (peaks ~1.61 around the middle, back to 1.56 by the cut) so
    // the long held-wide load breathes instead of flatlining for 14s. A WIDE
    // lateral sway visibly LOADS the frame off-centre; it is phrased to the beat
    // grid (phrasePhase) so it grooves WITH the bars, not on a section-length
    // clock. Spends no 1.6+ register before the cut, reserving the hero.
    final rise = (c.sectionPhase / 0.45).clamp(
      0.0,
      1.0,
    ); // settle in, then hold
    final midPush =
        0.05 * math.sin((math.min(c.sectionPhase, 0.9) / 0.9) * math.pi);
    final z = 1.50 + 0.06 * rise + midPush; // ~1.50 -> 1.56, bulging ~1.61 mid
    final sway = math.sin(c.phrasePhase * 2 * math.pi) * 0.34; // beat-phrased
    return (zoom: z, dx: sway * z * kSideCatCentreRef, dy: 0);
  }

  final breathe = math.sin(c.phrasePhase * 2 * math.pi) * 0.02;

  // FIRST CHORUS — the establish: centred and the WIDEST of the hooks, held wide
  // so the golden-hour Lagos vista breathes and the full legwork reads, with a
  // slow breathing push so the song has room to grow. ONE continuous home; the rig
  // CUTS into it on the downbeat (see [isChorusDrop]).
  if (c.build < 0.30) {
    final push = 0.05 * c.sectionPhase; // 1.40 -> 1.45 across the section
    return (zoom: 1.40 + push + breathe, dx: 0, dy: 0);
  }

  // THIRD CHORUS (late, pre-finale): its signature HOME is a committed RIGHT
  // two-shot favouring the dark backup — a different anchor from chorus 2. The rig
  // DOLLIES into it from the bridge/verse, so the commit reads as a deliberate
  // truck onto the dark singer, not a cut. One continuous home, gently pushing and
  // breathing, capped well under the hero.
  if (c.build > 0.62) {
    // Held wider than before (vista + legwork breathe); the right lean is a touch
    // shallower (0.38) so the bright yacht hull on this side doesn't pull focus
    // from the lead.
    final z = 1.44 + 0.05 * c.sectionPhase; // slow tighten across the section
    return (zoom: z + breathe, dx: _lean(z, 0.38, left: false), dy: 0);
  }

  // SECOND CHORUS: its signature HOME is a committed LEFT two-shot favouring the
  // silver backup — the mirror of chorus 3 and a distinct anchor, so the refrains
  // never read as one looped centred shot. Held wider than before so the vista and
  // legwork breathe; the rig CUTS into it on the downbeat ([isChorusDrop]).
  final z = 1.44 + 0.05 * c.sectionPhase;
  return (zoom: z + breathe, dx: _lean(z, 0.42, left: true), dy: 0);
}

/// Bridge (background-only): TWO committed singer-feature two-shots with a hard
/// CUT between them (see [isBridgeCut]). The lead is silent and the backups trade
/// the vocal, so the camera follows the VOICE — it spotlights the silver (left)
/// backup for the first half, then CUTS to the brown (right) backup for the
/// second, each a committed lean that weights the frame onto the singing cat with
/// the lead anchoring centre. Held to a deep-but-not-total lean (0.60) so the OFF
/// singer keeps a thin sliver rather than vanishing (the user flagged a cat fully
/// leaving frame as reading like a glitch), and a steady tight-ish zoom so each
/// feature actually fills. Peak under the 2.30 hero. Within each half the home is
/// constant — the rig holds it after the cut, so there is no per-bar pendulum,
/// just two clean held features.
Shot _bridgeShot(DanceCameraContext c) {
  final featuringLeft = c.sectionPhase < 0.5;
  const z = 1.60;
  return (zoom: z, dx: _lean(z, 0.60, left: featuringLeft), dy: 0);
}

/// Pre-chorus: a strictly monotonic crane-push, crest capped (~1.52) just under
/// the chorus drop so the downbeat punches above it for a felt jump (no reset).
Shot _preChorusShot(DanceCameraContext c) {
  final p = c.sectionPhase; // monotonic 0..1 across the pre-chorus
  return (zoom: 1.22 + 0.30 * p, dx: 0, dy: 0);
}

/// Outro: ease the energy down across the section so the piece settles into the
/// wide establish instead of cutting to it cold. Everything is continuous (the
/// sway returns to zero at each phrase boundary and decays to nothing), so the
/// rig glides the whole de-escalation as one long pull-back.
Shot _outroShot(DanceCameraContext c) {
  final p = c.sectionPhase; // 0..1
  final z = 1.48 - 0.38 * p; // 1.48 -> 1.10, toward the 1.06 establish
  final sway = math.sin(
    c.phrasePhase * 2 * math.pi,
  ); // smooth, 0 at phrase ends
  return (
    zoom: z,
    dx: sway * 70 * (1 - p), // gentle truck that fades out as it settles
    dy: kHorizonDropPx * p, // eases into the idle establish's wide trim
  );
}

/// Verses (and anything else energetic): the grounded pocket between hooks — but
/// a breather still BREATHES. A single slow continuous push across the whole
/// verse (1.36 -> 1.45) plus a gentle lateral drift, so it reads as a calm,
/// LIVING medium that contrasts the favouring two-shot choruses and the swinging
/// bridge — rather than a frozen centred three-shot parked for the section's
/// length (which read as the operator falling asleep).
Shot _verseShot(DanceCameraContext c) {
  final z = 1.36 + 0.09 * c.sectionPhase; // slow push across the section
  final drift = math.sin(c.phrasePhase * 2 * math.pi) * 0.06; // gentle sway
  return (zoom: z, dx: drift * z * kSideCatCentreRef, dy: 0);
}
