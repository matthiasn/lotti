# `messagePrev` Wiring + Shadow Projection — Implementation Plan (PR 3)

- Status: Plan · Date: 2026-05-30
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (PR 3).
- Design baseline: [`../daily_os_ai_runtime_architecture.md`](../daily_os_ai_runtime_architecture.md) §8; [ADR 0016](../adr/0016-agent-state-as-log-projection.md).
- Depends on: **PR 1** (projection kernel, merged) and **PR 2** (deterministic order). Unblocks **PR 4** ([state-as-projection](./2026-05-30_state_as_projection_plan.md)) and ADR 0020 (input capture), both of which assume a real causal DAG.

## Goal

Two workstreams:

1. **Populate the causal edges.** `prevMessageId` / `AgentLink.messagePrev` are
   *declared but created nowhere* — messages persist without a parent, so the
   "log is a DAG" is only notional. Stamp each newly-persisted message with its
   causal parent so the forward log becomes a real DAG.
2. **Shadow projection.** Add the `AgentEvent.fromMessage` / `fromLink` adapter
   (deferred from PR 1) and compute `project(canonicalOrder(...))` **alongside**
   the live mutable rows, asserting equality on the corpora where it must hold.
   **No reads flip** — that is PR 4.

## What we confirmed about the ground truth

- **No DB schema migration.** `agent_entities` stores each entity as a
  `serialized TEXT` JSON blob (only `id`/`agent_id`/`type`/`thread_id`/timestamps
  are promoted columns). `prevMessageId` already lives inside that JSON, and
  `messagePrev` is a variant of the existing `agent_links` table. Populating both
  is *data*, not schema.
- **~18 append sites.** Messages are constructed inline in
  `task_agent_workflow`, `project_agent_workflow`, `day_agent_workflow`, and each
  of their `*_strategy` files, then persisted via `agent_repository.upsertEntity`.
- **Head is already tracked.** `AgentStateEntity.recentHeadMessageId` is the
  current head; appends advance it.

## Edge-population design

- **Centralize, don't sprinkle.** Add one `appendMessage` chokepoint (in the
  repository or a thin service) that, given a message without a parent, stamps
  `prevMessageId` = the agent's current head and creates the `messagePrev` link,
  then advances the head. Refactor the ~18 construction sites to call it. Setting
  the edge at 18 call sites is the main correctness risk; a single chokepoint
  removes it.
- **Parent rule.** Parent = the running head *within the wake* (so several
  messages appended in one wake form a chain), seeded from
  `recentHeadMessageId`. First message of a brand-new agent = root (no parent).
- **Forks/joins.** Concurrent multi-device appends off one head produce a fork
  (≥2 heads) — legal and expected; the projection is multi-head tolerant. A wake
  that resumes after a sync delivered a concurrent branch may either pick one
  head (fork persists) or emit a join (multiple parents). PR 3 picks the simple
  rule (parent = local head) and leaves join emission to PR 6.
- **`hostId` sourcing (resolves the PR 1 open item).** Stamp the authoring host
  into the message JSON on new appends (local host from `VectorClockService`;
  `originatingHostId` is already on the sync envelope, per PR 2). The adapter
  sets `AgentEvent.hostId` from that field, falling back to `id`-only tiebreak
  when absent (legacy rows) — deterministic either way.

## Adapter + shadow harness

- `AgentEvent.fromMessage` / `fromLink`: map a persisted message + its
  `messagePrev` links onto the kernel's `AgentEvent` (id, hostId, vectorClock,
  causalParents, kind).
- Shadow compare: for a given agent/thread, build the `AgentEvent` set, run
  `project(canonicalOrder(...))`, and compare against the live mutable state
  (head pointer, latest report). Surfaced as a diagnostic/assert in tests and
  (optionally) a debug-only runtime check — **never** drives a read.

## Risks & migration — existing task / project / Daily-OS agents

This is the load-bearing section: there are already live agents with populated
logs and `AgentStateEntity` rows across multiple synced devices. The arc to
"the agent is the log" (PR 3 → PR 4 → PR 5) must not corrupt or strand them.

### PR 3

- **R1 — Legacy messages have no edges, so the projection ≠ live state over
  history.** Every pre-PR-3 message has `prevMessageId = null` and no
  `messagePrev` link. The kernel treats them all as roots → `headIds` = *every*
  legacy message, ordered by `(hostId, id)` ignoring `createdAt`. Live state, by
  contrast, has one `recentHeadMessageId` (last by arrival). **Shadow-equality
  cannot hold over flat legacy history** — and that is expected, not a bug.
  *Mitigation:* scope PR 3 shadow-equality to **forward activity** (messages
  appended after rollout / after a baseline checkpoint), and to fresh agents in
  tests. Do **not** assert that flat legacy projects identically. See the
  baseline-event primitive below.
