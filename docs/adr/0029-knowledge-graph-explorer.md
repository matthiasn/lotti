# ADR 0029: Knowledge-Graph Explorer

## Status

Proposed (2026-06-18)

## Context

Lotti accumulates a rich, heterogeneous knowledge graph — ~16 journal-entry types
and several definition/AI-config node types, joined by directional typed edges in
`linked_entries` (`EntryLink`: `BasicLink`, `ProjectLink`, `RatingLink`) plus
embedded/denormalized relationships (Checklist↔Item, Category ref, Label M:N,
HabitCompletion→HabitDefinition, AiResponse→source, DayPlan→Task/Category, and the
AI-config sub-graph Profile→Model/Skill→Provider). Every node and edge is
timestamped; Categories supply a natural color/grouping dimension; the graph is
sparse (1–10 links per typical node) with Project and Category nodes as hubs; a
heavy user reaches thousands of nodes. None of this link structure is currently
visible or explorable — there is no graph/network view (charting uses `fl_chart`,
`graphic`, `pie_chart`).

The goal is a visually compelling explorer that **aids reflection and recall** —
sitting between a "gamey, walk-the-world" feel and serious information
visualization — not a decorative toy. A four-discipline panel (information
visualization, ontology/graph-DB, open-world game design, Flutter rendering) was
convened; full findings and citations are in
[`docs/research/2026-06-18_knowledge_graph_visualization_panel.md`](../research/2026-06-18_knowledge_graph_visualization_panel.md).

All four disciplines converged independently on one load-bearing constraint:
**never render the whole graph.** The full force-directed "constellation of
everything" collapses into an unreadable hairball past a few hundred nodes (the
Obsidian graph view is the cautionary example), which is orders of magnitude below
a heavy user's node count. The field's answer — a DOI ego-network (InfoViz), a
schema-driven perspective (graph-DB), the "Local Sky" local-graph (game design) —
is the same idea: stand on one node, expand on demand, always seeded by a question.

## Decision

This ADR records the **shape** of the feature and its constraints. Nothing is built
yet; the phased plan (Decision 9) gates construction on a de-risking spike.

1. **Ego-centric, seed-and-expand — never the full graph.** Entry is always a seed
   (the open entry, a search hit, or "today"). Render only a bounded
   degree-of-interest neighborhood (graph distance + a-priori hub interest + recency,
   with `hidden`/soft-deleted edges scored ~0); double-tap expands a node's neighbors
   into the frontier. A hard visible-node cap is part of the contract, not a tuning
   afterthought (see Decision 6 budget).

2. **Schema-derived perspectives, not one canvas.** Ship a small set of saved,
   scoped lenses (visible node/edge types + per-type styling + seed query): (1)
   Project containment tree, (2) Provenance — what the AI touched, (3) Rating
   landscape, (4) Day-plan ↔ task flow, (5) Habit/measurement instance-of fan, (6)
   Category facet map. **The AI-config sub-graph is a separate, settings-only
   perspective** and is never mixed into journal views — it is plumbing, not lived
   experience.

3. **Layout follows the semantic relation class of the edges in view.** Layered
   (Sugiyama) for directed-acyclic relations — containment (`ProjectLink`,
   Checklist↔Item), provenance (`AiResponse`→source), AI-config, day-plan flow;
   organic/force for associative exploration; radial for instance-of fans
   (`HabitDefinition`→completions); adjacency matrix for dense many-to-many
   (Label↔entry, dense Rating); node-link whenever the user traces a path. Only the
   *visible* subgraph is ever laid out, keeping every layout job small.

4. **Visual encoding.** Category → color (the strongest pre-attentive grouping, and
   it already exists); node type → glyph using shape *families* plus the existing
   per-type icons (not 16 distinct shapes); hub degree → size; recency → luminance.
   User-authored links render solid; system-inferred/derived edges render faint and
   dashed so inference never masquerades as an asserted link.

5. **Time is a first-class axis.** Recency-as-luminance is the resting encoding (new
   bright/saturated, old dimmed). A scrubbable "graph diary" animates nodes/edges in
   as their timestamp crosses a window, and an opt-in "On This Day" flies to a
   genuine past cluster. **Layout stability is mandatory:** existing node positions
   are pinned and only new arrivals animate in — global re-layout never runs on a
   scrub tick or an incremental change (it destroys the mental map). Discovery is
   framed as honest *rediscovery* of the user's own forgotten connections, never
   fog-of-war over data they authored.

6. **Rendering stack: custom 2D `CustomPainter` + `Matrix4` viewport.** Nodes via
   `canvas.drawRawAtlas` against a pre-baked sprite atlas; edges via `drawVertices`/
   `drawRawPoints` (arrowheads only at high zoom). Force layout (Fruchterman-Reingold
   / ForceAtlas2 with a **Barnes-Hut** quadtree, O(N log N)) runs in a **long-lived
   isolate** that streams packed `Float32List` positions and **settles-then-freezes**
   (stops ticking at low kinetic energy; re-heats locally on mutation). Interaction is
   a custom `GestureDetector` (scale + pan + double-tap + fling), **not**
   `InteractiveViewer`; tap maps to a node by inverting the view matrix and querying a
   quadtree (the same spatial structure). **Committed node budget:** ≤300 visible live
   at 60fps; 300–800 with viewport culling + level-of-detail + atlas batching;
   800–2000 with cluster rasterization; beyond that, aggregate distant regions.
   **Rejected:** `graphview` (one widget per node — small graphs only; reference
   only); 3D via `flutter_scene`/`flutter_gpu` (preview, master-channel only —
   disqualified on a five-platform stable app); `flame` (production-grade but overkill
   for a pannable graph — reserved as a future escape hatch only if a true particle-
   rich "world" is later wanted). Reuse the existing `.frag` shader pipeline
   (`lib/features/ai/ui/animation/`) for optional glow.

