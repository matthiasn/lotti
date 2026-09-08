# Plaza: cinematic night city

Design proposal, 2026-09-08. The user selected a cinematic nighttime city inspired
by Times Square. This is the outcome of an AI review panel covering game
environment art, urban architecture, real-time rendering, and product navigation.
The board is not a rendered app capture or a performance result. The first
implementation now includes bounded task-building kits, a stepped project
landmark, recessed shopfronts, restrained paving and status roofs. The map hides
decorative enclosure at its altitude threshold. Pylon replacement, additional
sign typography work and a smooth context fade remain later design work; current
runtime behaviour belongs in the linked concept.

The panel reviewed the supplied prototype screencast frames and the integrated
source at `03ef8ae09`. Those frames establish the visual starting point; they do
not verify how the latest integration renders. Current behavior remains
documented in the [Plaza concept](../../knowledge/features/plaza.md).

The accompanying generated board uses fictional penguin-project content and
shows Home, Overview and a task frontage. It is an art-direction reference:
its facade detail and lighting are aspirations, not evidence of current renderer
capability. Images remain outside the repository. Panel review specifically
required a dominant front-facing overdue sign, distinct red/orange status hues,
and a correctly ordered six-week timeline.

## Direction

Build a convincing city around the task signs: a memorable corner landmark,
substantial storefronts, stepped towers, and a clear avenue through the timeline.
Keep the spectacle concentrated around Home and important work. Let the ground,
ordinary buildings and distant skyline provide quieter surroundings.

