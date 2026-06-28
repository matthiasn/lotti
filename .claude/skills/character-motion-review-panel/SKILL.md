---
name: character-motion-review-panel
description: "Run a grounded expert panel on character animation using real rendered frame strips, dense frame captures, or video stills. Use when motion looks robotic, lame, snappy, wobbly, drunk, physically impossible, off-beat, weakly choreographed, or when the user asks to convene a dance coach, animator, MoCap/biomechanics, cartoon animation, cinematography, or music-video expert panel for the cat dance/walk/kick."
---

# Character Motion Review Panel

Grounded review loop for animated character motion. This is for movement,
silhouette, staging, and performance quality, not generic UI review.

## Review Contract

- Review fresh pixels from the current code. Do not reuse old scores.
- Every panelist must base comments on rendered frames they actually inspect.
- Scope the prompt to the active clip. If the user says dance only, do not bring
  in walk, run, or kick.
- If judging choreography, prefer a static camera capture first. Add camera
  review only when the camera itself is in scope.
- Mention only artifacts present in the rendered material. Do not prime panelists
  with absent objects or old issues.
- Use grumpy scoring: `8` means good but polish remains, `9` means strong, `10`
  means production-grade and hard to improve.

## Capture First

Use the repo's deterministic render harnesses before convening the panel:

```bash
GRID_CLIPS=dance GRID_FRAMES=16 GRID_COLS=8 GRID_SCALE=0.75 GRID_LIVE=1 \
  fvm flutter test test/features/character/frame_grid_test.dart
```

For suspected snaps or jumps, use `temporal-animation-diff` before asking humans
to guess. Dense frame diffs should identify exact frame pairs and phases.

For scene/camera/backdrop judgement, render the actual production path rather
than a fallback or placeholder. Use `cinematic-render-panel` when the main
question is lighting, scenery, or camera frame quality rather than body motion.

## Default Expert Lenses

Use 4-6 reviewers. Pick the smallest set that covers the user's complaint:

- **Afrobeats dance coach:** groove authenticity, pocket, call-and-response,
  downbeat/offbeat feel, whether the move vocabulary reads as Afrobeats.
- **Character animator:** pose appeal, arcs, anticipation, overshoot,
  follow-through, silhouettes, head/hand readability.
- **MoCap/biomechanics analyst:** physical plausibility, support foot, hips vs
  legs, impossible side-to-side travel, weight transfer.
- **Cartoon performance director:** charm, exaggeration, squash/stretch,
  comedic timing, readable personality.
- **Music-video director/cinematographer:** camera, staging, ensemble spacing,
  whether the shot sells the performance.
- **Technical animation reviewer:** rig seams, ribbons/mesh artifacts, z-order,
  foot locks, discontinuities.

## Prompt Template

Give each reviewer the same artifact list and scope:

```text
Read these rendered frame strips/stills from the current code:
<paths>

Scope: judge <dance/walk/kick/camera/backdrop>. Ignore unrelated clips.
Return:
SCORE: single 0-10 number
TOP 3 BLOCKERS: ranked, evidence tied to a visible frame/phase
TOP 3 FIXES: concrete, implementable changes
ONE-LINE VERDICT: highest-leverage next move
```

For Afrobeats work, add:

```text
Judge whether this feels like a Lagos/Afrobeats music-video groove rather than
generic boy-band posing. Prioritize pocket, hips, footwork, call-and-response,
and relaxed confidence over big random arm gestures.
```

## After The Panel

1. Cluster repeated findings across reviewers.
2. Fix the highest-leverage body/choreo issue first, not a scattered set of
   cosmetic comments.
3. Re-render the same capture and re-rate. Scores are valid only for the pixels
   that were reviewed.
4. Add or adjust focused tests when a finding maps to a measurable invariant:
   bounded head displacement, no torso/hip detachment, no arm hiding behind the
   belly, no large adjacent-frame centroid jump, valid support-foot spans.

## See Also

- `choreo-phrase-authoring` when the issue is weak or unstructured dance data.
- `temporal-animation-diff` when the issue is snapping/jumps/discontinuity.
- `cinematic-render-panel` when the issue is scenery, lighting, or camera.
