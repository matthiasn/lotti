# ADR 0026: Author-Time Memory Links (Convergence-Safe A-MEM)

## Status

Accepted (2026-06-09)

## Context

The agent memory substrate is an **append-only**, content-addressed event log
that compacts deterministically (ADR 0016/0017) and converges across devices by
LWW + vector clocks (ADR 0018). A-MEM (Xu et al. 2025, arXiv:2502.12110)
proposes giving a self-learning agent an interconnected memory network — note
construction (attributes), dynamic linking, and memory *evolution* (rewriting
old notes). A-MEM realizes all three in a **mutable store**, which is exactly
what our invariants forbid: in-place rewrites break append-only set-union,
make the compaction fold non-reproducible, and invalidate the prompt
prefix-cache on every edit.

The critique behind A-MEM — "a rigid append-log is poorly suited to a
self-learning agent" — is about the *store*. The escape hatch is that the
**content** of each immutable note is free text we already author and sync, so
we can move the plasticity A-MEM gets from a mutable graph into note content
without touching structure. We want associative linking and "new versions of
memories" with zero violation of append-only / convergence / cache stability,
and with no hard dependency on local embeddings (Ollama).

## Decision

1. **Links live in note content, not in a schema or a mutable graph.** A note
   (an observation, or a durable-knowledge statement) may cite a related entry
   inline as `[[relation:id]]`. The vocabulary is **closed** —
   `refines` / `supersedes` / `contradicts` / `relates` — so handling is
   deterministic and specific relations can map onto existing mechanisms. The
   token is plain content of an append-only entry: it never mutates history,
   never enters the cached prompt prefix, and is convergent because the cited
   `id` is the synced entity id the agent saw in the log.

2. **Two flavors of linking, kept separate.**
   - *Frozen author-time links* (text in the note) — deliberate, durable
     relationship assertions the agent makes with intent.
   - *Live read-time association* — recomputed against the current query at
     read time via the `search_memory` recall tool, never stored. This is
     strictly fresher than a baked graph and costs zero storage / convergence.

3. **Resolution is a pure projection** (`lib/features/agents/memory/memory_links.dart`):
   `parseMemoryLinks` (tolerant, closed-vocab, de-duplicating) +
   `resolveMemoryLinks`, which validates a target's *existence* against the
   known log ids (plus caller-supplied `extraKnownIds` — e.g. durable-knowledge
   keys, so a cross-tier link resolves) and forward-follows a supersession
   chain (cycle-guarded) to the live version. A `supersedes` link is **never**
   forward-followed — its whole purpose is to name the *old* entry.

4. **Recall is the traversal primitive.** `search_memory`
   (`AgentLogCompactor.searchLog` / `resolveByIds`, wired in
   `DayAgentWorkflow._searchMemory`) takes a `query` (keyword) or `ids` (follow
   a link). It scans the **full** immutable log newest-first, lazily and
   bounded, attaching each hit's validated outgoing links and a
   `supersededByEntryId` flag. The system prompt instructs the agent to author
   links and to actually follow them.

5. **Maps of Content.** A `propose_knowledge` entry keyed `moc-<topic>` whose
   statement curates `[[relates:id]]` links is a durable, navigable hub
   (Zettelkasten) — zero new mechanism, just a key convention over the grammar.

## Consequences

- **Convergent.** Author-time tokens are content of append-only events
  (set-union). A cited id is a synced entity id, so links converge; a
  not-yet-synced target renders as a dead link and self-heals on sync; a
  hallucinated id resolves to "not found" and is **never** followed or
  fabricated.
- **Cache-safe.** Tokens add a few bytes to content the prompt already
  includes (append-only additive). Validation/expansion happens only in
  `search_memory` tool turns (after the cached prefix) or the volatile
  retrieval slot — never in the `dayLog` prefix.
- **Best-effort forward-follow.** A non-`supersedes` link to a superseded
  target only jumps to the live version when that superseder was within the
  recall scan window; otherwise it renders at its original (still-valid) id.
  This is presentation-only (transient tool output, never persisted), so the
  bound is acceptable.
- We get A-MEM's *expressiveness* (rich notes + links) without its *mutable
  store*. The cost: no single globally-canonical evolving graph — we use
  append-only per-origin links plus recomputed read-time association. Weaker
  than A-MEM's one network, but safe.

## Non-goals

- In-place rewriting/evolution of any episodic capture/observation or
  knowledge note (breaks convergence + caching). "Evolution" is realized only
  as append-only supersession.
- A single canonical, mutable link graph.
- A stored `knowledge_link` `AgentLink` edge set — deferred as a last resort,
  only if the text convention proves insufficient.
- Any hard dependency on Ollama; the substring recall + text links work on
  every platform. Semantic recall (embeddings) is a later, optional upgrade
  behind the same tool.

## Related

- ADR 0016 / 0017 (append-only input-event log + deterministic compaction —
  the recall reader is documented there), ADR 0018 (convergent multi-device
  execution), ADR 0022 (long-lived Daily OS planner durable knowledge).
- Plans: `docs/implementation_plans/2026-06-08_convergence_safe_a_mem.md`
  (Phases 0/1/1.5 implemented; 2/3/4 proposed),
  `2026-06-08_planner_log_search.md`, `2026-06-08_planner_embeddings.md`.
- Code: `lib/features/agents/memory/memory_links.dart`,
  `lib/features/agents/sync/agent_log_compactor.dart`,
  `lib/features/daily_os_next/agents/workflow/day_agent_workflow.dart`.
