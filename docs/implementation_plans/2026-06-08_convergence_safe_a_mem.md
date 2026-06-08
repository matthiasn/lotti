# Convergence-safe A-MEM for the planner memory

- **Status:** Phase 0 implemented (author-time links + recall). Phases 1–4 proposed (A16-adjacent).
- **Date:** 2026-06-08
- **Motivates:** Finding #8 + the open question of the [planner vs. state-of-the-art research note](../research/2026-06-08_long_horizon_planner_vs_state_of_the_art.md) — adopt the parts of A-MEM (Xu et al. 2025, [arXiv:2502.12110](https://arxiv.org/abs/2502.12110)) compatible with our append-only, convergent, cache-stable architecture.
- **Builds on:** [Planner log search](./2026-06-08_planner_log_search.md) (the `search_memory` recall tool — already shipped; Phase 0 extends it).
- **Depends on:** [ADR 0016/0017](../adr/0017-deterministic-log-compaction.md) (append-only log + deterministic compaction), [ADR 0018](../adr/0018-convergent-multi-device-execution.md) (convergence), [ADR 0022](../adr/0022-long-lived-daily-os-planner.md) (durable knowledge). Embeddings (Phase 2) depend on the [planner embeddings plan](./2026-06-08_planner_embeddings.md).

## The reframing

A-MEM has three mechanisms. The useful way to see them is *where the structure lives*:

| A-MEM mechanism | Structure lives… | A-MEM realizes it by… |
|---|---|---|
| **Note construction** (keywords/tags/description) | **in** a note | mutable store fields |
| **Linking** | **between** notes | a mutable graph of edges |
| **Evolution** | mutates existing notes | **in-place rewrite** |

A-MEM puts all three in a **mutable store**, and that is exactly what collides with our invariants (append-only set-union, deterministic compaction, prefix-cache stability). The collision dissolves once we **move the structure out of the store layout and into the note content** — which is free text we already author, sync, and fold:

- **Construction** = the agent writes attributes into the note body → free.
- **Linking** = the agent writes references (entry ids) into the note body → free, *and convergent because the cited id is the synced entity id*.
- **Evolution** = the agent writes a *new* note that supersedes an old one → append-only (we already do this for knowledge).

The "an append-log is too rigid for self-learning agents" critique is about the **store**. We keep the store rigid and put the plasticity in the **content**, which is maximally plastic. The critique evaporates without giving up a single invariant.

### Why in-place evolution stays a hard non-goal
Rewriting historical entries breaks all three load-bearing invariants at once:
- **Convergence (ADR 0016/0018):** the model is append-only set-union + deterministic fold. Two devices independently LLM-rewriting the same note are concurrent, non-deterministic mutations — LWW picks one arbitrarily, so "evolved" memory diverges per device. There is no convergent merge for "two different AI rewrites of one note."
- **Deterministic compaction (ADR 0017):** the `dayLog` is a reproducible fold of *immutable* events; mutating events makes the fold non-reproducible.
- **Prefix cache:** mutating historical content rewrites the prompt prefix → cache invalidation on every evolution.

So evolution is applied **only** as append-only supersession, never as in-place rewrite, and never to the episodic capture/observation stream.

## Two flavors of linking — keep them separate

"Linking" is two different things, and conflating them is the trap:

1. **Frozen author-time links (text in the note).** The agent writes `[[refines:<id>]]` into the note when it records it. Cheap (no extra LLM call — folds into the wake it is already running), convergent (the id syncs), cache-safe (content of a *new* append-only entry; never touches the prefix), zero Ollama. For **deliberate, durable relationship assertions** the agent makes with intent.

2. **Live read-time links (recall).** *Don't store the associative graph at all* — recompute the relevant neighborhood against the current query at read time. `search_memory` (shipped) is this primitive in substring form; embeddings are the semantic upgrade behind the same tool. For **associative recall** ("what else is relevant right now").

