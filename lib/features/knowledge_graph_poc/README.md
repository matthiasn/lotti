# Knowledge-graph explorer

An exploratory view of how everything in Lotti connects — entries, tasks,
projects, agents — as a graph you walk through rather than a diagram you squint
at.

The explorer is available from the graph action in task details.

## What it does

- **You stand somewhere.** The main canvas is a bounded 1–2 hop projection
  around the focus. A topology minimap keeps the full graph available for
  jumping without turning the primary view into a hairball.
- **You walk the links.** Tapping a neighbour moves the camera to it; it becomes
  the new focus, its own neighbours appear, and a trail shows where you came from.
- **You can read it.** Labels are prioritized and collision-placed; dense
  relation and photo sets collapse into exact-count aggregates that can be
  expanded in place.
- **You can choose how to navigate.** The same focus and filters drive either
  the spatial graph or a grouped Connections list. Density, hop, relation,
  type, category, recency, and task-status controls narrow the view.
- **You can see what you are looking at.** A compact side inspector shows the
  full title, cover art and linked photos, a collapsed AI brief, age, and linked
  entries without reserving an empty banner.

## Where the code lives

```text
lib/features/knowledge_graph_poc/
```

Design context: [ADR 0029](../../../docs/adr/0029-knowledge-graph-explorer.md).

## How it works

Why the view is ego-centric rather than a whole-graph layout is documented in the
knowledge bundle:

**→ [knowledge/features/knowledge_graph_poc.md](../../../knowledge/features/knowledge_graph_poc.md)**
