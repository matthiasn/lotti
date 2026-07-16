# Knowledge-Graph Explorer — Proof of Concept

Phase-0 spike for the knowledge-graph explorer described in
[ADR 0029](../../../docs/adr/0029-knowledge-graph-explorer.md) (research:
[`docs/research/2026-06-18_knowledge_graph_visualization_panel.md`](../../../docs/research/2026-06-18_knowledge_graph_visualization_panel.md)).

A **walkable** knowledge-graph view drawn with a 2D `CustomPainter`. You "stand
on" a focus node; its 1–2-hop neighborhood is framed and bright while the rest of
the world recedes into faint, category-tinted "horizon stars". Tap a node and the
camera **walks the link** to it — it becomes the new focus, its neighbors expand
in, and a trail + ghost ring mark where you came from. A side **inspector**
previews the focus node (cover, type, category, age, links, TL;DR).

The production route adapts real `JournalEntity` and `EntryLink` data into the
same graph model used by the deterministic development scenarios. A
four-discipline expert panel (information visualization, ontology/graph-DB,
open-world game design, Flutter rendering) reviewed the original visual spike
across several iterations to a **9.2/10 consensus on interaction *and* looks**
(every reviewer ≥ 9.0).

## Design (what the panel signed off on)

- **Ego / degree-of-interest, never the whole graph.** The focus is framed;
  emphasis falls off with BFS graph-distance, so a ~120-node world reads as a
  legible local neighborhood plus a faint horizon — no hairball.
- **Walk-the-link navigation.** Tap → the camera glides (emphasized easing + a
  "travel dolly" that pulls back mid-move and settles) to the new focus; a
  brightening **wake trail** and a **ghost ring** make the traversal read as
  travel. **Back / Recenter** controls + history. Free pan / pinch-zoom anytime,
  including trackpad scroll-to-zoom on desktop.
- **Local force simulation.** The deterministic layout is the rest state; the
  focused 1–2-hop neighborhood becomes a short-lived force island with edge
  springs, local separation, damping, and a weak anchor back to the static
  layout. Walk-to navigation gives the destination node a larger, lower-damping
  impulse so it keeps wobbling after the camera arrives. Edges, labels, and the
  walk trail use those display positions, then the ticker stops once the island
  settles. System "reduce motion" disables it.
- **Relation class drives edge styling.** Containment = thick near-white
  backbone; the generic `BasicLink` association splits into *linked-task*
  (dashed + arrow) vs *note/log*; AI provenance = cyan dash; rating/evaluation =
  pink dot-dash. Edge hues are kept **outside** the node-category palette.
- **Encoding.** Category → node hue; type → glyph; degree → size; recency →
  luminance within the node's own hue; graph-distance → atmospheric depth dimming
  of nodes and the edges reaching them.
- **Atmosphere ("place").** Radial vignette + faint star-field; soft
  category-tinted **biome haze** behind clusters (so you can aim at distant
  regions); lit-sphere nodes with a glow; the focus on a contact-shadow seat. No
  streaks / XP / badges.
