# Project plaza — design for a usable walkable space

Companion to [HANDOVER.md](HANDOVER.md), which describes what exists (M0)
and why it is not usable. This document answers: **what would it take to
make the plaza a usable, appealing, cognitively useful walkable space?** It
is a proposal, written 2026-09-03, to be argued with; the milestones at the
end are sized so each one is demonstrable in the existing dev harness.

Design decisions here are driven by two hard facts from M0:

1. **Nothing ever moves.** Placement is a pure function of merged task data
   (`createdAt`, `id`, week bucket). Every idea below is an *overlay* on
   that layout or an extension that is itself a pure function of bucket
   index and project id. If a feature needs a building to move, it is wrong.
2. **Capture is the only cost.** Hosting hundreds of widget subtrees is
   free; rendering one to a texture costs ~0.6 ms per frame on weak hardware.
   So: live widgets only where the user is looking, captured widgets that
   re-capture only on change, and everything at a distance is geometry and
   colour.

---

## 1. Principles

- **Three ranges, three questions.** Every design element answers exactly
  one of: *How is the project?* (skyline range, > 140 m), *What is over
  there?* (street range, 35–140 m), *What do I do with this?* (shopfront
  range, < 35 m). If an element does not read at its range, it is noise.
- **The world is opinionated about where you look.** Free walking exists,
  but the default way to move is a beacon: a visible point that flies you to
  a curated pose. Walking is for the last twenty metres.
- **Never cut, never lose the horizon.** Every camera change is an animated
  flight with the horizon level; the user can always tell which way is
  "newer" and where "home" is.
- **Attention is earned.** Only what deviates from the expected pattern gets
  a billboard, a lantern or a beacon. A healthy project is quiet.
- **Height means importance, not verbosity.** M0 sizes buildings by content;
  the design sizes them by weight (priority, estimate, links) and moves
  content into the facade layout instead.
- **Same place, every device.** Everything the layout does must be
  reproducible from synced data alone, which the existing property tests
  already enforce for the street and must enforce for districts and beacons.

## 2. Navigation model

Three ways to move, one camera, no cuts.

```mermaid
stateDiagram-v2
  [*] --> Walking: spawn at Home beacon
  Walking --> Flying: click beacon / click facade / key to next beacon
  Flying --> Walking: arrival (or any movement input cancels, camera stays where it is)
  Walking --> Overview: M key / overview button / pinch out
  Overview --> Flying: click a block or beacon on the map
  Overview --> Walking: M key again (flies back down to the last ground pose)
  Flying --> Overview: flight target is an overview pose
  Walking --> Walking: WASD / touch joystick / drag look
  Walking --> Shopfront: within 12 m of a facade, facing it
  Shopfront --> Walking: step back / Esc
  Shopfront --> Flying: Back (reverse flight)
```

### 2.1 Walking

Keep the M0 walk camera, with four fixes:

- **Collision with buildings and street edges.** You cannot walk through a
  facade; the walker slides along walls. Removes the disorientation of
  ending up inside a box.
- **Eye height 2.2 m, not 5 m.** Facades become taller and content sits at
  eye level (section 4.3), so the camera no longer needs to float.
- **Auto-align.** Standing still for a moment near a facade gently yaws the
  camera to face it square-on, which makes the live widget usable without
  pixel-precise mouse work.
- **Touch.** Left-thumb virtual joystick to walk, right-thumb drag to look,
  tap to select, pinch to overview. Same controller, second input source.

### 2.2 Beacons (teleport points)

A beacon is a **curated pose**, not a location: a camera position, yaw,
pitch, and an optional focus building. Beacons render as small glowing
dots with a fixed *screen-space* size, so they are equally visible from
across the district and from up close, and through buildings at reduced
opacity. Hovering one shows its label.

Beacon kinds, all deterministic:

| Kind | Placed where | Why it exists |
|---|---|---|
| **Home** | The frontier plaza (section 3.2), facing the newest block | The morning starting point; `H` or the compass tap always flies here |
| **Block** | The middle of each week's road segment, looking down the block | The unit of "I remember this place"; there is one per built week, so the street has a rhythm of stops |
| **Corner** | Each district fold (section 3.1), looking along the new heading | Removes "what is round the bend" |
| **Overview** | Above the district centroid, pitched down 55° | The map, reachable by flight, not by a separate mode |
| **Attention** | 12 m in front of each anomalous building (section 4.4) | The thing that needs you, one flight away |
| **Task** | 12 m in front of any facade, created on demand when you click a facade or search for a task | Search result, link target, "open in plaza" from the task page |

