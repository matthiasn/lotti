# Better use of embeddings in the planner

- **Status:** Proposed (follow-up; not a 0.9.1017 item)
- **Date:** 2026-06-08
- **Motivates:** Recommendation #2 + open question of the [planner vs. state-of-the-art research note](../research/2026-06-08_long_horizon_planner_vs_state_of_the_art.md), and the observation that we have a full embedding stack but use it in exactly one place.
- **Builds on / feeds:** [Log-search plan](./2026-06-08_planner_log_search.md) (phase 2 upgrades that tool), [Convergence-safe A-MEM plan](./2026-06-08_convergence_safe_a_mem.md) (phase 3 + linking depend on this).

## Current state (grounded)

- **Full stack exists:** `embedding_service`, `embedding_processor`, `sharded_embedding_store` (+ objectbox), `vector_search_repository`.
- **Provider:** Ollama, **local-only** (`POST $baseUrl/api/embed`; throws if the embed model isn't pulled locally). So embeddings are an **opt-in, on-device** capability — absent on mobile/web and on desktop without Ollama.
- **What's embedded:** Tasks / journal entities (on create/update) and agent *reports*.
- **Only live consumer:** `journal_query_runner.dart` — optional semantic search over the journal/task list, gated by `enableVectorSearch` + `VectorSearchRepository` registration.
- **Unused for the planner:** capture transcripts, observations, durable knowledge are **not embedded**, and the planner does **zero** semantic retrieval.

## Hard constraint → design principle

Embeddings are **local-Ollama-only**, but the planner resolves to **cloud** models. Therefore **every** planner feature here must **degrade gracefully** to the deterministic / substring / FTS path when embeddings are unavailable (no Ollama, flag off, model not pulled). Embeddings are an *enhancement*, never a hard dependency — exactly how journal vector search is already optional.

## Convergence note

Embeddings are a **regenerable local cache, not synced authoritative state**: each device embeds its own copy, search is local, nothing enters the append-only synced log. So none of this touches the CRDT/convergence invariants (unlike A-MEM's in-place *evolution*, which does — see the A-MEM plan). Only caveat: comparable vectors require the same embed model across devices, already true.

## Phases

### Phase 1 — Embed agent memory
- Extend `EmbeddingProcessor` to embed `CaptureEntity` transcripts and observation messages (and, for the A-MEM plan, `PlannerKnowledgeEntity` statements), under a distinct namespace/source-type in the sharded store so agent memory and journal vectors don't collide.
- Trigger on create (origin device), best-effort; absence of Ollama → skip silently (no error path that blocks a wake).
- Touches: `embedding_processor.dart`, `embedding_service.dart`, the store's namespacing, wiring in the agent write paths.
- Done when: with Ollama present, new captures/observations get vectors; without it, nothing breaks.

### Phase 2 — Semantic `search_memory`
- Behind the existing `search_memory` tool: when embeddings are available, embed the query and rank by nearest-neighbor over embedded memory; otherwise fall back to the keyword scan from the log-search plan.
- Keep the same `MemoryLogHit` result shape and the same prompt-result formatting, so the tool's contract is unchanged.
- Touches: `_searchMemory` handler (add an optional ranker), a `MemorySearchRanker` seam on the compactor/service.
- Done when: paraphrase queries surface the right folded memory when Ollama is present; identical behavior to keyword search when it isn't.

### Phase 3 — Embedding-ranked knowledge retrieval
- Select the in-scope durable-knowledge **statements** by similarity to the wake context (the day's claims/agreements/plan blocks), not only by exact `category:`/`project:` scope match — so relevant cross-scope knowledge surfaces.
- Slots cleanly into the **C1 layout**: `knowledgeStatements` already live in the *per-wake/volatile* region (after `dayLog`), so non-deterministic similarity selection does **not** evict the `dayLog` prefix. Fallback: scope filter when embeddings absent (today's behavior).
- Touches: `day_agent_context_builder.dart` (`_knowledgeContext`), knowledge service retrieval.

### Phase 4 — Embedding-assisted capture→task matching
- Tasks are **already** embedded, so match a spoken capture phrase to existing tasks by similarity alongside the current FTS5 keyword match in `day_agent_corpus_service.dart` — paraphrase-robust did-you-mean. Fallback: FTS5 only.
- Touches: `day_agent_corpus_service.dart` (`matchToCorpusImpl`).

## Testing
- Each phase: a Ollama-present path and a Ollama-absent fallback path (the fallback path must be the existing deterministic behavior, byte-for-byte where it matters for caching).
- No new flaky/IO: stub the embedding repository; never call a real Ollama in tests.

## Risks
- **Availability skew:** behavior differs with/without Ollama. Mitigate by making the fallback the *current* deterministic behavior, so embeddings only ever *add* recall.
- **Index freshness / backfill:** existing captures/observations won't have vectors until backfilled; semantic recall is partial until then (keyword fallback covers the gap). A one-time backfill is optional.
- **Cost:** local embed calls per memory; batch on the origin device, off the wake hot path.