- **Inspector preview.** Center-right card: cover banner (a task's real cover
  art or an image entry's photo, else a category-gradient + glyph), full title,
  type · category, created + link count, and a real TL;DR — a task shows its
  most recent linked AI-response text, an AI node shows its own; other types
  fall back to a generic, type-based line. Updates as you walk.

All colors and text styles come from the design-system tokens (`DsTokens`); the
painter takes a plain `GraphStyle` value object so it never needs a
`BuildContext`. The overlay is wrapped in a transparent `Material` so widget text
renders cleanly outside a `Scaffold`.

## Files

| File | Role |
|------|------|
| `domain/graph_models.dart` | `GraphNode` / `GraphEdge` / `GraphScenario`, type enums, `degreeMap`. |
| `domain/graph_scenarios.dart` | Deterministic scenarios: `exploreWorldScenario` (~120 nodes) + the task ego-views (`taskEgoNetworkScenario`, `busyTaskScenario`, `lightTaskScenario`). |
| `domain/graph_layout_engine.dart` | `computeGraphLayout` (ego sector seed + FR relax) and `computeWorldLayout` (world-scale FR). Deterministic, seeded. `computeLayoutForScenario` dispatches between them at `kWorldScaleThreshold` (the single source of truth shared with the view). |
| `ui/graph_style.dart` | Token-backed `GraphStyle`, node glyphs, type labels, and the relation-class → `EdgeVisual` mapping. |
| `ui/graph_motion_controller.dart` | Event-driven local force island: edge springs, local separation, damping, anchored offsets, graph-surface repaint ticker, and settle/stop logic. |
| `ui/knowledge_graph_painter.dart` | The `CustomPainter`: atmosphere, biome haze, edges, walk trail, lit nodes, ghost ring, labels. |
| `ui/knowledge_graph_view.dart` | Host: layout choice, fit/walk camera, pan/zoom/tap, history, title + controls + inspector + legend. Uses a pre-computed `layout` when given (provider path) and only relaxes the graph itself as a fallback (synthetic scenarios / tests). Reports walked-to task nodes to the page so real-data graphs can expand lazily. |
| `state/task_graph_provider.dart` | **Real-data adapter** (Phase 1): `taskGraphProvider` loads a task's real `linked_entries` (depth-2 BFS + project + checklists), maps entities→node types and links→relation kinds, resolves real category colors, and relaxes the layout **on a background isolate** (`Isolate.run`) so opening the page never blocks the UI thread — the result rides in `TaskGraphData.layout`. The same off-thread layout entry point is reused after additive expansions. The context-only `knowledgeGraphEntryPointEnabledProvider` suppresses a recursive graph button inside the explorer's embedded task detail. Pure helpers `graphNodeTypeFor` / `graphNodeLabelFor` / `edgeKindFor` are unit-tested. |
| `ui/task_knowledge_graph_page.dart` | **In-app page** (Phase 1): hosts the view full-bleed in a `Stack` with a compact, transparent top-left header (back + "Knowledge graph" title) floated over the graph — no banded app-bar row. Reserves the header's height in the view's `MediaQuery` top padding (so the view's own top-left chrome clears it) rather than a full-width bar that would swallow taps over the inspector. Loading / empty / error states; reached from a hub icon on the task app bar. When the user walks onto a task that was only present as a project sibling, the page reads that task's graph, merges its nodes/edges into the graph already on screen, and swaps in a freshly relaxed merged layout. |
| `dev_main.dart` | Standalone dev entrypoint to explore the synthetic worlds interactively. |

## Pipeline

```mermaid
flowchart LR
  P[taskGraphProvider(seed task)] --> D[TaskGraphData]
  D --> S[GraphScenario]
  S --> L{size > 40?}
  L -- yes --> W[computeWorldLayout]
  L -- no --> E[computeGraphLayout]
  W --> V[KnowledgeGraphView]
  E --> V
  T[DsTokens] --> Y[GraphStyle.fromTokens]
  V -->|focus + BFS hops + camera| PA[KnowledgeGraphPainter]
  V -->|tap / walk / pan-end impulses| M[GraphMotionController]
  M -->|display offsets + repaint| PA
  Y --> PA
  PA --> O["Canvas: vignette → biome haze → edges → trail → nodes → labels"]
  V -.->|tap| WK[walk: re-focus + glide + wake + spring kick] --> V
  V -.->|walked-to task| X[TaskKnowledgeGraphPage expansion]
  X --> XP[taskGraphProvider(walked task)]
  XP --> XM[merge nodes + edges into current graph]
  XM --> XR[layoutTaskGraphOffThread]
  XR --> V
```

## Previewing

Interactive (pan / pinch-zoom / tap-to-walk, with a scenario + theme switcher):

```bash
fvm flutter run -t lib/features/knowledge_graph_poc/dev_main.dart -d linux   # or macos / a device
```

Deterministic screenshots (mobile + desktop) are produced with the screenshot
harness (`test/test_utils/screenshot_harness.dart`). `captureInApp` writes via
`matchesGoldenFile`, so it only emits PNGs under `--update-goldens` and would
fail a normal CI run with no committed baseline — it is a **throwaway** tool, not
a committed test. To regenerate previews, write a short capture test that calls
`captureInApp` for each scenario, run it with `--update-goldens`, view the PNGs,
then delete the test:

```bash
fvm flutter test test/features/knowledge_graph_poc/ui/<throwaway>_test.dart \
  --update-goldens
# PNGs → test/features/knowledge_graph_poc/ui/screenshots/ (gitignored)
```

## App integration (Phase 1 — done)

Wired to real data and reachable in-app: a **hub icon on the task app bar**
(compact + expandable) opens `TaskKnowledgeGraphPage`, which loads the task's
real `linked_entries` neighborhood via `taskGraphProvider` and renders it with
real `CategoryDefinition` colors. The relation mapping is validated against the
live `db.sqlite` schema (`BasicLink`→association/provenance, `ProjectLink`→
containment, `RatingLink`→evaluation, plus embedded project + checklists). The
view is additive after the initial load: walking from a project to a sibling
task triggers a second `taskGraphProvider` read for that task, deduplicates and
merges the returned nodes/edges into the current scenario, then recomputes
layout for the merged graph on the same background isolate path. The route does
not switch to a new base task, so the already visible world stays on screen
while new links become explorable. The expert panel scored the integration
**9/10 in full app-scaffold screenshots**
(every reviewer ≥ 9).

### Entry-point rollout

The hub icon is always available from the compact and expandable task app bars.
The explorer embeds a task detail sidebar, so that nested `TaskDetailsPage`
overrides `knowledgeGraphEntryPointEnabledProvider` to `false`; this prevents a
second graph button from recursively opening the same route. The provider is a
view-context guard, not a user-facing rollout flag.

Page chrome, controls, relative ages, node and relation type labels, summaries,
and fallback/error messages are localized in all six primary ARBs. Titles and
category labels loaded from journal data remain the user's own text. The
synthetic scenario names used only by the standalone development harness stay
developer-facing.

## Status & next steps

The view (interaction + looks) and the app integration are both panel-approved.
Still a Phase-0/1 spike in scope: the initial data load is a bounded depth-2 BFS
with per-id (coalesced) fetches, and walked-to tasks can lazily add another
bounded task neighborhood to the visible graph. Layout already runs off the main
thread (`Isolate.run` in the provider and expansion merge); the remaining perf
spike (Barnes–Hut to drop the relax from O(N²), `drawRawAtlas` batching,
viewport culling, batched DB reads, and pruning/compaction for long exploration
sessions) is needed before scaling past a handful of local neighborhoods.
Non-blocking polish the panel flagged: biome haze legibility at the pulled-back
zoom, a touch more ghost-ring contrast, larger control hit targets, and a phone
bottom-sheet inspector (the detail panel is desktop-only today).