7. **Data prerequisite — give `BasicLink` semantics, with no migration.**
   `BasicLink` is currently untyped; its meaning is reconstructed by UI context, so
   it cannot drive styling, filtering, or layout. Add one **nullable** `semantic`
   string property and **backfill by inference** from the rules already applied in the
   UI (`AiResponse`→source ⇒ `derivedFrom`; `DayPlan`→`Task` ⇒ `plans`; same-day
   entries ⇒ `relatedTo`; …), constrained to a small closed vocabulary aligned to
   PROV-O/SKOS/schema.org names. Old rows stay valid (null = unspecified association).
   This is independently useful and is the cheapest high-leverage groundwork.

8. **Calm game-feel; no gamification.** Permitted: inertial pan/zoom, a "walk the
   link" eased camera dolly along edges (~400–600ms, never linear, never a cut),
   semantic zoom, an arrival "settle", animated constellation-line draw, restrained
   default-off sound. **Forbidden:** streaks, XP/levels, badges, leaderboards,
   completionist "fill the sky" pressure, unlock-gating the user's own data — for
   private, single-player journal data these corrode the intrinsic motivation the
   feature depends on. Feedback may acknowledge an action; it may never congratulate
   the user for using their journal.

9. **Phased delivery, spike-gated.**
   - **Phase 0 — POC spike (throwaway).** Real ~300-node category subgraph from
     `linked_entries`; Barnes-Hut layout in an isolate; `CustomPainter` +
     `drawRawAtlas` + viewport culling; custom pan/zoom; tap-to-select; on-screen
     frame-ms / visible-node overlay. **Pass criteria:** sustained 60fps panning at
     300 nodes on a mid-range phone, smooth settle without UI-thread jank, correct
     hit-testing at 0.25×–4× zoom. Push test data to 800/2000 to find the cluster-
     rasterization threshold.
   - **Phase 1 — "Local Sky" panel.** An embedded per-entry local-graph view (ego,
     1–2 hops, expand-on-demand) shipped *alongside* existing list/database views.
     Proves the one thing that can kill the vision — does walking a link feel good and
     useful? — and structurally dodges the hairball.
   - **Phase 2 — "Stargazer" world.** A first-class spatial explorer (night-sky
     metaphor, perspectives, graph diary, "On This Day"), grown out of Phase 1 only
     once traversal is proven to feel good.

## Consequences

- The explorer answers a concrete personal question and ends in an action ("open
  this task", "link this orphan", "revisit this dormant cluster") rather than
  rendering a pretty constellation — the failure mode every PKM graph view hits.
- Time becomes legible (accumulation, dormancy, "On This Day") — the dimension
  mainstream PKM graph views ignore and Lotti's strongest differentiator, enabled by
  the existing per-node/per-edge timestamps.
- The `BasicLink.semantic` backfill (Decision 7) improves the data model regardless
  of whether the visualization ships, and unlocks per-type styling/filtering/layout.
- The rendering choice reuses existing competencies (`CustomPainter`, `.frag`
  shaders, off-thread isolates) and adds no heavyweight rendering dependency.

Accepted limitations and deferred questions (not yet resolved):

- The visible-node cap means the explorer is deliberately a *local* tool; there is no
  global overview, by design. Hub fan-out (a Category's hundreds of children) is
  collapsed-by-default with a count badge, expand-on-demand.
- Force-layout *quality* (gravity/repulsion/edge-length tuning, type-aware seeding) is
  the expected time sink; Phase 0 must surface it before Phase 1 commits.
- Isolate↔UI cadence (tick rate during settling, freeze on idle) and Drift fan-out
  must reuse the batched `database_links_ratings.dart` path and the
  `idx_linked_entries_from_id_hidden_to_id` index; a naive per-node query would
  regress DB performance (see ADR 0025's fan-out lessons).
- Impeller is opt-in on desktop, so desktop runs on Skia — the atlas/shader paths must
  be validated on both.
- The `semantic` vocabulary, whether inferred edges are persisted vs derived at read
  time, and the perspective save/share model are open and deferred to Phase 1 design.
- Whether Phase 2 ("Stargazer") is built at all is contingent on Phase 1 proving the
  traversal feel; this ADR does not commit to it.

## Related

- Research: [`docs/research/2026-06-18_knowledge_graph_visualization_panel.md`](../research/2026-06-18_knowledge_graph_visualization_panel.md)
- ADR 0025 (insights time-analysis data layer) — `linked_entries` fan-out / batched
  query lessons apply to building the visible subgraph.
- ADR 0026 (author-time memory links) — related edge-creation semantics.
- Data model: `lib/classes/entry_link.dart`, `lib/database/database_links_ratings.dart`
  (index `idx_linked_entries_from_id_hidden_to_id`).
- Rendering precedents: `lib/features/ai/ui/animation/` (shaders),
  `lib/widgetbook/zoom_pan_wrapper.dart`, `third_party/flutter_onnxruntime` (isolate).
