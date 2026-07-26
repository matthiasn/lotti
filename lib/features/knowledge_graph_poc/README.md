# Knowledge-graph explorer (proof of concept)

An exploratory view of how everything in Lotti connects — entries, tasks,
projects, agents — as a graph you walk through rather than a diagram you squint
at.

**This is a spike**, not wired into normal navigation.

## What it does

- **You stand somewhere.** One node is the focus; its immediate neighbourhood is
  bright and framed, and everything else fades into a faint horizon.
- **You walk the links.** Tapping a neighbour moves the camera to it; it becomes
  the new focus, its own neighbours appear, and a trail shows where you came from.
- **You can see what you are looking at.** A side inspector previews the focus
  node — cover, type, area, age, links, summary.

## Where the code lives

```text
lib/features/knowledge_graph_poc/
```

Design context: [ADR 0029](../../../docs/adr/0029-knowledge-graph-explorer.md).

## How it works

Why the view is ego-centric rather than a whole-graph layout is documented in the
knowledge bundle:

**→ [knowledge/features/knowledge_graph_poc/](../../../knowledge/features/knowledge_graph_poc/)**
