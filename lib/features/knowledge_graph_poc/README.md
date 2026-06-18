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

This is a throwaway visual/interaction spike: it runs on **synthetic,
deterministic scenarios**, not real `JournalEntity`/`EntryLink` data, so the
explorer could be reviewed independently of the data plumbing. A four-discipline
expert panel (information visualization, ontology/graph-DB, open-world game
design, Flutter rendering) reviewed it across several iterations to a **9.2/10
consensus on interaction *and* looks** (every reviewer ≥ 9.0).

## Design (what the panel signed off on)

- **Ego / degree-of-interest, never the whole graph.** The focus is framed;
  emphasis falls off with BFS graph-distance, so a ~120-node world reads as a
  legible local neighborhood plus a faint horizon — no hairball.
- **Walk-the-link navigation.** Tap → the camera glides (emphasized easing + a
  "travel dolly" that pulls back mid-move and settles) to the new focus; a
  brightening **wake trail** and a **ghost ring** make the traversal read as
  travel. **Back / Recenter** controls + history. Free pan / pinch-zoom anytime.
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
| `domain/graph_layout_engine.dart` | `computeGraphLayout` (ego sector seed + FR relax) and `computeWorldLayout` (world-scale FR). Deterministic, seeded. |
| `ui/graph_style.dart` | Token-backed `GraphStyle`, node glyphs, type labels, and the relation-class → `EdgeVisual` mapping. |
| `ui/knowledge_graph_painter.dart` | The `CustomPainter`: atmosphere, biome haze, edges, walk trail, lit nodes, ghost ring, labels. |
| `ui/knowledge_graph_view.dart` | Host: layout choice, fit/walk camera, pan/zoom/tap, history, title + controls + inspector + legend. |
| `state/task_graph_provider.dart` | **Real-data adapter** (Phase 1): `taskGraphProvider` loads a task's real `linked_entries` (depth-2 BFS + project + checklists), maps entities→node types and links→relation kinds, resolves real category colors. Pure helpers `graphNodeTypeFor` / `graphNodeLabelFor` / `edgeKindFor` are unit-tested. |
| `ui/task_knowledge_graph_page.dart` | **In-app page** (Phase 1): Scaffold + "Knowledge graph" AppBar hosting the view, with loading / empty / error states. Reached from a hub icon on the task app bar. |
| `dev_main.dart` | Standalone dev entrypoint to explore the synthetic worlds interactively. |

## Pipeline

```mermaid
flowchart LR
  S[GraphScenario] --> L{size > 40?}
  L -- yes --> W[computeWorldLayout]
  L -- no --> E[computeGraphLayout]
  W --> V[KnowledgeGraphView]
  E --> V
  T[DsTokens] --> Y[GraphStyle.fromTokens]
  V -->|focus + BFS hops + camera| PA[KnowledgeGraphPainter]
  Y --> PA
  PA --> O["Canvas: vignette → biome haze → edges → trail → nodes → labels"]
  V -.->|tap| WK[walk: re-focus + glide + wake] --> V
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
expert panel scored the integration **9/10 in full app-scaffold screenshots**
(every reviewer ≥ 9).

### Feature flag

The hub icon is gated behind the `enable_knowledge_graph` config flag
(`enableKnowledgeGraphFlag` in `lib/utils/consts.dart`), seeded **off** by
default. Both app bars watch `configFlagProvider(enableKnowledgeGraphFlag)` and
omit the hub button while the flag is off, so there is no in-app entry point
until it's enabled under Settings → Advanced → Flags ("Knowledge Graph"). The
explorer is still an experimental spike, so it stays hidden for normal users.

The flag name/description and the page chrome (title, empty, error) are
localized in all six ARBs. The **in-graph copy** rendered by the painter/view —
node + relation type labels, legend/title captions, relative-age text, and the
fallback TL;DR sentences — is intentionally **English-only during the spike**.
Localizing that surface (≈40 strings × 6 locales) is deferred until the feature
graduates from behind the flag; it must be done before the flag is enabled by
default.

## Status & next steps

The view (interaction + looks) and the app integration are both panel-approved.
Still a Phase-0/1 spike in scope: the data load is a bounded depth-2 BFS with
per-id (coalesced) fetches — fine for a task neighborhood, but the eventual perf
spike (Barnes–Hut layout in an isolate, `drawRawAtlas` batching, viewport
culling, batched DB reads) is needed before scaling past the local
neighborhood. Non-blocking polish the panel flagged: biome haze legibility at
the pulled-back zoom, a touch more ghost-ring contrast, larger control hit
targets, and a phone bottom-sheet inspector (the detail panel is desktop-only
today).
