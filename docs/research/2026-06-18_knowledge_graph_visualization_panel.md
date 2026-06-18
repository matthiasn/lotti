# Knowledge-Graph Visualization — Expert-Panel Research

Date: 2026-06-18

Supporting research for [ADR 0029 — Knowledge-Graph Explorer](../adr/0029-knowledge-graph-explorer.md).

This document captures the findings of a four-discipline panel convened to answer:
*how do we turn Lotti's link structure (entry links + the AI-config relationships)
into a visually compelling, genuinely useful explorer — and what is feasible in
Flutter today?* Each panelist did independent web research grounded in the actual
data model. The decision distilled from this research lives in ADR 0029; this file
is the rationale and the citations behind it.

## The data model the panel reviewed

**Node types (heterogeneous, typed).** ~16 journal-entry variants — `Task`,
`ProjectEntry`, `JournalEntry`, `JournalAudio`, `JournalImage`, `Checklist`,
`ChecklistItem`, `AiResponseEntry`, `DayPlanEntry`, `RatingEntry`,
`HabitCompletionEntry`, `MeasurementEntry`, `WorkoutEntry`, `SurveyEntry`,
`JournalEvent`, `QuantitativeEntry` (`lib/classes/journal_entities.dart`); plus
definition nodes `CategoryDefinition`, `LabelDefinition`, `HabitDefinition`,
`MeasurableDataType`, `DashboardDefinition` (`lib/classes/entity_definitions.dart`);
plus AI-config nodes `AiConfigInferenceProvider`, `AiConfigModel`, `AiConfigPrompt`,
`AiConfigInferenceProfile`, `AiConfigSkill` (`lib/features/ai/model/ai_config.dart`).

**Edge types.** The `linked_entries` table (`lib/database/database.drift`) stores a
directional `from_id → to_id`, a `type`, a `hidden` soft-delete flag, timestamps,
and a sync vector clock. `EntryLink` (`lib/classes/entry_link.dart`) has three
variants: `BasicLink` (any → any, generic), `ProjectLink` (Project → Task,
containment, denormalized to `journal.project_id`), `RatingLink` (Rating → rated
entity). Additional relationships are embedded/denormalized: Checklist↔ChecklistItem
(JSON id lists), Category ref (`Metadata.categoryId`), Label ref (M:N `labeled`
table), HabitCompletion→HabitDefinition, Measurement/Quantitative→MeasurableDataType,
AiResponse→source (via `BasicLink`), DayPlan→Task/Category (inline `PlannedBlock`),
and the AI-config sub-graph (Profile→Model/Skill, Model→Provider, Prompt→Model).

**Key properties.** Everything is timestamped (strong temporal dimension).
Categories give a natural color/grouping dimension. Graph is sparse (1–10 links per
typical node); Project and Category nodes are hubs. Scale: thousands of nodes for a
heavy user. No graph/network visualization exists today; charting uses `fl_chart`,
`graphic`, `pie_chart`.

## Convergent finding (all four panelists, independently)

**Never render the whole graph.** The full force-directed "constellation of
everything" is the most-criticized pattern in this space — it degrades into an
unreadable "hairball" past a few hundred nodes, and the canonical example (the
Obsidian graph view) is widely judged a beautiful-but-useless toy. The fix the
field converged on is the same idea under three names:

- **InfoViz:** a Degree-of-Interest (DOI) **ego-network** — "search, show context,
  expand on demand" (van Ham & Perer, IEEE InfoVis 2009).
- **Ontology / graph-DB:** a **schema-driven perspective** — seed a node, expand its
  neighborhood, scope by type (the Neo4j Bloom "perspective" model).
- **Game design:** the **"Local Sky"** — a world explored *from a standpoint*, never
  from orbit; the Obsidian *local graph* is the one part users found useful.

You stand on one node and explore outward; the graph grows as you walk it; entry is
always seeded by a question ("what's connected to *this*?").

## Brief 1 — Information Visualization

- **Primary view: DOI ego-network seeded by search/selection.** Render only the
  top-N highest-interest nodes (cap ~50–80; ~30 on phone). DOI = graph distance from
  focus (decaying per hop) + a-priori interest (hubs score higher; hidden/soft-deleted
  edges ~0) + a recency term. Double-tap expands a node's neighbors into the frontier.
- **Hairball, head-on.** Static node-link stays legible only below ~30 nodes; past
  that, force layout traps a high-energy hairball — orders of magnitude below a heavy
  user's node count. DOI never instantiates the hairball.
