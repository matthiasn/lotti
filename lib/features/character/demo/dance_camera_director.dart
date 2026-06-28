/// A small "virtual director" for the dance-to-track demo's camera. Instead of
/// looping one push-in move every phrase, it gives each song section its own
/// treatment, scheduled against the bar grid and the section's own progress:
///
/// - calm intro/outro: a wide establish with a slow breathe;
/// - pre-chorus: a strictly monotonic crane-push that builds tension into the drop;
/// - verse: a grounded, centred medium with a slow continuous push and gentle
///   drift — the calm pocket that contrasts the favouring choruses and the
///   swinging bridge, alive rather than frozen;
/// - chorus: each refrain owns a DISTINCT home so they never loop — the first
///   chorus establishes wide and centred, the second lives on a committed LEFT
///   two-shot (silver backup), the third on a committed RIGHT two-shot (dark
///   backup), escalating in scale and all capped well under the climax;
/// - bridge (background-only): ONE slow swing that hands the frame from the silver
///   backup to the brown one, never a per-bar pendulum;
/// - post-chorus (closing hook): the climax — a centred COIL that visibly LOADS
///   off-centre a clear band under the peak, then a hard CUT onto the reserved
///   money hero: an intimate, knee-up CENTRED close-up on the lead, the single
///   tightest framing in the whole piece (the one beat that crops the dead sky
///   and flings the backups to edge-slivers);
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
/// centred by the painter — stays the readable star. The dance shots therefore
/// ride `dy: 0`; only the calm idle/outro wides carry a small positive `dy` trim
/// to drop their heads off the waterline seam at establish zoom. The reserved
/// money hero also rides `dy: 0` — at its ~2.1 zoom the feet-pivot alone lifts the
/// head to the top and crops the dead sky, so no vertical trim is needed.
///
/// Pure and deterministic so it is unit-testable and renders identically offline
/// and live. The output `(zoom, dx, dy)` is fed to
/// `CharacterPainter.cameraOverride`; a jump between frames reads as a hard cut,
/// a smoothly-moving value as a continuous move.
library;

import 'dart:math' as math;

/// One framing: zoom about the frame centre plus a pan/crane offset. `dx` is in
/// 2560-wide reference px (the painter rescales it to the live stage width, so it
/// pans the same FRACTION at any size); `dy` is raw px (positive pushes content
/// down, lowering the framing so heads clear the seam). These are *intent*
/// values — the painter clamps the pan to what the zoom can hide.
typedef Shot = ({double zoom, double dx, double dy});

/// Reference-px horizontal pan (per unit of zoom) that brings a side dancer from
/// its rest position to frame centre. Derived from the trio layout: a side cat
/// sits ~0.167·stageWidth from centre (`_trioSpacing·_trioScaleFactor`), so
/// fully centring it at zoom z needs `z · 0.167 · 2560 ≈ z · 428` reference px.
/// Feature shots use a small FRACTION of this so they lean the frame toward a cat
/// without slinging it lopsided or clipping the third (the composition panel
/// flagged full-amplitude pans as off-balance).
const double kSideCatCentreRef = 428;

/// Small vertical trim (px) for the WIDE/calm framings only. With the dance
/// camera's pivot pinned at the feet, a push-in already plants the feet and
/// grows the cast up into the sky, so `dy` is no longer needed to keep feet in
/// frame — the dance shots ride `dy: 0`. This positive nudge just drops the
/// idle/outro wide a touch so the heads clear the waterline seam at z~1.06.
const double kHorizonDropPx = 8;

class DanceCameraContext {
  const DanceCameraContext({
    required this.section,
    required this.energetic,
    required this.build,
    required this.phrasePhase,
    required this.sectionPhase,
    required this.barIndex,
    required this.sectionBar,
    required this.beatInBar,
    required this.beatFraction,
  });

  /// Section label (lower-case: intro/verse/pre-chorus/chorus/post-chorus/
  /// bridge/outro), or '' if unknown.
  final String section;