This is where we beat A-MEM rather than approximate it: A-MEM freezes links at write time *and then has to mutate them*. We never freeze the associative part — recomputing at read is strictly fresher than a baked graph and costs zero storage and zero convergence risk. We reserve frozen links only for relationships that are genuinely intentional and must outlive any single query.

## What we already have

The interesting part is ~80% enabled by what is already on this branch:

- Append-only immutable log — ✅ ADR 0016/0017
- Supersession (new version wins the Head) for knowledge — ✅ (`day_agent_knowledge_service.dart`, `supersedesId`)
- On-demand recall — ✅ `search_memory` (`AgentLogCompactor.searchLog`)
- A volatile retrieval slot that doesn't invalidate the `dayLog` prefix — ✅ C1 (`day_agent_context_builder.dart`)

The genuinely new work is small and is the lead phase below.

---

## Phase 0 — Author-time links in free content (the cheap win)

No Ollama, no schema change, no new entity, no convergence risk. This is the core of the idea.

### Content convention (a closed grammar)
The agent emits links inline in the text it *already* produces, using one token shape:

```
[[<relation>:<entryId>]]
```

- **`relation`** is a closed vocabulary (closed for deterministic handling + so specific relations can map onto existing mechanisms):
  - `refines` — sharpens/clarifies an earlier note; both stay true. (This is also how the agent records a "new version" of an observation: a fresh note that `refines` the old one.)
  - `supersedes` — replaces an earlier note; the earlier one is no longer the live truth.
  - `contradicts` — conflicts with an earlier note; surface for the user.
  - `relates` — generic association.
- **`entryId`** matches `[A-Za-z0-9_\-]+` and must be an id the agent actually saw (rendered log lines and `search_memory` hits both carry `contentEntryId`; knowledge lines carry their key).

The token is plain content. It rides inside the observation/knowledge text that already lives where it lives — it does **not** add anything to the cached prefix, and resolution happens only on demand (below).

### Where the convention applies
- **Episodic tier (observations / `record_observations`):** the token is the *only* link mechanism, and this is where "it's just text" pays off — no schema field exists and adding one would be churn. Meaningful relations here: `refines`, `supersedes` (read-time preference, see below), `contradicts`, `relates`.
- **Knowledge tier (`propose_knowledge`):** `supersedes` should continue to go through the **structured `supersedesId` field** (it exists, integrates with Head-wins recency, and is already convergent). The text token is the general-purpose fallback for `refines`/`contradicts`/`relates`, which have no structured home today.

`supersedes` in the episodic tier is **a read-time preference, not a storage mutation**: when recall surfaces a note that another in-scope note supersedes, it folds/annotates the superseded one. This is the convergence-safe analog of "memory evolution" at the episodic level — pure recall behavior over immutable data, the "create a new version" pattern the model asked for.

### Parser + resolver (pure, testable)
New file (proposed) `lib/features/agents/memory/memory_links.dart`:

```dart
enum LinkRelation { refines, supersedes, contradicts, relates }

class MemoryLink {
  final LinkRelation relation;
  final String entryId;
}

/// Tolerant: ignores malformed tokens and unknown relations (closed vocab),
/// dedups, preserves authored order.
List<MemoryLink> parseMemoryLinks(String content);

class ResolvedMemoryLink {
  final MemoryLink link;
  final bool exists;        // entryId resolved to a real entry/key
  final String? liveEntryId; // forward-followed Head if superseded, else entryId
  final bool superseded;
}

/// Validate against the projected log. `knownIds` = ids present in the agent's
/// projection; `supersededBy` maps an entryId to the id that supersedes it
/// (knowledge: current Head by key; episodic: any in-scope note carrying
/// `[[supersedes:<thisId>]]`). A token whose id is absent → exists:false
/// (a "dead link"), never fabricated, never auto-followed.
List<ResolvedMemoryLink> resolveMemoryLinks(
  List<MemoryLink> links, {
  required Set<String> knownIds,
  required Map<String, String> supersededBy,
});
```

