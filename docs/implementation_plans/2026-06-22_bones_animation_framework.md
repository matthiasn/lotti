# Bones (2D Skeletal) Animation Framework — Working Planning Document

**Status:** Planning CONVERGED after 2 panel rounds. Decisions locked (§5). Ready to build the film-strip POC. No code yet.
**Created:** 2026-06-22
**Owner:** main thread (synthesizing a panel of 4 experts)
**Process:** Multiple planning rounds → synthesize → recirculate for critique → build only after the gate → panel rates the built outcome.

---

## 1. Goal (as stated by the stakeholder)

Build a framework to animate 2D characters programmatically:

- **Input:** an SVG character (AI-generated — Claude / Nano Banana; "cat in a suit" energy).
- **Rigging:** Claude analyzes the SVG to infer a skeleton (bones, joints, hierarchy) **and a face rig** (mouth/eyes/brows) for expression/mimicry. The face is called out as *especially* important.
- **Animation:** procedural / mathematical (a little physics) — walk, run, sit, jump as code-defined, data-driven motion cycles; controllable expressions (smile/frown/blink).
- **First deliverable:** *film strips* — frame sequences of the character in each motion — to eyeball quality before committing to a runtime.
- **Hard constraint:** must run smoothly on **low-end devices, including old Android**. Non-negotiable; the primary design driver.
- **Product use case:** a Tamagotchi-style "living character" in Lotti whose mood reflects how well the user keeps up with tasks/habits; also a character that moves across the screen.

Stakeholder decision (2026-06-22): **runtime biased toward pure Dart + CustomPainter** (no Rive/Flame/Lottie). Authoring/rigging may be heavy & offline.

---

## 2. Round 1 — panel summary

Four independent expert plans (animation, low-end performance, vector/rigging, Flutter integration). Self-scores:

| Expert | Feasibility | Fidelity | Low-end perf |
|---|---|---|---|
| Animation | 8 | 6.5 | 9 |
| Performance | 9 | 6 | 9 |
| Vector / rigging | 8 | 6 | 9 |
| Flutter integration | 8 | 6 | 8 |

**The headline finding:** feasibility and low-end performance are already at/near the 8 gate. **Fidelity is the weak axis at ~6** and is what subsequent rounds must lift — *without* sacrificing the low-end-perf score. That tension (fidelity ↑ vs cheap-on-old-Android) is the central design problem.

### 2.1 Strong, independent convergence (treat as settled unless challenged)

1. **Two-layer split.** Heavy AI rigging + SVG parse + rasterization happen **offline / at load time**; the on-device player does only trivial math against cached data. Everyone agreed.
2. **Transform-only "cut-out" puppet, not 3D-style skinning.** Rigid body-part pieces rotated about pivots in a parent→child hierarchy. No per-vertex skinning on the default/low-end path.
3. **No runtime IK.** Canned cycles are authored as forward-kinematics keyframes; IK (if any) is an *offline authoring helper* baked into FK, plus possibly one 2-bone analytic foot-lock — never a runtime system on low-end.
4. **The SVG authoring contract is the make-or-break — more than the runtime code.** Do **not** auto-segment a flat AI-painted SVG. Force the generator to emit structured SVG (named groups per body part, explicit pivots, explicit z-order). Claude's job becomes "map well-named groups to a skeleton template + fill pivots," which is reliable, instead of CV-style segmentation, which is not. Two experts said this independently and forcefully.
5. **Face = hybrid: mouth shape-set swap + cheap transforms for eyes/brows.** No mesh morphing on low-end. ~8 scalar control "knobs"; emotions are named presets that blend across knobs. Mouth = 5–8 pre-drawn shapes (smile/frown/open/o/…), swapped (optionally 2-shape path-tween if topology matches). Blink = `scaleY` pulse on eyelids; look = pupil translate within a clip; brows = rotate + translateY.
6. **The "autonomic" layer is the soul of a Tamagotchi.** Always-on idle breathing, Poisson-timed blinks, micro eye-darts. A still rig with good autonomic micro-motion beats a busy rig with none. Budget for it explicitly.
7. **Data-driven cycles.** A cycle = a named bag of parameters. Cyclic motion (walk/run/idle) ≈ phase-shifted, amplitude-scaled sinusoids per joint (+ optional 2nd harmonic for snappy knees/elbows). One-shots (sit/jump) = small per-joint keyframe tracks with ease curves + springy follow-through. New cycle = new data, zero new code. Walk→run can be a single `gait` lerp between two param sets.
8. **One evaluator, two consumers.** The film-strip renderer and the live player share the exact bone-transform + face-resolve code, so strips are guaranteed to match runtime. Strips double as a CI regression artifact and as a baked-flipbook fallback for the weakest devices.

