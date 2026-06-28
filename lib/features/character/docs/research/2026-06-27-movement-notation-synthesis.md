# Movement-notation & choreography-theory synthesis (2026-06-27)

Background for [CHAR-0001](../adr/CHAR-0001-dance-choreography-encoding-and-move-library.md).
Condensed from a fact-checked multi-source research pass (each finding survived
adversarial verification). Sources at the end.

## The converging architecture

All primary sources agree on one shape: **keep the per-bone keyframed clips, but
treat them as a notation-style score reshaped by a continuous Laban-Effort
parameter layer rather than played back as raw interpolation — and stop driving
the trio in lock-step.**

## Findings

1. **Notation as a multi-track score.** Labanotation's staff is per-body-part
   columns plus a dedicated **support/weight-shift** column. Maps onto a rig of
   per-bone tracks plus an explicit support track; a move is a time-bounded
   per-bone event span whose meaning is context-dependent (which foot bears
   weight). LabanDancer shows a written score can be the authoring source.

2. **Effort as continuous dials over the clips.** LMA Effort = Space / Weight /
   Time / Flow. EMOTE models each as a `-1..+1` continuum that modulates authored
   key poses instead of linearly interpolating them. → expose Weight/Time/Flow as
   dials that reshape the keyframed accents. (Effort **Space** is excluded as
   unreliable — keep Weight/Time/Flow.)

3. **Effort is computable from kinematics** (so it can be targeted): Weight ≈ peak
   kinetic energy at the extremities (a Strong accent = a velocity spike at the
   paws/tail/head, *not* a bigger displacement); Time ≈ peak joint acceleration
   (snap vs. sustain); Flow ≈ jerk; Space ≈ path/displacement ratio (the
   unreliable one). This gives test assertions: measure velocity/acceleration and
   check the intended quality appears.

4. **Dynamics via parameterized timing.** EMOTE's recipe: nonzero start velocity
   `v0` → anticipation wind-up (pull back before a Strong move); nonzero end
   velocity `v1` → overshoot for a Free move; an inflection point `tᵢ`
   (`0.5 + 0.4·max(strong,sudden) − 0.4·max(light,sustained)`) controls ease vs.
   snap. Rig-dimension-independent → ports to a 2D rig as an easing curve. This is
   the basis of `dynamicsCurve`.

5. **Follow-through / overlapping action.** Loosely-connected parts (tail, ears,
   arms, head-bob) keep moving after the driver stops — author per-bone lag. The
   chibi tail is the strongest follow-through element and has no analogue in the
   3D papers' joint sets, so it is free upside.

6. **Whole-body Shape.** Squash/stretch on a fixed-segment skeleton comes from
   coordinated torso/spine/clavicle/pelvis rotation; an arm-only gesture lacks
   weight. The groove must live in the body, not just the arms.

7. **Trio polyrhythm.** A single 12-pulse cycle divides simultaneously as 4×3,
   6×2, or a 3+2 hemiola (West-African cross-rhythm). Put each cat's weight-shift
   on a different grouping of the shared beat map so they interlock and only
   re-sync at the cycle top.

8. **Polycentric / gesture-on-beat.** Drive bone groups as independent concurrent
   phrases ("Selfpolification") and make each rhythmic accent a legible gesture
   ("Gestorhythmitization") rather than one global sway.

9. **Personality via Effort/Shape modulation.** PERFORM/Samadani overlay emotion
   on a *neutral* motion path by modulating it in Effort/Shape space rather than
   hand-keying each variant — so each cat's character is an Effort/Shape setting
   on shared neutral clips (cheap variety).

## Caveats

- Every cited precedent targets **3D** figures; 3D Shape descriptors
  (convex-hull volume / kinesphere) need re-mapping for a side-on 2D rig
  (volume → area; drop depth-plane terms).
- Effort/Shape inter-rater reliability is only weak-to-acceptable (~0.46–0.50) —
  fuzzy authoring dials, not precise measurement.
- **Taste boundary:** body amplitude is unbounded; only **faces** are capped (no
  over-acted/grimacing faces).

## Sources

EMOTE (Chi, Costa, Zhao, Badler — SIGGRAPH 2000); PERFORM (Durupinar et al. — ACM
TOG 2017); computational-LMA formulas (arXiv 2504.21166; arXiv 2006.06071 — note
it excludes Effort Space); LabanLab (HKUST-GZ) & LabanDancer; West-African
polyrhythm (SHS Web of Conferences, etltc2021_05001); Talawa Technique
(polycentric / Gestorhythmitization) + Gottschild Africanist-aesthetic
scholarship; the 12 animation principles (Thomas & Johnston, *The Illusion of
Life*).