### Recall-time validation (the safety net)
Hallucinated/garbage links are immutable, so they can't be cleaned up — but because they live in *content*, not a queryable graph, a bad link is just a dead string with near-zero blast radius (versus a bad edge in a mutable graph corrupting traversal globally). The guard is **validate-on-read**:

- Validation runs **only in `search_memory` results** (tool-call turns, after the cached prefix) — never while rendering the `dayLog` into the prefix. The `dayLog` tail shows the raw token as authored; expansion is on demand.
- A missing id renders as `[[relates:abc123 (not found)]]` rather than being dropped or silently followed, so the agent never invents a target.
- A token pointing at a superseded note resolves forward to the live Head (`liveEntryId`).

### Following a link (no new tool — extend `search_memory`)
Add an optional `ids` parameter to the existing `search_memory` tool so the tool count — and thus the cached tools prefix — stays stable:

- `day_agent_tools.dart`: `search_memory` gains `ids` (optional array of strings, clamped, e.g. 1–10) alongside `query`.
- `AgentLogCompactor`: add `Future<List<MemoryLogHit>> resolveByIds(agentId, {required Set<String> ids})` — chunked newest-first via the existing lazy resolver, resolving only the requested ids and stopping once all are found (no whole-history load).
- `MemoryLogHit` gains `links: List<ResolvedMemoryLink>` (additive) so every returned hit carries its outgoing links already validated — the agent can traverse another hop by calling `search_memory(ids: [...])` again.
- `day_agent_workflow.dart` `_searchMemory`: when `ids` is present, call `resolveByIds`; otherwise `searchLog` as today. Parse + resolve links on every returned hit before formatting.

### Prompting
- `record_observations` / `propose_knowledge` system-prompt lines: "When a note refines, supersedes, contradicts, or relates to an earlier one you can see, cite it as `[[relation:id]]` using an id from the log or a prior `search_memory` result. Never invent ids." One short line each.
- `search_memory` line gains: "Pass `ids` to pull up specific entries by id (e.g. to follow a `[[…:id]]` link)."

### Convergence & cache (Phase 0)
- Author-time tokens are content of append-only events → set-union, no merge conflict.
- Cited ids are synced entity ids → stable across replicas. Hallucinated id → validated to a dead link, never followed. Dangling (not-yet-synced) id → self-heals on sync; rendered as "not found," idempotent.
- No prefix impact: tokens add a few chars to content the prompt already includes (append-only additive — earlier prefix bytes are untouched); expansion/validation is in `search_memory` tool turns, after the cached prefix.

### Tests (Phase 0)
- `memory_links_test.dart`: grammar (valid/malformed/unknown-relation rejected), multiple links + dedup + order, no-links case.
- Resolution: known vs unknown id; supersession follow-forward (knowledge Head + episodic `supersedes` token chain); a 2-hop chain.
- `search_memory` `ids` path: resolves exact entries, lazy (does not load full history), missing id reported; hits carry resolved `links`.
- Convergence: two devices each append an observation citing the other's prior observation id → both links present, both resolve, set-union; no divergence.

### Done when (Phase 0)
The agent can author `[[relation:id]]` links in observations/knowledge, those links survive sync convergently, and it can follow/validate them via `search_memory(ids:)` — with no `dayLog`-prefix regression and zero Ollama dependency.

---

## Phase 1 — Construction attributes (as content)

Make recall hit better by having the agent attach keywords/tags — also as free text, not schema:

- **Episodic:** instruct the agent to lead an observation with a compact tag line (e.g. `keywords: deep-work, mornings`). Pure content; improves substring `search_memory`; zero schema.
- **Knowledge:** keep attributes in the statement/hook text first. Only if a structured need emerges, add **immutable** `keywords`/`tags` fields to `PlannerKnowledgeEntity` (set once at origin, synced as content, never recomputed per replica) — additive to conversions/LWW. Prefer text-first.

Fallback: if the agent omits attributes, recall degrades to today's behavior.

## Phase 2 — Semantic recall (embeddings, optional, Ollama-gated)

