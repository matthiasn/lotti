# Convergence-safe A-MEM for the durable-knowledge tier

- **Status:** Proposed (follow-up; A16-adjacent, not a 0.9.1017 item)
- **Date:** 2026-06-08
- **Motivates:** Finding #8 + the open question of the [planner vs. state-of-the-art research note](../research/2026-06-08_long_horizon_planner_vs_state_of_the_art.md) — adopt the parts of A-MEM (Xu et al. 2025, [arXiv:2502.12110](https://arxiv.org/abs/2502.12110)) compatible with our append-only, convergent, cache-stable architecture.
- **Depends on:** [Planner embeddings plan](./2026-06-08_planner_embeddings.md) (linking needs embeddings), the weekly ritual (A16, deferred), [ADR 0018](../adr/0018-convergent-multi-device-execution.md) (convergence), [ADR 0022](../adr/0022-long-lived-daily-os-planner.md) (durable knowledge).

## A-MEM's three mechanisms vs. our invariants

| A-MEM mechanism | What it is | Verdict for us |
|---|---|---|
| **Note construction** | LLM-generated attributes (keywords, tags, contextual description) per memory | **Adoptable** — compute once at origin, store immutably, sync as content |
| **Dynamic link generation** | Embed a new note, link to top-k similar historical notes | **Adoptable, scoped** — append-only origin-generated links (set-union) |
| **Memory evolution** | Integrating a new note **rewrites** existing notes' attributes in place | **Incompatible** with the episodic stream — see below |

### Why in-place evolution is a non-goal for the episodic stream
Rewriting historical entries breaks all three load-bearing invariants at once:
- **Convergence (ADR 0016/0018):** the model is append-only set-union + deterministic fold. Two devices independently LLM-rewriting the same note are concurrent, non-deterministic mutations — LWW picks one arbitrarily, so "evolved" memory diverges per device. There is no convergent merge for "two different AI rewrites of one note."
- **Deterministic compaction (ADR 0017):** the `dayLog` is a reproducible fold of *immutable* events; mutating events makes the fold non-reproducible and non-append-only.
- **Prefix cache:** mutating historical content changes the prompt prefix → cache invalidation on every evolution.

So evolution is applied **only** as append-only supersession (below), never as in-place rewrite, and **never** to the episodic capture/observation log.

## The convergence-safe variant (durable-knowledge tier only)

Apply construction + linking to `PlannerKnowledgeEntity` (user-gated, low-frequency, already where we accept richer organization), and approximate evolution with mechanisms we already have.

### Phase 1 — Note construction (attributes)
- At confirm time, on the confirming device, derive `keywords` / `tags` / a short `contextDescription` for the entry (one small LLM call) and store them as **immutable** fields on the entity (set once, synced as content — never recomputed per replica).
- Touches: `agent_domain_entity.dart` (`PlannerKnowledgeEntity` fields + codegen), `day_agent_knowledge_service.dart` (confirm path), conversions/LWW (additive fields).
- Fallback: if the attribute call fails / no model, store the entry without attributes (degrade to today's behavior).

### Phase 2 — Dynamic linking
- Embed each confirmed entry (embeddings plan phase 1/3), nearest-neighbor over confirmed entries, write a new **`knowledge_link`** `AgentLink` to the top-k.
- **Convergence:** generate links **at origin, append-only** (set-union of links across devices), treated as additive hints — not one canonical evolving graph. A note created on device B links to B's then-visible set; A's links coexist. Converges; slightly weaker than A-MEM's single network, but safe.
- Touches: `agent_link.dart` (+ `knowledge_link` type), knowledge service (link on confirm), repository (link reads).

### Phase 3 — Link-aware / similarity retrieval
- Retrieve in-scope statements by similarity to the wake context and **follow links** to bring in related entries (embeddings plan phase 3). Fits the C1 volatile slot, so no `dayLog`-prefix cost. Fallback: scope filter.
- Touches: `day_agent_context_builder.dart`, knowledge service.

### Phase 4 — Evolution-as-supersession (A16-gated)
- Replace A-MEM's in-place rewrite with: at the weekly one-on-one ritual (A16), the agent *proposes* a consolidated/refined note that **supersedes** related entries via `supersedesId` (append-only, recency-wins, user-confirmed). This is the convergence-safe analog of "memory evolution": old notes stay immutable, a new note wins the Head.
- Touches: the weekly-ritual wiring (A16), knowledge service supersession (already exists), the "What I've learned" panel (surface proposed consolidations for confirmation).
- Depends on A16 landing first.

## Explicit non-goals
- In-place rewriting of any episodic capture/observation (breaks convergence + caching).
- A single globally-canonical evolving link graph (we use append-only per-origin links instead).
- Making any of this a hard dependency on Ollama (all of it degrades to today's deterministic behavior).

## Done when
- Confirmed knowledge carries origin-computed attributes + embeddings + links; retrieval can surface related (not just exact-scope) knowledge; the weekly ritual can propose supersession-based consolidations the user confirms — all convergent across devices and with no `dayLog`-prefix regression, and all gracefully degrading without Ollama.

## Testing / risks
- Convergence tests: concurrent links + concurrent attribute writes converge (set-union / origin-immutable); a supersession and a concurrent edit resolve per the existing monotonic rules.
- Risk: attribute/link generation cost and Ollama availability — both mitigated by origin-only, off-hot-path generation + graceful fallback. Risk: link-graph quality without evolution — accept weaker-but-safe; revisit only with evidence.
