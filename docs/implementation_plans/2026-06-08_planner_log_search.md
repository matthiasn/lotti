# Planner Log Search — `search_memory` recall tool

- **Status:** In progress (this plan is implemented in the same change)
- **Date:** 2026-06-08
- **Motivates:** Recommendation #1 of the [planner vs. state-of-the-art research note](../research/2026-06-08_long_horizon_planner_vs_state_of_the_art.md) — give the agent a tool to reach back into folded-away detail, the standard mitigation for **summarization drift** (Anthropic context-engineering; LCM-style "keep the original, recall on demand").
- **Builds on:** [ADR 0017](../adr/0017-deterministic-log-compaction.md) (the immutable log is retained as ground truth; only the *prompt* sees `summary + tail`).
- **Related:** [Planner embeddings plan](./2026-06-08_planner_embeddings.md) (the semantic upgrade), [Convergence-safe A-MEM plan](./2026-06-08_convergence_safe_a_mem.md).

## Problem

The planner's per-wake prompt shows a compacted `dayLog` (summary prose + a short verbatim tail). Detail folded into a summary is **not** in the prompt, so a fact the user mentioned weeks ago can only be paraphrased by the summary — the documented drift failure mode. But ADR 0017 already keeps the **full append-only log** (capture transcripts + observations) as immutable ground truth. We just don't let the agent read it on demand.

## Goal

A `search_memory` tool: the planner passes a keyword/phrase and gets back the matching raw log entries (across all days, including folded ones), most-recent-first, bounded. Keyword (substring/term-AND) matching — **no embedding dependency**, so it works on every platform regardless of whether local Ollama is present. The semantic ranker is a later, optional upgrade (see the embeddings plan) slotted behind the same tool.

## Design

### Cacheability (must not regress)
- The tool **definition** joins the tools list (part of the cached prefix) — a one-time prefix change, then stable. Acceptable.
- Tool **calls/results** are conversation turns *after* the cached user-message prefix, so recall results never invalidate the `dayLog`/knowledge prefix. ✓
- The per-wake assembly path stays **lazy** (the capture-metadata + tail-only resolution from the lazy-capture change). `search_memory` is an **opt-in, occasional** action; it is the *only* place that resolves content beyond the tail, and only when the agent explicitly recalls. The per-wake O(all) load is **not** reintroduced.

### Mechanism — `AgentLogCompactor.searchLog`
The compactor already projects the full `InputEventLog` (`_projectActiveView`) and resolves event content (`_resolveEventContents`, lazy-resolver aware). Add:

```dart
class MemoryLogHit { contentEntryId; at (DateTime); type (capture|observation|…); text; edited }

Future<List<MemoryLogHit>> searchLog(agentId, {required query, int limit = 8})
```

- Tokenize `query` on whitespace → case-insensitive **term-AND** match on each event's searchable text (`content['text']`, else JSON-encoded content).
- Iterate events **newest-first in chunks** (e.g. 50), resolving content per chunk via `_resolveEventContents` and **stopping as soon as `limit` matches are found** — so recent matches don't force resolving the whole multi-year history.
- Return hits with id + position timestamp + type + text + edited flag.
- Lives on the shared compactor, so it benefits any long-lived agent, not just the planner.

### Tool wiring (planner)
- `day_agent_tool_names.dart`: `searchMemory = 'search_memory'`; add to `foundationHandlerTools` (→ routed through the workflow handler, like `set_next_wake`); `isSearchMemoryTool`.
- `day_agent_tools.dart`: definition — `query` (required string), `limit` (optional int, clamped 1–20).
- `day_agent_workflow.dart`: `_searchMemory` handler builds a compactor with the same capture inline-events + `_resolveCaptureContent` resolver the wake uses, calls `searchLog`, formats the hits into a tool-result string (or "no matches"); dispatch branch in `_executeToolHandler` before the `set_next_wake` arm; one system-prompt tool line ("recall specific past detail folded out of the summary").
- `_isToolEnabled` already returns `true` for non-service tools → always available.

## Phases
1. `MemoryLogHit` + `AgentLogCompactor.searchLog` (chunked newest-first, bounded) + unit tests (match across folded + tail, term-AND, case-insensitive, limit, recency order, resolves deferred capture content).
2. Tool name + definition + workflow handler + dispatch + system-prompt line.
3. Workflow dispatch test (search_memory returns formatted hits; empty-query rejected; no-match message).
4. `fvm dart format` + `fvm flutter analyze` clean; targeted tests green.

## Done when
- The planner can call `search_memory` mid-wake and receive matching raw log lines spanning folded history, bounded and most-recent-first.
- The per-wake assembly path is unchanged (still lazy); search is the only on-demand full-content reader.
- No CHANGELOG entry (an agent-internal capability with no direct user-visible surface).

## Out of scope (future)
- **Semantic ranking** (embed the query + NN over embedded memory) — [embeddings plan](./2026-06-08_planner_embeddings.md), phase 2; slots behind this same tool with substring fallback.
- Time-range / by-day filters and pagination — add only if the agent needs them.
