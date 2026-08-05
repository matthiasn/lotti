---
type: Feature Module
title: Knowledge-graph explorer
description: "A local-first, walkable knowledge graph with a topology minimap, readable Connections list, filtering, media, and AI context."
resource: ../../lib/features/knowledge_graph
tags: [knowledge-graph, visualization, navigation]
status: draft
generated: { by: claude-code/opus-5, at: 2026-07-26T04:15:00Z }
stale_after: 2027-03-08
sources:
  - id: src
    resource: ../../lib/features/knowledge_graph
    title: Knowledge-graph explorer source
    last_modified: 2026-08-05
---

The task knowledge-graph explorer described in ADR 0029.

It is a **walkable, local-first** graph view drawn with a 2D `CustomPainter`.
You "stand on" a focus node; the main canvas projects a bounded 1–2-hop
neighbourhood around it. Tapping a node makes the camera **walk the link** to
it. The full provider graph remains visible as a small topology map in the
corner, where any node can reseed the local workspace.

The same `GraphViewportController` state drives a non-spatial Connections list.
It groups direct neighbours by typed relationship and direction, preserving
the user's focus, history, filters, and next walk.

```mermaid
flowchart LR
  DB[(JournalDb)] --> Provider[taskGraphProvider]
  Reports[Agent reports] --> Provider
  Provider --> Raw[Raw task graph]
  Raw --> Topology[Full topology layout]
  Raw --> Projection[Bounded local projection]
  Viewport[GraphViewportController] --> Projection
  Projection --> Canvas[Graph canvas]
  Viewport --> Canvas
  Raw --> Connections[Connections list]
  Viewport --> Connections
  Topology --> MiniMap[Topology minimap]
  Canvas --> Inspector[Task inspector]
  Connections --> Inspector
```

# Why walking rather than a force-directed layout

A whole-graph force layout over a real journal produces a hairball. The
ego-centric projection in `graph_projection.dart` inverts that: the main view is
bounded by hops and a density node budget. Direct photos collapse into one media
aggregate. Large relation/type groups retain a recent preview and an exact-count
aggregate, which the user can expand independently. The topology minimap uses
the full precomputed provider layout, so global position is still available
without sacrificing local legibility.

# Rendering and interaction

`knowledge_graph_painter.dart` paints nodes, typed edges, labels, focus trails,
and media mosaics in screen space. `graph_label_layout.dart` measures labels and
places them at one of eight anchors using deterministic priority and collision
avoidance. Focus, selection, aggregates, direct neighbours, and second-hop
context descend in priority; non-essential labels cull at low semantic zoom.

The toolbar changes local density and hop depth, and filters by relationship,
node type, category, recency, and task status. Arrow keys move the selection in
screen-space direction, Enter or Space walks to it, and Escape walks back.
Painter semantics expose every visible node as a labelled button with a
minimum-size accessibility target. Reduced-motion and high-contrast media
preferences change motion and relationship stroke strength respectively.

# Inspector data

`task_graph_provider.dart` projects journal entities and typed `EntryLink`
variants into graph nodes and edges. For each task it resolves:

- cover art path and horizontal crop from `TaskData.coverArtId` and
  `coverArtCropX`;
- directly linked `JournalImage` paths, ordered after cover art and deduplicated;
- generated task status;
- the latest assigned-agent one-liner and TL;DR/report content.

The provider's update subscription watches loaded journal entity ids, report
ids, and report agent ids, so task media and AI context refresh with the graph.
The inspector renders a cover-first horizontal media carousel only when media
exists, keeps the full title visible, and collapses the longer AI brief by
default. Its linked-entry timeline remains another way to walk the graph.

**It ships, ungated.** Both task-detail app bars — `TaskCompactAppBar` and
`TaskExpandableAppBar` — render a hub-icon action that pushes
`TaskKnowledgeGraphPage`, and the gate in front of it,
`knowledgeGraphEntryPointEnabledProvider`, is `Provider<bool>((_) => true)` with
no config flag behind it. Every user with a task open can reach it, so treat
changes here as user-facing.