### 2.2 The key OPEN disagreement to resolve next: the runtime draw primitive

This is the one place the panel split, and it directly drives the fidelity-vs-perf tension.

- **Performance expert: `Canvas.drawAtlas` over rasterized part bitmaps (rigid sprite-per-bone).** All bone quads = ONE draw call against ONE pre-uploaded texture atlas. RSTransform (scale+rotate+translate) covers rigid bones. Cheapest thing a weak GPU does well; no per-frame path tessellation/AA. *Limitation:* RSTransform is uniform-scale rotate/translate only — **no shear / non-uniform scale**, so squash/stretch and skin deformation are out unless faked via extra atlas pieces. This caps fidelity but maximizes the low-end score.
- **Vector/rigging + Flutter experts: CustomPainter drawing vector `Path`s directly** (raster-atlas as an *option* via a `drawable.kind` discriminator). Keeps true vector scaling and allows non-uniform scale (fake squash/stretch), at the cost of per-frame path fill/AA — the exact thing the perf expert warns kills old GPUs.
- **Animation expert** sided with the perf concern: painting cost (not the math) is the real risk; recommended **cached-raster pieces + no `saveLayer`/blend modes**, and gating any mesh upgrade behind film-strip review.

**Resolution path for Round 2:** likely a tiered drawable model — `drawAtlas`/raster as the low-end default, vector-path or a single `drawVertices` mesh tier as an opt-in fidelity upgrade on capable devices, selected by the degradation ladder. The rig format already anticipates this with a `drawable.kind` discriminator. Round 2 must decide whether we build the vector/mesh tier at all for v1, or ship raster-only first.

---

## 3. Consolidated architecture (Round 1 draft — subject to critique)

### 3.1 Pipeline

```text
Generate SVG (AI, contract-conformant)
   → Validate (linter: required groups, unique ids, pivots, z, subset whitelist)
   → Normalize (bake transforms, resolve use/defs, enforce viewBox/units)
   → Extract parts (one drawable per named group + bbox + pivot)
   → Rig inference (Claude: parts → skeleton template, parents, pivots, face rig)
   → Emit RIG spec (declarative, serializable) [+ optional rasterized atlas]
   → [offline] Film-strip render (batch-evaluate cycles)  ──┐
   → [device]  Live player (same evaluator)               ──┘ shared evaluator
```

### 3.2 The RIG format (contract between offline rigging and the cheap player)

Declarative, versioned, serializable (pseudo-JSON; **not** Dart types). TRS-decomposed transforms relative to parent (rotation in degrees, separate scale x/y, translate) so keyframes interpolate intuitively and an LLM can author them as numbers.

- `bones[]`: `{ id, parent|null, pivot[x,y] (parent-local), rest{rot,sx,sy,tx,ty}, length?, z, drawable }`
- `drawable`: discriminated — `kind:"path"` (`d`, `fill`) **or** `kind:"raster"` (`atlas`, `rect`, `anchor`). This is what lets us pick the runtime primitive per tier.
- `face`: `{ anchor: <bone>, slots: { mouth: shapeset{neutral,smile,frown,open,...}, eye.L/R: transform+blink, brow.L/R: transform } }`
- `cycles{}`: named; `{ loop, fps, frames, tracks{boneId: {rot:[{t,v,ease}], ...}}, faceTracks{} }`. Sparse — only animated bones appear; rest hold rest pose.

### 3.3 SVG authoring contract (two tiers)

