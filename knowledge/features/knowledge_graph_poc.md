---
type: Feature Module
title: Knowledge-graph explorer (PoC)
description: "A walkable knowledge graph drawn with a CustomPainter — you stand on a focus node and walk the links rather than reading a hairball."
resource: ../../lib/features/knowledge_graph_poc
tags: [knowledge-graph, visualization, poc]
status: draft
generated: { by: claude-code/opus-5, at: 2026-07-26T04:15:00Z }
stale_after: 2027-03-15
sources:
  - id: src
    resource: ../../lib/features/knowledge_graph_poc
    title: Knowledge-graph explorer (PoC) source
    last_modified: 2026-07-26
---

A phase-0 spike for the knowledge-graph explorer described in ADR 0029.

It is a **walkable** graph view drawn with a 2D `CustomPainter`. You "stand on" a
focus node; its 1–2-hop neighbourhood is framed and bright while the rest of the
world recedes into faint, category-tinted "horizon stars". Tapping a node makes
the camera **walk the link** to it — that node becomes the new focus, its
neighbours expand in, and a trail plus a ghost ring mark where you came from. A
side inspector previews the focus node.

# Why walking rather than a force-directed layout

A whole-graph force layout over a real journal produces a hairball: every node is
drawn, nothing is legible, and the visualization answers no question. The
ego-centric model inverts that — **the view is always bounded by hops from where
you stand**, so complexity stays constant regardless of graph size, and the
horizon stars preserve a sense of scale without paying to render it.

**It ships, ungated.** Both task-detail app bars — `TaskCompactAppBar` and
`TaskExpandableAppBar` — render a hub-icon action that pushes
`TaskKnowledgeGraphPage`, and the gate in front of it,
`knowledgeGraphEntryPointEnabledProvider`, is `Provider<bool>((_) => true)` with
no config flag behind it. The concept is still exploratory in ambition, but every
user with a task open can reach it, so treat changes here as user-facing.