- **R2 — `recentHeadMessageId` is single-valued; the kernel is multi-head.**
  Even forward, a concurrent multi-device append yields ≥2 heads while live state
  names one. The shadow harness must compare on linear (single-head) corpora and
  treat forks as known, projection-handled divergence — not a mismatch to fix by
  changing the kernel.
- **R3 — ~18 append sites.** Miss one and that message has no parent → a hole in
  the DAG. Mitigated by the single `appendMessage` chokepoint (above); the plan
  enumerates the files so none is missed.
- **R4 — Mixed-version sync during rollout.** A PR-3 device writes `messagePrev`
  links + `prevMessageId`; an old device keeps appending *without* edges and
  round-trips the new link rows harmlessly (the `messagePrev` variant already
  exists in the deployed model; unknown JSON fields are ignored). Net: additive,
  no break — but the forward DAG has gaps from old-device activity until all
  devices upgrade. The kernel already treats dangling/absent parents as roots, so
  it **degrades gracefully**; flag it, don't block on it.

### PR 4 (flip reads / state → cache) — the real migration

- **R5 — Counters via count-from-log need a baseline.** `wakeCounter`,
  `totalSessionsCompleted`, etc. were maintained imperatively. Recomputing them
  by counting log events would drop history if not every past event is retained.
  *Migration:* seed each counter from the **current `AgentStateEntity` value** as
  an offset and count forward — never recompute from zero.
- **R6 — Unrecoverable slot values.** Any slot only ever stored on
  `AgentStateEntity` (a watermark never emitted as an event) is *lost* if we
  naively derive from the log. This is the strongest reason for the baseline
  primitive below.
- **R7 — Reads change for in-flight agents.** Flipping reads could alter what an
  existing agent sees as head/state mid-life. Mitigated by the PR 4 model
  (synced cache stays, log authoritative, reconcile-on-wake) + the baseline:
  continuity is preserved, divergence self-heals.

### PR 5 (compaction)

- **R8 — First compaction of a large existing log is expensive** and needs the
  edges/baseline from PR 3/PR 4. Forward-looking; not a PR 3 blocker.

### The unifying migration primitive — per-agent baseline checkpoint

Emit **one append-only "state baseline" checkpoint per existing agent** (at the
PR 3→PR 4 boundary, where it is first needed) capturing today's truth: the head
pointer, counters, and slot values. Then **projection = baseline + forward DAG**.
This single primitive neutralizes R1, R5, R6, R7:

- legacy flat messages are *covered* by the baseline and not re-folded, so
  shadow-equality is cleanly scoped to forward activity;
- counters seed from the baseline (no zero-reset);
- slot values not otherwise reconstructible are preserved verbatim;
- no mass backfill of historical edges is required (cheaper and less fragile than
  rewriting every old message's parent).

Optional, only if full historical replay is ever wanted: a one-time **edge
backfill** chaining legacy messages per thread by `(createdAt, id)`. Deferred —
the baseline makes it unnecessary for correctness.

## Test plan

- **Adapter** — `fromMessage`/`fromLink` map fields correctly (example + a Glados
  round-trip on synthetic rows).
- **Shadow equality (forward corpus)** — append a sequence through the real
  workflows; assert the projection's head/report equals live state. Include a
  fork case asserting the projection yields the expected multi-head set while
  live state tracks one (documents R2, not a failure).
- **Edge population** — every message persisted via the chokepoint carries a
  parent; first message is a root; in-wake chains link correctly.
- **Mixed-version tolerance** — a message with a dangling/absent parent projects
  without crashing (kernel root behavior).
- Reuse the PR 1 two-device convergence harness for the cross-device cases.

## Acceptance criteria

- Analyzer/format clean; new pure logic property-tested with `tags: 'glados'`.
- Every message persisted post-PR-3 carries a causal parent edge.
- Shadow projection matches live state across the **forward** corpus; legacy
  divergence is documented and scoped, not asserted away.
- No read path consumes the projection yet (verify: only the shadow harness/tests
  import the adapter output).
- No DB schema migration (confirmed: serialized JSON + existing links table).

## Open decisions

- **Baseline checkpoint timing** — emit in PR 3 (anchors shadow scoping) vs. PR 4
  (where reads actually need it). Leaning PR 4, with PR 3 shadow scoped to fresh
  agents/forward corpora.
- **Authoring-host persistence** — add an explicit host field to the message JSON
  going forward (cheap, no schema migration) vs. rely on `originatingHostId` +
  `id`-only fallback. Leaning explicit field for a clean `(hostId, id)`.
- **Join-on-resume** — pick-one-head (defer joins to PR 6, recommended) vs. emit
  joins now.