  /// Whether this section dances (camera performs) vs calm (wide establish).
  final bool energetic;

  /// Overall progress/intensity 0..1 — grows toward the end so the late choruses
  /// get the tightest, slowest-to-release treatment and the final money shot.
  final double build;

  /// Phase within the current 3-bar phrase, 0..1.
  final double phrasePhase;

  /// Progress through the CURRENT section, 0..1 — drives monotonic moves (the
  /// pre-chorus push, the bridge hand-off swing, the outro de-escalation) that a
  /// per-phrase value would saw-tooth instead of build.
  final double sectionPhase;

  /// Monotonic bar count from the loop anchor — the global cut clock.
  final int barIndex;

  /// Bar index WITHIN the current section (0 = the section's downbeat) — so the
  /// chorus cut cycle aligns its hero punch to the start of each chorus.
  final int sectionBar;

  /// Beat within the bar (0 = downbeat).
  final int beatInBar;

  /// Fraction through the current beat, 0..1 (for downbeat punches).
  final double beatFraction;
}

/// Builds the context from the absolute (fractional) beat and the loop binding.
/// [sectionPhase] and [sectionBar] describe where we are inside the current
/// lyric section and must be supplied by the caller (which knows the section
/// timeline); pass `0` for both when unknown.
DanceCameraContext cameraContext({
  required double beat,
  required double anchorBeat,
  required double loopLengthBeats,
  required int beatsPerBar,
  required String section,
  required bool energetic,
  required double build,
  double sectionPhase = 0,
  int sectionBar = 0,
}) {
  final rel = beat - anchorBeat;
  var phrase = loopLengthBeats > 0 ? (rel / loopLengthBeats) % 1.0 : 0.0;
  if (phrase < 0) phrase += 1.0;
  final relFloor = rel.floor();
  return DanceCameraContext(
    section: section,
    energetic: energetic,
    build: build.clamp(0.0, 1.0),
    phrasePhase: phrase,
    sectionPhase: sectionPhase.clamp(0.0, 1.0),
    barIndex: (rel / beatsPerBar).floor(),
    sectionBar: sectionBar < 0 ? 0 : sectionBar,
    beatInBar: beatsPerBar > 0
        ? (relFloor % beatsPerBar + beatsPerBar) % beatsPerBar
        : 0,
    beatFraction: rel - relFloor,
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

/// Chorus / post-chorus: the hook. The feet-planted camera pivot lets the hook
/// push in HARD (the lead reads as a real close-up) while feet, shadows and low
/// hand-swings stay in frame. Crucially each refrain owns a DISTINCT home so the
/// choruses never read as one looped centred shot, and the tightest sustained
/// CENTRED hero is RESERVED for the closing hook alone:
///   - chorus 1 (build < 0.30): establishes wide and centred, longer holds;
///   - chorus 2 (0.30..0.62): home is a committed LEFT two-shot (silver backup);
///   - chorus 3 (build > 0.62): home is a committed RIGHT two-shot (dark backup);
///   - closing post-chorus (build > 0.74): a centred COIL that loads off-centre
///     well under the peak, then a hard CUT onto the money hero — the single
///     tightest framing in the piece, an intimate knee-up close-up on the lead.
/// The mid choruses are capped ~1.60 (chorus 2's lean sits just under chorus 3's),
/// and the closing hook spends NO 1.6+ framing before the hero, so the money cut
/// to ~2.10 is a whole new register rather than the tallest point on a plateau.
/// Side cats are favoured by a committed PAN with the lead on a third-line.
Shot _chorusShot(DanceCameraContext c) {
  // CLOSING HOOK (final post-chorus): the single climax of the piece. A centred
  // coil (capped ~1.56) COILS tension, then a slow push ARRIVES on the money hero
  // — the ONE reserved framing (tightest sustained CENTRED hold). Every earlier
  // chorus and the coil sit lower, so this lands as the peak by contrast.
  if (c.section == 'post-chorus' && c.build > 0.74) {
    // MONEY HERO: a hard CUT-IN — the ONE place the camera abandons the
    // feet-planted full-figure read for an intimate KNEE-UP close-up on the lead.
    // The coil holds flat at 1.56; then at the threshold the zoom JUMPS straight
    // to the reserved ~2.10 register with NO intermediate value surviving on
    // screen, so it lands as a cut (a punctuation mark), not a fast push. Every
    // earlier hook is capped ~1.60, so this is a whole register the eye has not
    // seen; at that scale the feet-pivot alone lifts the head to the top (dead
    // sky cropped, feet to a knee-up) and flings the backups to edge-SLIVERS so
    // the lead DOMINATES. And because the coil ends LOADED off-centre, the jump
    // to a dead-centred frame makes the arrival a scale AND a re-centring event.
    // `dy` stays 0: at this zoom the feet-pivot already crops the sky.
    if (c.sectionPhase > 0.93) {
      return (zoom: 2.10, dx: 0, dy: 0); // hard cut to the reserved register
    }
    // COIL: the run-up. The zoom settles to the 1.56 ceiling early then HOLDS
    // flat (spends NO zoom before the cut — that is what reserves the register),
    // while a WIDE, slow lateral sway visibly LOADS the frame off-centre, ending
    // loaded just before the cut — so the wind-up reads as tension and the cut
    // releases it. Deliberately NO committed two-shots: spending the 1.6+ band
    // here is what flattened the old climax into a plateau the hero couldn't top.
    final rise = (c.sectionPhase / 0.45).clamp(
      0.0,
      1.0,
    ); // settle in, then hold
    final z = 1.50 + 0.06 * rise; // 1.50 -> 1.56, flat for the coil tail
    final sway = math.sin(c.sectionPhase * 4 * math.pi) * 0.34; // wide, loading
    return (zoom: z, dx: sway * z * kSideCatCentreRef, dy: 0);
  }

  // FIRST CHORUS — establish: centred and the WIDEST of the hooks, longer holds
  // and a real breath, capped well under the climax so the song has room to grow.
  if (c.build < 0.30) {
    final breathe = math.sin(c.phrasePhase * 2 * math.pi) * 0.02;
    switch (c.sectionBar % 6) {
      case 0:
      case 1:
        return (zoom: 1.50 + breathe, dx: 0, dy: 0); // hero, held two bars
      case 2:
      case 3:
        return (zoom: 1.40 + breathe, dx: 0, dy: 0); // wide breath, two bars
      case 4:
        return (zoom: 1.52, dx: _lean(1.52, 0.44, left: true), dy: 0); // lean
      default:
        return (zoom: 1.54 + breathe, dx: 0, dy: 0); // hero accent
    }
  }

  // THIRD CHORUS (late, pre-finale): its signature HOME is a committed RIGHT
  // two-shot favouring the dark backup — a different anchor from chorus 2, so the
  // refrains never read as the same looped centred shot.
  if (c.build > 0.62) {
    // The bridge ends its swing LEANING RIGHT (handed onto the dark backup), and
    // chorus 3's home is ALSO a right two-shot — so open on a centred downbeat
    // punch to RESET the contrast before settling into the right home, else the
    // refrain's "commit" is blunted because the frame was already there.
    if (c.sectionBar == 0) return (zoom: 1.54, dx: 0, dy: 0);
    final breathe = math.sin(c.phrasePhase * 2 * math.pi) * 0.02;
    switch (c.sectionBar % 4) {
      case 1: // momentary punch back to a centred lead accent
        return (zoom: 1.54, dx: 0, dy: 0);
      case 3: // deepen the favouring lean: a tighter zoom MARRIED to the pan so the
        // dark backup + lead FILL the frame (the trio's wide spacing means the
        // third cat reads as a half-figure exiting the edge, not a clean cut-out).
        // Capped ~1.60 — the deepest pre-hero zoom, leaving the 1.92 hero a clear
        // register of its own.
        return (zoom: 1.60, dx: _lean(1.60, 0.60, left: false), dy: 0);
      default: // HOME: sustained right two-shot, gently breathing so it never parks
        return (
          zoom: 1.53 + breathe,
          dx: _lean(1.53, 0.50, left: false),
          dy: 0,
        );
    }
  }

  // SECOND CHORUS: its signature HOME is a committed LEFT two-shot favouring the
  // silver backup — distinct from chorus 3, with a centred downbeat punch and one
  // brief wide release for internal dynamics.
  final breathe = math.sin(c.phrasePhase * 2 * math.pi) * 0.02;
  switch (c.sectionBar % 6) {
    case 0: // drop / downbeat — a momentary centred lead accent
      return (zoom: 1.54, dx: 0, dy: 0);
    case 3: // deepen the favouring lean: a tighter zoom MARRIED to the pan so the
      // silver backup + lead FILL the frame (held a touch under chorus 3's lean,
      // both capped well under the 1.92 hero)
      return (zoom: 1.58, dx: _lean(1.58, 0.60, left: true), dy: 0);
    case 4: // brief wide release, floored at chorus energy (not idle width)
      return (zoom: 1.42, dx: 0, dy: 0);
    default: // HOME: sustained left two-shot, gently breathing so it never parks
      return (zoom: 1.52 + breathe, dx: _lean(1.52, 0.50, left: true), dy: 0);
  }
}

/// Bridge (background-only): one slow swing that hands the frame from the silver
/// backup, through a looser centred pass, to the brown backup across the whole
/// section — a continuous move so the hand-off reads, never a per-bar pendulum.
/// Zoom is married to the lean depth (tightest at the held extremes, looser
/// mid-pass), so the featured backup actually weights and FILLS the two-shot at
/// each end rather than the wide three-shot sliding sideways. Peak under the hero.
Shot _bridgeShot(DanceCameraContext c) {
  final p = c.sectionPhase;
  final swing = math.cos(p * math.pi); // +1 (left) at 0 -> -1 (right) at 1
  // Marry zoom to the lean DEPTH, not the section middle: tightest at the held
  // extremes (|swing|→1) where a backup actually fills the two-shot, looser
  // through the centred hand-off pass (swing→0) — so a deep pan never reads as
  // the wide three-shot just sliding sideways. The pan is DEEP here (0.75 of a
  // full side-cat centring) so at each extreme the featured background singer is
  // pulled well toward centre and the lead is pushed off-axis toward the far
  // edge — re-staging the shot around whoever carries the vocal, not just sliding
  // the world past a parked lead. Peak ~1.60, still well under the 2.10 hero.
  final z = 1.50 + 0.10 * swing.abs();
  return (zoom: z, dx: swing * 0.75 * z * kSideCatCentreRef, dy: 0);
}

/// Pre-chorus: a strictly monotonic crane-push, crest capped (~1.52) just under
/// the chorus drop so the downbeat punches above it for a felt jump (no reset).
Shot _preChorusShot(DanceCameraContext c) {
  final p = c.sectionPhase; // monotonic 0..1 across the pre-chorus
  return (zoom: 1.22 + 0.30 * p, dx: 0, dy: 0);
}

/// Outro: step the energy down across the section so the piece settles into the
/// wide establish instead of cutting to it cold.
Shot _outroShot(DanceCameraContext c) {
  final p = c.sectionPhase; // 0..1
  final z = 1.48 - 0.38 * p; // 1.48 -> 1.10, toward the 1.06 establish
  final dir = (c.barIndex ~/ 3).isEven ? 1.0 : -1.0;
  final sway = (c.phrasePhase - 0.5) * 2;
  return (
    zoom: z,
    dx: dir * sway * 90 * (1 - p), // truck fades out as it settles
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