Slot an embedding ranker behind the **same** `search_memory` tool (embed the query/`ids` context, NN over embedded memory, substring fallback when Ollama is absent). This upgrades read-time linking from substring to semantic without changing the tool surface or the prefix. Details in the [planner embeddings plan](./2026-06-08_planner_embeddings.md). Retrieval lands in the C1 volatile slot — no `dayLog`-prefix cost.

## Phase 3 — Structured knowledge links (last resort)

Only if the Phase-0 text convention proves insufficient for the knowledge tier: add a `knowledge_link` `AgentLink`, generated **at origin, append-only** (set-union of links across devices), treated as additive hints — not one canonical evolving graph. Converges; strictly more machinery than Phase 0, so defer until there is evidence the text convention can't carry it.

## Phase 4 — Evolution-as-supersession (A16-gated)

At the weekly one-on-one ritual (A16), the agent *proposes* a consolidated/refined note that **supersedes** related entries via `supersedesId` (append-only, recency-wins, user-confirmed) — the convergence-safe analog of A-MEM "evolution": old notes stay immutable, a new note wins the Head. Surface proposed consolidations in the "What I've learned" panel. Depends on A16 landing first.

## Further Zettelkasten borrowings (evaluation)

Linking is the headline idea, but a Zettelkasten is more than links. What else is worth taking — and what to skip:

| Zettelkasten idea | Our analog | Verdict |
|---|---|---|
| **Atomic notes** (one idea per note) | one fact per observation / knowledge entry | **Adopt as a prompting norm** — makes links precise and supersession clean; zero mechanism. |
| **Unique stable ids** | synced entity ids the agent sees in the log | **Already have** — this is exactly what makes Phase-0 links convergent. |
| **Maps of Content / hub notes** (an index note linking into a topic cluster; an entry point that survives) | a knowledge entry keyed `moc:<topic>` whose statement is a curated `[[relates:…]]` list | **Adopt (Phase 1.5)** — zero new mechanism: a key convention + the Phase-0 grammar. A durable, navigable hub that survives summarization. The single most valuable extra. |
| **Literature vs. permanent notes** (fleeting raw capture → distilled, linked note) | captures = fleeting/literature; observations + knowledge = permanent | **Already our split** — make the "distill a capture into a linked permanent observation" habit explicit in prompting. |
| **Keyword register / index** | the always-on hook index + Phase-1 keyword tag-lines | **Already have / Phase 1.** |
| **Link with a reason** (annotate *why*, not just *that*) | optional trailing text after the token | **Defer** — the relation type already encodes a coarse "why"; free-text reasons cost cached-prefix tokens. Revisit only if recall quality needs it. |
| **Folgezettel** (branching sequence ids) | a `follows`/sequence chain | **Skip** — subsumed by `refines`; our ids are uuids, not sequence positions. |
| **Bottom-up emergent structure** (no rigid upfront taxonomy) | links + MOCs over a fixed schema | **Already the design philosophy** — structure lives in content, not the store. |

The meta-lesson: a Zettelkasten's value comes as much from the **traversal habit** as from creating links. `search_memory(ids:)` is the traversal primitive; prompting the agent to actually follow links and maintain MOCs during a wake is what turns a pile of links into a Zettelkasten — and that habit is free (prompt-only), making it the cheapest high-leverage step after Phase 0. MOCs (Phase 1.5) are the natural next build.

## Explicit non-goals
- In-place rewriting of any episodic capture/observation or knowledge note (breaks convergence + caching).
- A single globally-canonical evolving link graph (we use append-only per-origin links, and prefer recomputed read-time association).
- Any hard dependency on Ollama (every phase degrades to today's deterministic behavior).

## Risks
- **Hallucinated links** — contained by validate-on-read + content-not-graph blast radius.
- **Link → superseded note** — recall follows `supersedesId` / `supersedes` chains forward to the live Head.
- **Prompt budget** — never auto-expand links into the prefix; traversal stays behind `search_memory` / the C1 slot.
- **Over-engineering** — the associative graph is better recomputed than stored; resist Phase 3 until Phase 0 demonstrably falls short.