Home, Block, Corner and Overview beacons are pure functions of the
`StreetPlan`; Attention beacons are pure functions of task data plus the
attention score; Task beacons are transient. None of them affects the
layout: they are overlays.

### 2.3 Flights

A flight is the only way the camera moves other than walking:

- **Path.** A cubic Hermite curve from the current pose to the beacon pose.
  Tangents point along the road at each end so flights leave and arrive
  "along the street", not through walls. Flights longer than 120 m rise to
  a cruise height proportional to distance (an arc), which keeps the
  destination and the route legible and reads as pleasing on its own.
- **Timing.** 0.8 s minimum, 2.5 s maximum, ease-in-out, duration grows
  with the square root of distance so far flights feel fast but not
  teleport-instant.
- **Orientation.** Yaw and pitch interpolate on the short arc; roll is
  always zero (horizon level). The camera looks at where it is going for
  the middle 60 % of the flight and settles to the beacon's pose in the last
  20 %.
- **Interruptible.** Any movement input cancels the flight in place, and
  the user is walking from wherever they are. No forced sequences.
- **Back.** Every flight pushes the departure pose; `Backspace`/back
  gesture flies the reverse. The stack is the breadcrumb trail.
- **LOD during flight.** No promotions to live during a flight; the
  destination's focus building is pre-captured at mid tier when the flight
  starts and promoted to live on arrival. This is what removes the promotion
  hitch on weak hardware.

### 2.4 Overview is a pose, not a mode

M0's overhead is a separate blend 90 m over the walker's head. In the
design, overview is simply the Overview beacon: a flight up to a fixed pose
over the district, from which the whole district reads as a skyline map
(section 4.1). Blocks and beacons are clickable from there, and clicking one
flies down. That coexists with walking without disorientation because the
same camera, the same horizon rule and the same Back stack apply.

### 2.5 Keyboard and search

- `Tab` / `Shift-Tab`: fly to the next / previous beacon along the street.
- `H` Home, `M` Overview, `Backspace` Back, `Esc` leave shopfront.
- `/` opens search: type a title, pick a result, fly to its Task beacon.
  Search is the escape hatch that makes a 300-building district navigable
  on day one, before spatial memory has formed.

## 3. Scene organisation beyond one street

### 3.1 Folding the street into a district

The 300-task preset is a 4 km line. The fix keeps the street exactly as it
is (same buckets, same plots, same ordering) and folds it: instead of a
seeded random bend, **every 6th bucket boundary turns 90°**, alternating
left and right, so the street snakes into a compact rectangle. The fold is
a pure function of bucket index, so it is as stable as the bends it
replaces, and it gives every district the same readable shape: rows of
blocks, newest row at the front.

```
            oldest                         (district, from above)
   ┌──────────────────────────┐
   │ b0  b1  b2  b3  b4  b5 → │   row 0, heading +X
   └──────────────────────┐ ↓ │
   │ ← b11 b10 b9  b8  b7  b6 │   row 1, heading −X
   │ ↓ ┌──────────────────────┘
   │ b12 b13 b14 b15 b16 b17 →│   row 2
   └──────────────────────┐ ↓ │
   ...
   │ ← b35 b34 b33 b32 b31 b30│   row 5
   │ ↓                        │
   ╔══════════════════════════╗
   ║      FRONTIER PLAZA      ║   the "now" square: billboards, Home beacon
   ╚══════════════════════════╝
            newest
```

Six buckets per row at 46 m each is a ~280 m row; the 300-task district is
16 rows deep, roughly 280 × 320 m, which fits in one overview pose.
Corner beacons sit at each fold. Empty weeks still collapse to gaps, so a
project with a quiet quarter has a visibly short row.

Small projects stay a lane: the waddle world is 276 m of straight street
and does not fold. The rule is the same; it just never reaches a fold.

### 3.2 The frontier plaza (Times Square)

The end of the newest bucket opens into a **plaza**: a square as wide as
three rows, with the Home beacon at its centre. Around it stand the
**billboards**: enlarged, elevated facades for the tasks that currently
deserve attention (section 4.4), mounted on the plaza-facing walls of the
newest blocks and on free-standing pylons at the plaza edge. The plaza is
where you land in the morning; the billboards are the headlines; the street
behind them is the history.

Billboards never move buildings. A billboard is an additional facade
surface (mid tier, captured) on a pylon whose slot is a pure function of the
attention rank, so the top-ranked task is always on the same pylon. When
the attention set changes, the *content* of the pylons changes, the pylons
do not.