- **Tier A (strict, target):** every part group carries `data-parent`, `data-pivot="x,y"` (root space), `data-z`, `.L/.R` suffix on pairs, single fill/clip scope, only identity/translate group transforms (no baked rotation/skew), optional `data-symmetry`. Rigging becomes a parse, not an inference.
- **Tier B (relaxed fallback):** named groups only; Claude infers parents/pivots from the part-name vocabulary (`root, hips, torso, head, neck, arm_upper.L/R, arm_lower.L/R, hand.L/R, leg_upper.L/R, leg_lower.L/R, foot.L/R, tail_00..NN, ear.L/R`).
- **Tier C ("flat SVG, figure it out"): NOT supported.**
- A **linter gate** rejects/repairs non-conformant output and triggers regeneration.

### 3.4 On-device runtime (per-frame hot path — the only allowed work)

Precompute at rig-load: part atlas (if raster) uploaded once, per-bone static data (src rect, pivot, parent index, rest local transform, z), clips as `Float32List` keyframe tables, reusable scratch buffers.

Per frame: advance clock `t` → lerp clip keyframes → FK pass (parent→child compose, ~25 bones, emit TRS/RSTransform directly, no `Matrix4` alloc) → write into pre-allocated buffer → single `drawAtlas` (raster tier) or transformed `drawPath` set (vector tier).

**Forbidden per frame:** SVG parse, image decode/upload, path tessellation rebuild, `saveLayer`, blend modes / mask / image / color filters, widget rebuild, layout, any heap allocation. `isAntiAlias=false` + `FilterQuality.low` on the hot blits where possible.

Clock: a single `Ticker`; mutate a `ValueNotifier<double>`/`Listenable`; `CustomPainter(repaint: listenable)`; wrap in `RepaintBoundary`; never `setState` per frame. Gate the tick to every Nth vsync for 30/20fps tiers. Pause on background / off-screen; honor reduced-motion (static pose, no ticker) — reuse the existing animation/reduced-motion preference signal.

### 3.5 Degradation ladder (runtime-selected)

`Tier0` full rig @60 → `Tier1` reduced joints/simplified face @60 → `Tier2` reduced tick rate (30→20) → `Tier3` baked sprite-strip flipbook (the film-strip asset) → `Tier4` static pose.
Start tier from a coarse device signal (RAM class, cores, API level); then adapt from measured `FrameTiming` (`addTimingsCallback`, watch `rasterDuration`) with hysteresis + cooldown to avoid oscillation. Drop tiers on thermal/power-save.

### 3.6 Where it lives in the repo (integration)

- **New feature `lib/features/character/`** (engine is the reusable framework; the Tamagotchi product is a *separate* consumer, e.g. `lib/features/companion/`, that depends on `character/` but never the reverse — preserves the "no deps from new code to old / no back-deps" rule).
  - `model/` (freezed RigSpec, Pose, Clip — pure Dart), `engine/` (skeleton_solver FK, clip_evaluator, face_solver — pure Dart, no Flutter), `rigging/` (offline SVG→RigSpec; the only AI-layer consumer), `runtime/` (CustomPainter + ticker-driven demo surface), `state/` (Riverpod mood controller), `widgetbook/` (film strips), `README.md` (architecture-first + Mermaid `stateDiagram-v2` for clip lifecycle).
- **Rigging reuses the AI layer's public seams:** a new built-in Skill `Rig SVG Character` (`built_in_skills.dart`), new `SkillType.rigGeneration`, `requiredInputModalities: [image, text]`, `contextPolicy: none`. Send the SVG **rasterized to PNG** *and* the raw path text (vision models reason better over a render than over `d=` strings). Output = strict JSON RigSpec validated by `rig_spec_parser.dart`. **v1: run dev-only through the direct `triggerSkillProvider` path and parse in `rigging/` — no journal-persistence arm** (avoids polluting journal semantics; flagged for confirmation). Reuses provider routing, keys, profiles, thinking-mode, per-invocation model picker for free.
- **Design tokens:** colors via `context.designTokens`, resolved in the widget and passed into the painter as plain `Color`s (painter stays pure/testable). Canvas size & FPS are **behavioral engine constants, not visual tokens** (sidesteps "ask before new token" since DS has no sizing/motion group). Ask the design panel before any character-specific color.
- **Rollout:** feature flag `enableCharacterFlag` in `lib/utils/consts.dart` + flags page; engine compiles unconditionally, only product surfaces gate. CHANGELOG/metainfo entry only once user-visible (engine/tool-only first deliverable likely warrants none). l10n for any user-facing strings.