The architectural reference is the pedestrian ground plane of
[Snøhetta's Times Square](https://www.snohetta.com/projects/times-square):
cohesive paving, reduced clutter, and benches that organize the open space.
Our design inference is to combine that restrained ground with theatrical,
building-mounted task screens above it. This is inspiration, not a replica.

## Panel findings and decisions

| Lens | Finding | Proposed response |
| --- | --- | --- |
| Game environments | Repeated dark boxes and detached panels have little visual hierarchy. | Three related building families; one dominant Home composition; signs integrated into architecture. |
| Architecture | Huge panels obscure the base, middle and crown of buildings. The square feels detached from its edges. | Continuous lower frontage, visible supporting walls, recessed entrances, upper setbacks and edge seating. |
| Real-time 3D | The renderer already has bloom and atmosphere; visual structure offers a better first return than more effects. | Retain the current rendering path, shared textures and batches; improve geometry proportions and authored shading. |
| Product/navigation | An attractive street can still hide the timeline or depend on cover art that tasks lack. | Design text-led signs, preserve task facts and approach paths, and give Overview a distinct information hierarchy. |

### Architectural kit

1. **Stepped crown tower.** A masonry podium, narrowing upper volumes and a
   recognizable crown. Carries project identity and anchors Home.
2. **Corner media tower.** A chamfered or corner-facing volume with screens
   visibly supported by its facade. Carries the strongest attention sign.
3. **Theater frontage.** Lower podium, recessed door treatment, shallow canopy
   and a tower set behind the streetwall. Houses everyday task interactions.

Each family has coordinated proportions and window rhythms. Choose its identity
from project/task IDs and a versioned recipe; do not independently randomize
every cornice or replace the architecture whenever status changes. Constrain
every recipe to the available plot and existing navigation envelope.

Priority still changes physical sign size. Building variety must not erase that
signal, and low-priority tasks must retain useful nearby interaction surfaces.

### Home and street composition

- Show the project landmark and the entrance to the timeline street together
  from the normal Home pose. Place the primary attention panel low enough to read
  without looking steeply upward.
- Frame the view with inhabited frontage and a small amount of edge furniture.
  Keep the walking axis open; do not fill vacant paving with random props.
- Use a few dominant building-mounted signs. Replace the current impression of
  a pylon forest without removing access to attention tasks.
- Use restrained paving courses and edge bands. Support luminous storefronts
  with subtle, broken light pools; avoid a prominent checkerboard floor.
- Give upper towers distinct silhouettes and quieter windows. Background
  buildings provide enclosure and depth without resembling additional tasks.

### Task signs and status

Text-only tasks need intentional poster layouts: title, status, concise facts
and a clear action. Cover art is optional richness. At least half the tasks in
the first visual fixture should have no cover. Keep visible architecture around
the sign; avoid turning every facade into the same oversized dashboard card.

Retain blue for in progress, yellow for open, red for blocked, orange for overdue,
and green for done. Pair state with glyphs as well as color. Category identity
must not compete with these meanings through equally bright decorative accents.

Overdue flames stay localized around the sign's upper edge and must not obscure
its title or action. A blocked task that is also overdue still needs its blocked
identity and overdue signal; the presentation must not drop either fact.

Completed tasks should feel settled and successful: visibly green, less luminous
and recessed beside their actual week. Avoid shuttered or abandoned-looking
completion architecture. Keep cancellation distinct from successful completion.

### Overview and category exploration

Overview exposes the task district: clear week markers, a continuous timeline
route, broad roof state signals and recognizable Home. Reduce decorative skyline
contrast and occlusion at altitude. Roof glyphs support color; distant wall text
is not the primary information channel. Transition smoothly with altitude.

Green completed courtyards remain distributed beside their original weeks.
Gathering them into a fictional final week would misrepresent chronology.

Category worlds should develop into a boulevard of project entrances. Each
gateway carries its project's name, status and aggregate counts; entering it
reveals the richer task plaza. Completed projects remain farther from Home.
The first pass can improve the current gateway architecture while preserving
the existing category layout and scope boundaries.

## First implementation slice

Use the penguin fixture to redesign Home, its nearest street corner, one task
frontage and the corresponding Overview as one coherent slice. Include every
status, several priorities, long titles, tasks with and without covers, and a
blocked-and-overdue task. Use the established six-week fixture for comparisons.

Keep road centerlines, week membership, task IDs, Home and approach destinations
unchanged in this pass. Express new massing inside current envelopes. Do not
introduce a new diagonal road network just to imitate Times Square's plan.

Implement in this order:

1. Define the architectural recipes and validate their bounds and anchors.
2. Compose the three building families and supporting street frontage.
3. Integrate the primary screens, refine text-led signs and quiet the ground.
4. Make roof status and background suppression work in the same Overview.
5. Compare fixture captures and measure native performance before expanding.

All new styling must resolve through the existing design-system tokens and
components. Audit the legacy Plaza palette rather than extending its prototype
exceptions. If the token export has a genuine gap, propose it explicitly before
implementation. Any new user-visible labels require all localization catalogs.

## Technical boundaries

These are implementation seams, not new APIs already present:

| Work | Existing seam |
| --- | --- |
| Versioned architectural configuration | `lib/features/plaza/scene/project_world_generator.dart` |
| Shared massing, solids and sign-mount descriptions | `lib/features/plaza/domain/street_layout.dart`, `lib/features/plaza/domain/scenery.dart`, `lib/features/plaza/scene/plaza_world.dart` |
| Building and screen construction | `lib/features/plaza/scene/plaza_buildings.dart`, `lib/features/plaza/scene/plaza_billboards.dart` |
| Shared window and frontage treatment | `lib/features/plaza/scene/wall_textures.dart` |
| Paving, light spill and background hierarchy | `lib/features/plaza/scene/plaza_ground.dart`, `lib/features/plaza/scene/plaza_lights.dart`, `lib/features/plaza/scene/plaza_skyline.dart` |
| Aerial status cues | `lib/features/plaza/scene/plaza_sprites.dart` |
| Capture and detail budgets | `lib/features/plaza/scene/facade_lod_manager.dart`, `lib/features/plaza/scene/surface_captures.dart` |

The first pass should retain the current unlit/static-batching path. Use shared
material families, geometry shading, recesses and existing light-pool treatment.
Do not make the concept depend on mirror puddles, volumetric beams, additional
full-screen effects or a unique texture for every building.

Three cross-review constraints matter:

- An apparent walk-through arcade must not hide an unchanged collision wall.
  Use shallow facade recesses initially.
- Angling a billboard changes its mount, picking plane and viewing approach.
  Change their shared description together; renderer-only offsets are unsafe.
- Roof additions and overhangs must agree with the solids used by flight
  clearance. A prettier model must not introduce camera intersections.

Keep family selection stable through title/status updates. The current layout
is deterministic but does not reserve immutable parcels; this visual pass must
not claim to solve that separate spatial-stability limitation.

## Acceptance

Visual review should answer these questions at the actual review viewport:

- At Home, can a reviewer immediately read the primary attention task's title
  and status, recognize the project landmark, and see the way into the street?
- Does a close task panel retain readable facts and an accessible action while
  leaving enough visible architecture to feel embedded in a building?
- In Overview, can a reviewer distinguish done, blocked and overdue work
  without zooming, using color and glyphs, and follow the week sequence?
- Does the world remain appealing when most tasks have no cover image?

Performance gates are proposed targets, not measured outcomes: no new full-screen
passes; no increase to facade capture/live limits or ambient budgets; no new
per-frame allocations proportional to architectural detail. Use baseline draw
and translucent-batch counts as a guardrail, targeting at most 10% growth on the
same fixture and path. A faster result is welcome; matching the picture matters
more than spending that allowance.

On a named 120 Hz Mac, record UI and raster/GPU frame times for walking, flying,
Overview and refresh separately. Each pipeline stage should fit the 8.33 ms
frame budget; report median, p95, p99 and missed frames. Report generation and
scene-upload hitches separately. Compare the same build mode, resolution,
display scale and frame cap. Existing measurements and their limitations belong
in the [integration record](../implementation_plans/2026-09-07_plaza_integration.md).

Before visual implementation, capture fixture baselines for Home, street corner,
frontage and Overview using the [screenshot workflow](../../knowledge/conventions/screenshots.md).
Use headless tests for recipe determinism, solid agreement, approach clearance,
status semantics and picking/batching invariants. Native scene captures and
performance runs remain necessary; generated concept art is neither.

## Later layout work

| Task count | Intended reading |
| --- | --- |
| 0 | Complete small square with project identity and an empty-state sign; no invented task buildings. |
| 1 | One occupied frontage, with quiet background architecture providing enclosure. |
| 10 | Short coherent street with a recognizable entrance. |
| 28 | Reference district with readable weeks and occasional taller accents. |
| 100 | Several blocks, with roof states carrying the distant view. |
| 500 | District overview and local exploration, including dense-week handling. |

One dense week currently lengthens a single street segment: folding between
weeks does not make 500 tasks in one week compact. A subsequent generator change
should evaluate deterministic overflow blocks with repeated week/date labels.
Also defer new category street topology, reserved parcels, physical reflections
and expanded ambient simulation until the first visual slice is convincing.