### 3.3 Districts and the world

A **project** is a district. Multiple projects live on a **world grid**:
each project id hashes to a cell on a spiral around the origin (stable, no
collisions by construction: the spiral index is the rank of the project id
hash among all known project ids, which only changes when a project is
added or removed, and a new project is always appended at the end of the
spiral). Districts are separated by wide, dark boulevards and connected by
Overview beacons, so the world reads as a city of named districts from the
world overview pose.

The **goals map** is the same machinery with a different projection:
each goal is a district, its tasks are the buildings, and the world overview
is the map. A goal without tasks is a plaza with a single billboard (the
goal statement). Health at world scale is the skyline of each district
(section 4.1).

### 3.4 The morning walk

A **playlist** of beacons, generated deterministically every morning:

1. World overview (5 s hold): the skyline of every district.
2. For each district in attention order: its Overview beacon (3 s), then
   its top Attention beacons (3 s each, at most three per district).
3. Home beacon of the district with the most in-progress work.

The walk is a sequence of flights; the user can pause at any stop, interact
with the live facade, and resume (`Space`). Total length is capped at
~90 s. This is the ritual the vision describes: not a report, a place you
visit.

## 4. Information design at distance

### 4.1 Skyline range (> 140 m, and the overview pose)

What must read: **health**, **activity**, **anomalies**. Only geometry,
colour and light are available.

- **Roof lanterns.** Every building carries a small emissive lantern on its
  roof, coloured by state: done = off (dark), open = dim warm white, in
  progress = blue, blocked = red, overdue = amber, cancelled = off. Lanterns
  are screen-space-clamped so they never shrink below ~4 px; from the
  overview pose a district is a field of dots and the ratio of lit to dark
  is the health, with red and amber standing out by contrast. This is the
  "everything green is healthy" glance, done with light on a dusk scene
  rather than green paint.
- **Wall tint by category** stays as in M0, dimmed further so it never
  competes with lanterns.
- **Height by weight.** Building height is priority × log(estimate + links
  + open items), capped at 14 m; a tall dark building is a heavy task nobody
  has touched, a tall blue one is heavy and active. Content no longer sets
  height; the facade layout adapts to the wall instead (section 4.3).
- **Sky and fog.** A dusk gradient sky and distance fog matched to the
  ground colour: silhouettes read, far rows fade, and the district has depth
  instead of floating boxes on black. Both are cheap (a skybox quad and a
  fog term in the unlit material).
- **Block markers.** A low, wide plate on the road at every bucket start
  carries the week label as a captured texture (`W12 · 23 Mar`) readable
  from the overview pose, which gives the map a time axis.

### 4.2 Street range (35–140 m)

What must read: **which building is which**, and **what state it is in**.
The M0 facade is unreadable here; the design adds a **sign** variant.

- **Sign facade.** A captured (mid tier) surface with three elements only:
  title at 120 px on a 1000 px wide texture (two lines max, ellipsised),
  the state chip, and the category bar. No cover, no checklist. Legible at
  100 m on a 12 m wide wall.
- **Progress as a light bar** along the building's base, not a fill behind
  text: cheap, readable, and true at any angle.
- **Lanterns still on**, which is how the street range degrades into the
  skyline range without a visual jump.

### 4.3 Shopfront range (< 35 m)

The live facade, reorganised for a 2.2 m walker:

- Cover art fills the wall above the sign line; the interactive strip
  (checklist, state chip, open button) sits between 1 m and 3 m, at eye
  level; the title is the sign above the door. Nothing important is above
  4 m.
- A **focus ring** on the building the walker faces, and a subtle hover
  highlight on interactive items: you can see what will react.

### 4.4 Attention and anomalies ("what's that over there?")

An **attention score** per task, deterministic from synced data plus the
local clock at day granularity:

| Signal | Weight |
|---|---|
| Blocked | 3 |
| Overdue | 3 (+1 per week overdue, capped at 6) |
| Due within 3 days | 2 |
| In progress with no activity for 14 days | 2 (a lit building in old history) |
| High priority and open | 1 |
| Heavy (many links / items) and open for > 8 weeks | 1 |

Score ≥ 3 makes a task **anomalous**: it gets an Attention beacon, its
lantern pulses slowly (a 3 s luminance cycle on the emissive factor, no
extra geometry), and, if it is in the top *N* (N = 6 for a district), it
gets a billboard on the frontier plaza. Because the score is based on
pattern breaks, a healthy project has few or no anomalies and a quiet
plaza, which is the point: the eye is drawn by exceptions.