- **Secondary: adjacency matrix for a single hub's neighborhood.** Above ~20 nodes,
  matrices beat node-link on most tasks (Ghoniem, Fekete & Castagliola 2005) —
  *except path-tracing, which always favors node-link*. So: node-link to trace chains,
  matrix to scan everything attached to one hub.
- **Do NOT aggregate/edge-bundle as the primary mechanism** — those are clutter tools
  for *dense* graphs; Lotti is sparse, so bundling would hide the meaningful edges.
- **Time is the differentiator.** No mainstream PKM tool visualizes accumulation.
  Encode recency as luminance (new = bright/saturated, old = dim — the TempoVis idiom);
  a time-brushed "graph diary" animates entry over time (animation wins for perceiving
  add/delete; small multiples win for long-span topology comparison). Preserve the
  mental map: pin existing positions, animate only new arrivals — never re-run global
  layout per change.
- **Encoding:** Category→color (strongest pre-attentive grouping), type→glyph (shape
  *families* + existing icons, not 16 distinct shapes), degree→size, recency→luminance.
- **Anti-patterns:** the fireworks overview; force-directing the full set; layout
  instability; treating time as a hidden property; over-encoding shape; path-finding in
  a matrix or hub-scanning in node-link; showing hidden edges or full hub fan-out; a
  view that looks impressive but never drives an action.
- **Three concepts ranked by insight-per-effort:** (1) **Ego-Lens** — tap any entry,
  see its DOI ego-network; (2) **Graph Diary** — Ego-Lens + time slider + recency
  luminance + month-over-month small multiples; (3) **Hub Matrix + Health panel** —
  matrix for a dense hub + orphan/disconnected detection.

Sources: van Ham & Perer "Search, Show Context, Expand on Demand" (IEEE InfoVis 2009);
Ghoniem/Fekete/Castagliola, *Information Visualization* 2005; "Trimming the Hairball"
(Microsoft Research); dynamic-graph navigation (arXiv 2008.12747); TempoVis; ForceAtlas2
(Jacomy et al., PLOS ONE); Holten force-directed edge bundling; the Obsidian graph-view
critique and defense (codeculture.store; eleanorkonik.com).

## Brief 2 — Ontology / Graph-Database

- **You already have a Labeled-Property-Graph-shaped ontology; make it explicit.**
  Typed nodes + single-typed directional edges with properties = an LPG (Neo4j model).
  Map each edge to a semantic relation class:

  | Relation class | Lotti edges | Quality |
  |---|---|---|
  | instance-of (`rdf:type`) | HabitCompletion→HabitDefinition; Measurement/Quantitative→MeasurableDataType | clean |
  | containment / part-of | ProjectLink (Project→Task); Checklist↔Item | clean (single-hop; transitive latent) |
  | categorization (`skos:broader`, non-transitive) | entry→Category; entry↔Label (M:N) | clean |
  | evaluation | RatingLink | clean, distinct |
  | provenance (PROV-O `wasDerivedFrom`) | AiResponse→source; AI-config that produced it | clean but under-labeled |
  | association (generic/symmetric) | **BasicLink** | **muddy — untyped** |
  | configuration/dependency | Profile→Model/Skill; Model→Provider; Prompt→Model; DayPlan→Task/Category | clean, self-contained DAG |

  is-a and part-of are different hierarchy kinds; the model already keeps them
  separate (ProjectLink ≠ HabitCompletion→HabitDefinition) — preserve that visually.
- **The BasicLink problem — subtype it cheaply.** A single generic relationship type
  is an anti-pattern (meaning lives in the renderer, not the data; can't drive
  styling/filtering/queries). Low-effort fix with **no migration**: add one nullable
  `semantic` string property; **backfill by inference** from the same UI-context rules
  used today (AiResponse→source = `derivedFrom`; DayPlan→Task = `plans`; same-day
  entries = `relatedTo`); constrain to a small closed vocabulary aligned to
  PROV-O/SKOS/schema.org names.
- **Ship perspectives, never the whole graph.** Borrow the Neo4j Bloom "perspective":
  a saved, scoped projection (which node/edge types are visible, per-type styling,
  named saved queries). Seed → expand-on-demand; yFiles recommends an initial 20–50
  nodes driven by a question. Six concrete lenses for Lotti: **(1)** Project containment
  tree, **(2)** Provenance: what the AI touched, **(3)** Rating landscape, **(4)**
  Day-plan ↔ task flow, **(5)** Habit/measurement instance-of fan, **(6)** Category
  facet map. The **AI-config sub-graph is a separate, settings-only seventh perspective**
  — never mixed into journal views.
