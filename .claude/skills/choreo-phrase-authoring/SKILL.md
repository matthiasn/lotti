---
name: choreo-phrase-authoring
description: "Author, restructure, or improve beat-addressed character dance choreography as reusable phrase/move data. Use when Codex needs to add Afrobeats moves, map choreography to beat/downbeat analysis, reduce robotic sync, add per-cat style variance, improve pocket/groove, label dance sections, or stop random key tweaking in favor of extensible DancePhrase/AfrobeatsMove data."
---

# Choreo Phrase Authoring

Use this when the problem is the dance, not just one bad numeric key. The goal is
to turn movement feedback into labelled, reusable choreography data.

## Read First

- `lib/features/character/README.md`
- `lib/features/character/docs/adr/CHAR-0001-dance-choreography-encoding-and-move-library.md`
- `lib/features/character/docs/research/2026-06-28-afrobeats-dance-moves.md`
- `lib/features/character/model/dance_phrase.dart`
- `lib/features/character/model/afrobeats_move.dart`
- `lib/features/character/samples/cat_in_suit.dart`

## Authoring Principles

- Choreography is data. Add or adjust `DancePhrase`, `AfrobeatsMove`,
  `DanceMoveSignature`, `DanceRoleStyle`, accents, supports, and IK arcs before
  scattering anonymous per-bone key tweaks.
- Label the move and the count. A future reviewer should be able to say "frame
  16 Buga hit" or "slot 2 backup Azonto answer" and find the data.
- Separate choreo from camera. Use static-camera review while building the move;
  re-enable camera only after the body motion works.
- Keep support physics plausible. Hip/root movement must match the feet; dancers
  should not drift forward/back in ways their legwork cannot support.
- Avoid clone sync. The cats can share a phrase, but style overlays should add
  bounded variance in timing, amplitude, expression, gaze, and role.
- Use dynamics, not only positions. `DanceDynamics` controls anticipation,
  snap/sustain, and overshoot; `microFrames`/`swingFrames` place motion in the
  pocket.
- Keep faces happy unless the user asks otherwise. For the current dance, skip
  sad/angry expression cycling.

## Workflow

1. **Define the music grid.** Use beat/downbeat data from `dance-track-prep`
   when available. Otherwise state the assumed BPM and phrase length.

2. **Choose the move vocabulary.** Pick named moves from the ADR/research notes
   or add a new `AfrobeatsMove` entry with:
   - name and origin/reference;
   - `feel` (`onBeat`, `offBeat`, `halfTime`);
   - featured region for camera decisions;
   - default `DanceDynamics`;
   - default sub-frame swing/pocket.

3. **Lay out the phrase.** Define slots/counts before touching bones. Decide
   which cat leads, answers, or supports in each slot.

4. **Author support and body first.** Root, hips, pelvis, chest, and support-foot
   spans sell the groove. Limbs decorate the weight transfer; they do not replace
   it.

5. **Add hands/feet as IK target arcs.** Prefer semantic arcs tied to torso,
   pelvis, or named cue frames over raw FK if the hand/foot is meant to hit a
   visible place.

6. **Add role variance.** Use `DanceRoleStyle` and target/joint/body accent
   overlays so backup cats differ without forking the whole routine.

7. **Render and review.** First use static camera. Then run
   `character-motion-review-panel`; if snaps are reported, run
   `temporal-animation-diff`.

## Targeted Checks

Run the model tests for choreo data you touched:

```bash
fvm flutter test test/features/character/model/dance_phrase_test.dart \
  test/features/character/model/afrobeats_move_test.dart \
  test/features/character/model/dance_dynamics_test.dart
```

For runtime motion regressions, add only the focused files needed:

```bash
fvm flutter test test/features/character/runtime/temporal_motion_analyzer_test.dart \
  test/features/character/runtime/dance_beat_alignment_test.dart
```

## Smell List

- The panel keeps saying "generic boy band": the move vocabulary is too vague or
  the hips/feet are not leading the groove.
- It feels robotic: every cat peaks on the same frames with the same amplitude.
- It feels snappy/jumpy: inspect dense temporal diffs before adding more keys.
- The upper body floats off the hips: root/hip/chest channels are fighting or
  support spans do not match visible footwork.
- Arms hide behind the belly: z-order, IK target depth, or silhouette staging is
  wrong; fix the path and draw order, not just amplitude.
- Camera hides the problem: disable camera movement while comparing frames.

## See Also

- `dance-track-prep` for song beat/downbeat and lyric timing data.
- `dance-lipsync` for real mouth-shape cue generation.
- `character-motion-review-panel` for scored expert feedback.
- `temporal-animation-diff` for frame-by-frame discontinuity analysis.