## 5. Stability and spatial memory

The M0 layout invariants stay and extend:

| Element | Function of | Invariant test to add |
|---|---|---|
| Building placement | `(createdAt, id)`, week bucket | exists |
| Fold (90° turn) | bucket index | shuffled arrival ⇒ identical folds; appending never changes existing folds |
| Block / Corner / Overview beacons | `StreetPlan` | same plan ⇒ same beacons, order and poses |
| Frontier plaza | last bucket index | appending tasks to the last week does not move the plaza; a new week moves it exactly one bucket forward |
| Billboard pylons | attention rank (slot), not task | the set of pylons is constant for a district size; only their content changes |
| District cell | rank of project id hash among known project ids | adding a project never moves an existing district |
| Attention beacons | task data + day | same data on two devices on the same day ⇒ same beacons |

Two layout fixes for the M0 edge cases:

- **Fixed project epoch.** Persist the project's week-zero epoch with the
  project (or derive it from the project's own `createdAt`), so a task older
  than all known ones syncing in cannot shift bucket zero.
- **Reserve empty weeks.** Instead of collapsing an empty week to 7 m, give
  it a 12 m "vacant lot" segment that already reserves one building slot per
  side. A task syncing into an empty week then fills the reserved slot and
  nothing downstream moves. The 7 m gap was a hike-avoidance trade-off; with
  beacons and flights, walking length no longer matters and the invariant
  can be made absolute.

Recognisability comes from the combination: the fold shape is the same for
every district (you learn one shape), row depth is the project's age, the
plaza is always at the front, and a task's block never changes. "The
blocked one is in row three, left side, past the corner" stays true for
years.

## 6. Interaction with tasks

- **Click a facade** (tap threshold 6 px, 250 ms, so drag-look never
  triggers it): fly to its Task beacon. On arrival the facade is live.
- **Checkboxes** on the live facade write through the app's real checklist
  services (M5). Optimistic tick, sync via the normal path, the captured
  sign and the lantern update on the next data change.
- **Open** button and double-click: the task detail opens as a **side
  panel** over the plaza (the world stays visible and keeps rendering at
  reduced rate), not as a route away from the world. Closing the panel
  returns to the same pose.
- **Links** draw as faint ground lines between linked buildings while one
  of them is focused, and the linked building's lantern brightens. Clicking
  the far end flies there. Links are the one thing the hairball did that
  the street cannot; this makes them local and on-demand instead of global.
- **Status changes** from the facade (a state chip menu) are allowed but
  never move the building; the lantern and sign change.
- **Accessibility.** Every beacon and facade action is reachable by
  keyboard, the side panel is the real task page with its existing
  semantics, and the plaza can be entirely bypassed by search.

## 7. Performance budget

Derived from the M0 measurements (0.6 ms per live capture on weak hardware,
hosting free, 120 fps on macOS at geometry baseline):

| Tier | Budget | Where | Capture policy |
|---|---|---|---|
| Live facade | **≤ 4** (focus building + its two neighbours + one billboard being read) | shopfront range only | every frame while focused; otherwise demote to mid |
| Sign / mid facade | ≤ 80 hosted, but capture only on **data change** or first sight | street range | `WidgetUpdatePolicy.manual`, re-capture on task change; a 3 s interval only as a fallback for late-arriving cover art |
| Billboards | ≤ 6 per district, mid tier | plaza | as mid |
| Block markers | 1 per bucket, captured once at build | everywhere | once |
| Far facade | all buildings | skyline | no widget; state plate, lantern mesh |
| Lanterns | all buildings, one instanced mesh | everywhere | emissive factor per instance; pulse is a uniform, not a re-upload |
| Beacons | ≤ 1 per bucket + attention + 4 | everywhere | one instanced quad batch, screen-space sized |
| Districts | only the focused district hosts widgets; others render far tier only | world | none |

Rules that keep the budget:

- Promotions are **scheduled, at most one per frame**, ordered by distance
  along the walk direction, and **suspended during flights** (pre-capture
  of the destination happens at flight start). This turns the 60–100 ms
  worst frames into a steady one-capture-per-frame cost.
- Sign captures use a **1000 × 400 px texture**, not the 12 m × 90 px/m
  content-sized one, which halves capture time and memory.
- Cover art is loaded once into an image cache shared by sign, live
  facade and billboard, never three times.
- The overlay's caps stay as debug knobs; the budget above is the default
  config.

Target: 60 fps on a mid-range phone for a 300-task district in the skyline
and street ranges, and no frame over 32 ms in the shopfront range. Measure
with `PLAZA_BENCH=1`, which gains a "flight" phase and a "plaza" phase.

## 8. Milestones

Each milestone is demonstrable in `dev_main.dart` on the 300-task preset
and the waddle preset, and adds its own tour stops so the screenshot set
grows with it. None wires the plaza into the app until M5.

### M1 — A legible skyline

- Fold the street (90° every 6th bucket), frontier plaza geometry (empty).
- Roof lanterns (instanced, state-coloured, screen-size-clamped).
- Dusk sky, distance fog, block markers with week labels.
- Height by weight instead of by content.
- Sign facade variant for the mid tier; live facade reorganised for a 2.2 m
  eye height.
- Property tests: fold stability, plaza position, height determinism.
- Tour stops: `district-overview`, `skyline-anomaly`.
- Done when: from the overview pose, a reviewer can point at the blocked
  and overdue tasks without reading a word.

### M2 — Beacons and flights

- Beacon model and renderer (Home, Block, Corner, Overview); flight
  controller (Hermite path, arc, easing, interruptible, Back stack).
- Keyboard: Tab/Shift-Tab, H, M, Backspace, Esc; click-to-fly on beacons
  and facades with tap threshold; collision for the walker.
- Promotion scheduling (one per frame, suspended during flights, destination
  pre-capture).
- Tests: flight path stays above ground and level; Back returns exactly;
  beacon poses are pure functions of the plan.
- Tour stops replaced by a beacon playlist; `PLAZA_TOUR` drives flights.
- Done when: a reviewer reaches any named task in the 300 preset in under
  ten seconds using only beacons and search-less keyboard navigation, and
  never sees a cut.

### M3 — Attention, billboards and search

- Attention score, Attention beacons, pulsing lanterns.
- Billboard pylons on the frontier plaza with stable slots.
- Search (`/`) over titles with fly-to.
- Links as on-demand ground lines with lantern brightening.
- Generator gains overdue, stale-in-progress and priority signals so the
  presets contain anomalies worth finding.
- Done when: the plaza tells a reviewer the six most important things about
  the 300 preset in one glance, and each is one flight away.

### M4 — Districts and the morning walk

- World grid (spiral by project id rank), multi-district presets (three
  synthetic projects plus waddle), district culling.
- World overview pose; the morning-walk playlist with pause/resume.
- Goals projection: goals as districts (synthetic goals preset).
- Tests: district placement stability under project addition; playlist
  determinism per day.
- Done when: the 90 s morning walk over four districts runs at 60 fps on
  macOS and the reviewer can say which district is in trouble.

### M5 — Real data and real interaction (first app wiring)

- Projection from the app's task, checklist, link and category models,
  driven by the existing providers (read-only first), behind a debug flag
  in settings, reachable from the task list's project view.
- Checkbox and state-chip writes through the existing checklist and task
  services; side-panel task detail.
- Fixed project epoch persisted; vacant-lot reservation for empty weeks.
- Tests: projection parity with the demo world (same output as
  `demo_world_projection.dart`), write paths through the real services.
- Done when: a maintainer opens their own project in the plaza, ticks an
  item on a wall, and sees it ticked in the task page.

### M6 — Touch, polish, mobile budget

- Virtual joystick, drag-look, tap-to-fly, pinch-to-overview.
- Mobile performance pass against the budget in section 7; `PLAZA_BENCH`
  flight and plaza phases.
- Design-system pass on facade typography and colour (the harness palette
  in `facade_widget.dart` is explicitly temporary).
- Done when: the 300 preset holds 60 fps in skyline and street ranges on a
  mid-range phone.

## 9. Open questions

- **Time as the only street axis.** Week buckets give stability for free,
  but a project whose tasks are mostly created in one burst is one very
  busy row. An alternative second axis (category as side of the street, or
  category as street within the district) would trade some stability for
  readability. Prototype after M1, decide with the screenshots.
- **How much should be live at all?** If the side panel is good, the live
  facade may only need checkboxes and the open button; everything else can
  be captured. That would let the live cap drop to two.
- **Lantern colour for "open".** Dim warm white risks reading as "on" from
  a distance. Test against the all-off "done" state in the overview
  screenshot before committing.
- **World scale for many projects.** Twenty districts on a spiral is a
  large world; the overview may need a second level (a "city map" texture)
  before flights make sense across it.