- **Layout follows relation class:** layered/Sugiyama for directed+acyclic
  (containment, provenance, config, day-plan flow); organic/force for associative
  exploration; radial for instance-of fans; matrix for dense many-to-many
  (Label↔entry, dense Rating); node-link whenever the user traces a path.
- **Cheap on-device reasoning wins:** transitive containment reachability (bounded
  depth), hub detection (degree centrality → collapse hubs by default with a count
  badge), orphan detection (weakly-connected components), label co-occurrence /
  community (Louvain), bridge detection (betweenness). Render derived edges as
  visually distinct (dashed) inferences, not as user-authored links.

Sources: Neo4j graph concepts & Bloom perspectives; W3C PROV-O, SKOS, RDF Schema;
Neo4j relationship-type optimization & super-nodes; Cambridge Intelligence "fixing
hairballs"; yFiles knowledge-graph guide; Ghoniem/Fekete matrix-vs-node-link.

## Brief 3 — Open-World Game Design

- **Metaphor: the night sky / observatory.** Sparse points in void (matches the
  sparse graph; void keeps a small graph from looking abandoned), brightness/color
  encode type & importance for free, and "picking out patterns you yourself draw"
  is exactly a personal knowledge graph. Rejected: literal city (implies a planned
  grid), garden (pushes toward tending chores = gamification), subway (implies fixed
  curated lines), cave/dungeon (implies threat — wrong for one's own life).
  - Mapping: Category → region/constellation; Project/hub → bright anchor star
    (landmark you navigate by); Task → planet orbiting its project-star (containment =
    orbit, auto-clusters); other entries → smaller bodies with distinct glyphs;
    **time → luminosity/redshift** (recent bright, old dims into the field, never a
    teleporting slider); user-drawn links → solid constellation lines; inferred links
    → faint dotted alignments; **AI-config sub-graph → off-map "instrument panel"**
    (AiResponses *about content* render as a faint halo around their source star).
- **Core loop:** drop in at a standpoint → read the horizon (nearby connected stars
  pull, un-visited ones shimmer) → walk a link (camera dollies along the edge) → arrive
  → discover a forgotten cluster → new horizon. Borrow the open-world exploration loop
  but strip the combat/reward beat. The test for every feature: *does this aid
  reflection/recall, or just pass time?*
- **Traversal & camera:** inertial pan/zoom always; the signature move is **"walk the
  link"** — a ~400–600ms eased camera dolly along the edge, never a cut, never linear;
  **semantic zoom** (Category resolves into Projects resolves into Tasks — also the
  60fps savior via LOD); phone = strolling (one-thumb, local graph), desktop =
  surveying (keyboard pan, wider field, dense pattern-finding); always a "fly home"
  gesture.
- **Discovery: rediscovery, not fog-of-war.** The user authored every node; hiding
  their own data behind a shroud is a lie. Honest analogues: recency-as-luminosity is
  the "fog"; faint "trails I've walked"; an Obra-Dinn-style satisfying *lock-in* when
  the user manually connects two drifting stars; and **"On This Day in your sky"** —
  fly to a true forgotten cluster from years past (reminiscence as navigation, the
  single feature most likely to make someone open the app for joy). Method-of-loci /
  spatial-memory research backs spatial navigation as a privileged path to recall.
- **Tasteful game-feel (worth adding):** easing on every camera move; an arrival
  "settle" (tiny scale breathe + neighbors recoil/re-settle); animated constellation-
  line draw; slow ambient parallax/twinkle; one restrained sound layer (settle / snap /
  discovery), default-off.
- **Where gamification HURTS (the line not to cross):** no streaks ("don't break the
  chain" turns reflection into guilt), no XP/levels for adding nodes (rewards quantity
  over quality), no badges, no leaderboards (this is private single-player data), no
  completionist "fill the whole sky" pressure, no unlock-gating one's own data. Anchor
  to intrinsic motivation — the payoff is genuine rediscovery, never a token.
- **Two concepts:** **bold "Stargazer"** (a first-class spatial world you live in) and
  **restrained "Local Sky"** (an embedded per-node local-graph panel). **Recommendation:
  build Local Sky first** — it tests the one thing that can kill the vision (does
  walking a link feel good?) cheaply and dodges the hairball.

Sources: Kevin Lynch *Image of the City*; open-world navigation/POI design; method-of-
loci meta-analysis (PMC); constellation knowledge-viz (arXiv 2507.12337); SDT
gamification critique (Springer); Vlambeer "Art of Screenshake"; FTL/Slay-the-Spire
map design; Return of the Obra Dinn; reminiscence/"On This Day" research.

## Brief 4 — Flutter Rendering Feasibility

- **Verdict: shippable today.** Hundreds of visible nodes (of thousands total),
  pan/zoom/animated at 60fps, is realistic. The hard part is layout math (must run off
  the UI thread), not rendering.
- **Recommended stack: custom 2D `CustomPainter` + `Matrix4` viewport.** Nodes via
  `canvas.drawRawAtlas` against a pre-baked sprite atlas (≈one draw call for N nodes);
  edges via `drawVertices`/`drawRawPoints` (arrowheads only when zoomed in, via
  `arrow_path`). The app already ships `CustomPainter` (29 files) and `.frag` shaders
  (`lib/features/ai/ui/animation/`) — reuse that glow pipeline for cheap flair.
- **Layout in an isolate.** Fruchterman-Reingold / ForceAtlas2 with **Barnes-Hut**
  quadtree (O(N log N)); a long-lived isolate ticks and streams packed `Float32List`
  positions back; **settle-then-freeze** (stop ticking at low kinetic energy, re-heat
  on mutation). Precedent: the off-thread ONNX runtime.
- **Node-count budget:** ≤300 visible live @60fps; 300–800 with viewport culling + LOD
  + atlas batching; 800–2000 with cluster rasterization (distant clusters as cached
  `ui.Image` sprites); beyond, aggregate.
- **Interaction:** custom `GestureDetector` (scale+pan+double-tap+fling), **not**
  `InteractiveViewer`; tap = invert the view matrix → quadtree nearest-node query.
- **Performance playbook (ROI order):** (1) viewport culling, (2) layout off the UI
  thread, (3) `drawRawAtlas`/`drawVertices` batching, (4) level-of-detail, (5)
  `RepaintBoundary` discipline, (6) cluster rasterization, (7) custom gestures, (8)
  spatial hit-testing.
- **Package verdict:** `graphview` (most popular) renders one widget per node — "small
  graphs" only → **reference, not dependency**. `flutter_graph_view` (Flame-based),
  `vyuh_node_flow` (CustomPainter + LOD) → **architecture references**. 3D
  (`flutter_scene`/`flutter_gpu`) → preview, master-channel only → **avoid** on a
  5-platform stable app. `flame` → production-grade but overkill for a pannable graph;
  reserve as an escape hatch only if the product later wants a true particle-rich world.
- **Risks:** layout *quality* tuning (the real time sink); isolate↔UI cadence
  (throttle during settling, stop when frozen); Impeller is opt-in on desktop (test on
  Skia too); Drift fan-out (reuse the batched `database_links_ratings.dart` path; index
  `idx_linked_entries_from_id_hidden_to_id` exists). **Spike first:** Barnes-Hut-in-
  isolate hitting tick-rate at 300/800/2000 nodes, and `drawRawAtlas` frame time under
  culling.

Sources: pub.dev (`graphview`, `flutter_graph_view`, `vyuh_node_flow`, `flame`,
`flutter_scene`); Flutter docs (`Canvas.drawAtlas`, fragment shaders, Impeller,
`InteractiveViewer`); Barnes-Hut (jheer.github.io); ForceAtlas2 (PLOS ONE).

## Codebase anchors for implementation

- Data model: `lib/classes/entry_link.dart` (typed directed links),
  `lib/classes/journal_entities.dart`, `lib/classes/entity_definitions.dart`.
- Batched link loaders: `lib/database/database_links_ratings.dart`
  (`getBulkLinkedEntities`, `linksForEntryIdsBidirectional`) and
  `lib/database/database.drift` (index `idx_linked_entries_from_id_hidden_to_id`).
- Shader precedent: `lib/features/ai/ui/animation/` (`FragmentProgram` + CPU fallback
  + golden tests).
- Zoom/pan reference: `lib/widgetbook/zoom_pan_wrapper.dart`.
- Off-thread isolate precedent: `third_party/flutter_onnxruntime`.
- Existing viz patterns: `lib/widgets/charts/`, `lib/features/dashboards/`,
  `lib/features/insights/` (see ADR 0025).