### 3.7 Testing strategy (per repo rules)

- Pure-Dart engine carries the value: `skeleton_solver_test` (exact world transforms for known skeletons), `clip_evaluator_test` (pose values at t=0/0.5/1, loop closure `pose(0)≈pose(1)`, joint-limit bounds across sampled t), `face_solver_test` (expression→deltas). `rig_spec_parser_test` with golden JSON fixtures (valid/malformed/missing-parent/cyclic) — **no live LLM**.
- Ticker/widget tests under `fakeAsync`, `tester.pump(duration)` not `pumpAndSettle`: assert frame N → expected pose, `paused` stops advance, reduced-motion renders static pose & creates no Ticker.
- Poses: film-strip *review* goldens via existing `test/test_utils/screenshot_harness.dart` first; CI pixel-goldens only if the panel wants a regression gate (repo has none today; they're cross-platform flaky).

### 3.8 The film-strip deliverable — what "good" looks like

- One strip per cycle (walk/run/sit/jump/idle) + dedicated **face strips per emotion** + a blink strip (face is the priority).
- Frame counts: loops = one full cycle, 12–24 frames, seamless (frame N+1 == frame 0); one-shots = 16–32 frames covering anticipation→settle with extremes landing on frames; face = neutral→target over 8–12 frames to show the *transition*.
- Layout: horizontal strip + contact-sheet with frame indices + an animated GIF/APNG per strip (a strip can't show timing).
- Quality rubric (squint test): silhouette readability at extremes; arcs curve not zigzag; no loop-seam pop; no foot skating; visible overlap/drag on tail/tie/ears; jump lands heavy (squash + dwell); face emotion nameable in <1s; no joint seam tearing at extreme angles (the #1 cut-out failure mode).

---

## 4. Top risks (merged)

1. **Joint seams / "cardboard puppet" tearing** at extreme rotations (cut-out's #1 failure). → Art authored with overlapping pieces & pivots hidden under the parent; cap rotation amplitudes; "cap discs" at shoulders/hips drawn on top via z.
2. **Stiffness.** → Lean on overlap/drag springs, body bob, and the always-on autonomic face/breath layer.
3. **Foot skating.** → Optional single 2-bone analytic foot-lock during the contact phase (closed-form, cheap), authored offline.
4. **Painting cost / overdraw on low-end (the real perf risk, not the math).** → Cached-raster pieces, single atlas (≤2048²), `drawAtlas` one-call, no `saveLayer`/filters, minimize part overlap, cap layer count (~15–30), `isAntiAlias=false` where viable. Measure `rasterDuration` on a real old Android in profile mode, on both Impeller and Skia.
5. **AI ignores the authoring contract** (missing pivots, fused parts, reordered z). → Hard linter gate + auto-repair + tight few-shot with a validated exemplar; regenerate on failure.
6. **AI rig quality** (bad pivots/hierarchy) → garbage motion regardless of runtime. → Human-correctable rig (it's just data); validate via film strips before trusting any auto-rig; bundle hand-verified sample rigs so the runtime never depends on live rigging.
7. **Tier oscillation** from naive adaptive selection. → Hysteresis + sustained-window thresholds + cooldown.
8. **Coupling creep / back-deps.** → `rigging/` touches only public AI seams; mood→task mapping stays in the separate consumer feature; engine imports only `dart:ui`/freezed.

---

## 5. Locked decisions (resolved 2026-06-22 by lead, stress-tested in Round 2)

- **D1 — Runtime primitive: hybrid raster, single path for v1.** Body bulk = ONE batched `Canvas.drawAtlas` (rigid bones, uniform scale+rotate+translate). Face quads + a few squash/stretch "hero" bones = individual `Canvas.transform`(pooled `Matrix4`) + `drawImageRect` (the non-uniform scale `drawAtlas` can't do). **No vector-path runtime, no `drawVertices` mesh in v1.** Mesh deferred until film strips prove it necessary.
- **D2 — Lift fidelity with cheap craft, not expensive tech:** hand-tuned reference cycle library; always-on autonomic layer (Poisson **asymmetric** blink, breathing + 1–2px hold drift, micro eye-darts with lid-follow); overlap/drag springs on secondary bones (tail/tie/ears); non-uniform squash/stretch on ≤4–5 hero parts only; 2-bone foot-lock IK **baked offline into FK keyframes** (no runtime solver); **+ smear/elongated frame on the fastest 1–2 frames of run/jump.**
- **D3 — Rigging is AI-assisted, NOT fully automatic (Round-2 reframe).** A new built-in Skill `Rig SVG Character` (`SkillType.rigGeneration`, modalities `[image, text]`, `contextPolicy none`) sends rasterized PNG + path text to a frontier vision model → strict JSON candidate rig (pivots as **normalized bbox fractions + per-pivot confidence**). Then: automated **gap-detection gauntlet** (pose every joint to ±max ROM, check seam alpha for tears/balloons) → **film strip flags bad joints** → **fast human pivot-correction UI** (drag handle + per-joint re-render, ~2–5 min/character). This correction loop is **first-class v1 scope**, not optional. Run dev-only; **bypass `triggerSkillProvider`'s profile-resolution preamble** and call `runRigGeneration` directly with a hand-built `AutomationResult` (cleaner; no throwaway journal entity). Add `AiResponseType.rigGeneration` so the exhaustive `toResponseType` switch at `consts.dart:147` compiles.
- **D4 — Testing:** deterministic unit assertions on pose math (exact transforms) + golden JSON rig fixtures (no live LLM) + human review-goldens via the existing harness. **No CI pixel-diff goldens** (cross-platform flaky; repo has none).
- **D5 — Bone budget (amended in Round 2):** ~20–25 body bones + **joint-patch/cap quads (elbow/knee/shoulder/hip)** + **2-part foot (heel+toe hinge)** + smear quads; ~6–8 *individually-transformed* quads max (push uniform face quads — brows/pupils/static mouth — into the atlas batch); mouth shape-set = 6 (neutral, smile-closed, smile-open, sad/frown, surprised-O, angry). No CPU skinning.
- **D6 — Color tokens:** none. Character colors are intrinsic to its SVG/atlas art (carried in the rig). Design tokens apply only to chrome around the character.
- **D7 — Locomotion:** in-place cycle + root translation, speed-matched to the walk cycle to avoid foot-skate. Pathfinding/obstacles deferred. 3/4-turn/facing-change = a second pre-authored part set, out of v1 unless requested.

---

## 6. Round-2 panel synthesis & amendments

Round 2 stress-tested the locked decisions. The decisions held; the panel added concrete amendments (now folded into §3–§5) and named the hard build requirements.

### 6.1 Hard build requirements (non-negotiable, or the scores don't hold)
- **Allocation-free hot path.** No `Matrix4`/`Offset`/list/closure allocation in `paint()` or the per-frame tick; pool & mutate. Verify via a 30s DevTools memory timeline: flat graph, **zero GC events** in steady state.
- **Ban `saveLayer`** and all blend/mask/image/color filters in the player. Blink = geometry `scaleY`, never an alpha layer.
- **`FilterQuality.low`** on every individual `drawImageRect`; `isAntiAlias=false` where viable.
- **Atlas authored from day one to include discrete blink + squash keyframes** so the T2 degradation tier can collapse the individual face/squash draws back into the pure `drawAtlas` batch.
- **Ticker lives in the widget `State`** (`SingleTickerProviderStateMixin` + `markNeedsPaint`/`AnimatedBuilder`), Riverpod supplies only low-frequency mood/pose targets. Never push a per-frame value through a provider (R3 60×/s rebuild trap). Dispose atlas `ui.Image` + controller in `dispose()`.
- **Atlas:** single page ≤2048² (old-Android GL limit), **bake high + scale down** (never upscale), **generate mipmaps** (~21MB RGBA+mips). Two pages only if forced (costs a draw call).
- **Mouth registration guaranteed at bake time:** pad every mouth-shape slice to the union bbox so the anchor sits at the identical pixel — swapping changes only the source rect, never the transform. Don't trust AI alignment.

### 6.2 Concrete outcome bar (what the built film strips must hit to score ≥8)
- **Perf:** named reference device (Pixel 3a / Moto G-class), measured on **both Impeller-Vulkan and Skia-GLES** (GLES is the one that counts on old SKUs), profile mode. p95 frame ≤16.6ms, p95 `rasterDuration` ≤8ms / p99 ≤12ms, <1% janky frames over 60s, and **holds after a 5-minute thermal soak**.
- **Fidelity rubric (animation expert's grading checklist):** asymmetric Poisson blink present even in holds; breathing + no frozen frames; eye-darts with lid-follow; anticipation + landing overshoot/settle; contact squash + toe-off (no paddle feet); **zero foot-skate**; tail/tie secondary drag readable in silhouette; ≥1 smear frame on fast actions; **no joint tear at elbow/knee/shoulder/hip** (caps working); no z-pops; masked pupils that don't clip the sclera; 6 distinct readable expressions (brows doing the work). Hard-fail: foot-skate, melting/scale-faked turns, robotic linear blink, visible elbow tear.

### 6.3 Final panel scores (Round 2, with locked decisions + amendments)

| Expert | Feasibility | Fidelity | Low-end perf |
|---|---|---|---|
| Animation | 8 | 8 (conditional on §6.1/6.2) | 8 |
| Performance | 8 | 8 | 8 (conditional on §6.1 guardrails) |
| Vector / rigging | 8 (conditional on human-correction loop being v1) | 8 | 9 |
| Flutter integration | 8.5 | 7.5 | 8 |

**Gate status:** Feasibility (8–8.5) and low-end performance (8–9) clear for all four. Fidelity is **7.5–8** — at the gate, with the lone 7.5 attributed to the *accepted* offline-bake resolution cap (a non-issue at journal scale) and `drawAtlas` being net-new in this repo. These remaining fidelity questions are **empirical, not planning** questions — answered by building the film strips, which is the stakeholder's requested first deliverable. **Further planning rounds have diminishing returns; the plan has converged.**

### 6.4 Biggest residual risks (carry into build)
1. **Pivot correctness** — auto-rig is ~70% right per joint; the **human-correction UI + gap-detection gauntlet must be built to the same standard as the auto-rigger**, or characters tear and pop. Fund it as first-class.
2. **Perf discipline** — the hybrid is cheap *only* with §6.1 guardrails; without them it passes on a fresh Pixel and dies at minute 4 on a Moto G.
3. **`drawAtlas` is net-new in this repo** (`knowledge_graph_poc` uses `drawImageRect` as the closest precedent) — budget time for the `RSTransform`/rect/color arrays + single-atlas `ui.Image` lifetime.
4. **Profile-resolution friction** in the dev-only rig run — resolved by D3's direct-call bypass; confirm the rig skill not riding the standard trigger UI is acceptable.

## 7. Build sequencing (next phase — POC first)

1. **Pure-Dart engine + rig format** (`model/`, `engine/`): RigSpec/Pose/Clip, FK solver, clip evaluator, face solver, autonomic layer. Fully unit-tested (D4), no Flutter.
2. **Hand-authored sample rig + atlas** (bypass AI initially): one cat-in-a-suit, baked atlas with blink/squash keyframes, to de-risk the runtime independently of rigging reliability.
3. **Film-strip render harness** under `flutter test` (`PictureRecorder.toImage` per the `knowledge_graph_poc` pattern) → emit walk/run/sit/jump + face/blink strips + GIF/APNG. **First reviewable deliverable.**
4. **CustomPainter runtime** (hybrid `drawAtlas` + per-part draws) + ticker-driven demo widget, behind `enableCharacterFlag`. Profile on the named low-end device.
5. **Rigging skill + gap-detection + human-correction UI** (the AI half) — only after the runtime + film strips prove the rig format.
6. Panel rates the built outcome against §6.2.

## 8. Exit criteria

Plan gate (now met, per §6.3): all four experts ≥8 on feasibility and low-end perf; fidelity at/near 8 with residual fidelity being empirical. After building, the same panel rates the *built* film strips against the §6.2 rubric; target ≥8/10 each, stretch 9.
