# ADR 0071: Model-Checked Agent Message Log and Compaction

- Status: Accepted
- Date: 2026-09-24

## Context

An agent's message log is a causal DAG replicated across devices (ADR 0016):
each local append chains off the agent's head pointer, concurrent appends on
two devices fork it, and the fork healer joins the heads with a
content-addressed node (ADR 0018 rules 7 and 8). Summary checkpoints fold the
oldest part of the captured input log so a wake reads prose plus a verbatim
tail (ADR 0017, ADR 0020, ADR 0057). The claims were that the DAG stays
acyclic, that joins never storm, that the head never regresses, that the log
eventually has one head, and that checkpoint selection is pure, so devices
converge and no event before a cutoff is ever lost.

Every row syncs on its own — message, `messagePrev` edge, agent-state
version, capture link, payload, checkpoint — once each and in any order, and
the head pointer is a field of the state row, which last-writer-wins
resolves. We wrote the log down in TLA+ as the code stood —
`specs/tla/AgentMessageLog.tla` (two devices, one clock ahead, appends, other
state writes, plan and commit of a join with an append between them, a
crash) and `specs/tla/LogCompaction.tla` (two devices capturing versions of
two sources, folding, late delivery) — and model-checked them with TLC. Five
holes came back as concrete traces:

1. **An unset head rewrote the DAG.** A device appends with no head when its
   state row lags behind the messages it has received, or when a version
   without a head wins last-writer-wins there — one written by a device that
   had not seen any head yet (a wake outcome, a scheduling write). That
   append took the legacy migration path and re-chained every message it
   held by `createdAt`, reusing the `msgprev-<id>` ids appends had written,
   so one edge id named two parents.
   With one device's clock ahead the rewritten edge closed a cycle: TLC's
   trace is six steps (`Acyclic`), and the Glados trace found a six-step
   `EdgesImmutable` violation on the second device's very first append over
   a partly synced chain. Devices then hold different DAGs for good, and a
   cycle makes the projection throw, so fork healing skips that agent for
   good.
2. **A message that arrived before its own edge was joined as a head.** It
   projected as a root, its parent lost its only child, and the healer joined
   a parent with its descendant (`NoJoinOverNonTip`).
3. **A join missing edges was checked only while it was a head with fewer
   than two edges.** A join that had already received a child here, or that
   had two of three edges, left its remaining parents looking like heads.
4. **A late edit disappeared behind a checkpoint.** Coverage was keyed by
   source alone, so another device's edit of a folded source — captured after
   the folded version and before the cutoff, delivered after the fold — was in
   neither the prose nor the tail (`NoLostContext`).
5. **A fold past unsynced content was dead on arrival.** An event whose
   payload had not arrived was dropped from the fold input, the cutoff went
   past it, the checkpoint could not cover it, and every later wake paid for
   the same summary again (`NoDeadCheckpoint`).

## Decision

1. **An unset head is recovered, never re-chained.**
   `AgentSyncService._recoverHead` keeps the legacy spine for logs with no
   DAG evidence at all (no `messagePrev` edge, no message minted with a
   `prevMessageId`, no join); any other log keeps its edges, and the append
   chains off the last head of the projected log that no present row names
   as its `prevMessageId`. A log that no longer
   projects starts the message as a root and logs the failure.
2. **The healer waits for every edge it can prove is missing.**
   `ForkHealer._hasUnsyncedEdge` treats the view as incomplete while a
   message's `prevMessageId` names a present row but its edge has not
   arrived, or while any join — head or not, however many edges it has —
   misses edges its content-addressed id says lead to present heads. A
   `prevMessageId` naming an absent row does not block: the observation sweep
   deletes the edges into what it prunes.
3. **A checkpoint covers versions, not just sources.** `selectActiveSummary`
   accepts a checkpoint only if, for every payload-backed source, the covered
   digest is that of the source's latest version at or before the cutoff. An
   older version arriving late still does not invalidate it.
4. **A fold stops before the first event it could not resolve.**
   `AgentLogCompactor` folds only the resolved part of the tail that precedes
   the first unresolved event; if that is empty, it does not fold.
5. **The models gate the code**, as in ADR 0065: the specs live in
   `specs/tla/`, CI model-checks them whenever they or the code they describe
   change, and Glados traces drive two real `AgentSyncService` + `ForkHealer`
   replicas through generated appends, state writes, heals and deliveries,
   and `selectActiveSummary` through generated histories, checking the same
   invariants.

## Consequences

- `Acyclic`, `EdgesImmutable`, `NoJoinOverNonTip`, `Converged` and
  `LocalHeadAdvances` hold for two devices with a skewed clock, any delivery
  order, a stale state write, and a join planned before and committed after
  an append — `appendJoin`'s existing head guard is what keeps that last race
  from moving the head back; `EventuallySingleHead` holds under fair delivery
  and healing with a crash between plan and commit. `NoLostContext`, `NoDeadCheckpoint` and `Converged` hold for two
  devices folding concurrently over late captures, payloads and checkpoints.
  Each switch set back to the old code reproduces its hole.
- An append over an unset head reads the agent's messages and their
  `messagePrev` edges once, as the legacy migration already did. It happens
  only while the synced head is unset.
- A device holding a checkpoint but not the version it folded treats that
  checkpoint as invalid until the version arrives: its own older version
  might as well be a newer edit. The tail is longer for that while.
- A fold can cover less than planned while content is still syncing.
- Residuals, documented in `specs/tla/README.md`:
  - **The head pointer can still move back.** A state version written on
    another device can win last-writer-wins with an ancestor of the local
    head; the next append then forks off it and the next wake joins the
    fork (TLC: `HeadNeverRegresses` fails in six steps). Fork healing is off
    by default, so such a fork can stay. Closing it needs either a
    DAG-aware merge of the head on receive or a check, on every append, that
    the head has no child yet.
  - **A join row does not name its parents.** A join still missing the edge
    to a parent that is not a head here — one that has not arrived, or has
    another child — cannot be told from a parent the observation sweep
    deleted, so the healer may join again over that join's parents. The
    result is a redundant node, not a cycle. The same holds while more than
    twelve other heads make the subset search too costly to run on every
    wake. Carrying the sorted parent ids on the join row would close both,
    at the cost of a new synced field.
  - **The legacy spine assumes one legacy log.** Two devices whose first
    appends each met a different set of edge-less roots can write different
    spines. This needs three devices appending their first message
    concurrently and is not modelled.

## Related

- `specs/tla/AgentMessageLog.tla`, `specs/tla/LogCompaction.tla`,
  `specs/tla/README.md`
- [Agent memory and log compaction](../../knowledge/features/agents/memory-and-compaction.md)
- [Projection kernel](../../knowledge/features/agents/projection.md)
- [ADR 0016: Agent state as log projection](./0016-agent-state-as-log-projection.md)
- [ADR 0017: Deterministic log compaction](./0017-deterministic-log-compaction.md)
- [ADR 0018: Convergent multi-device execution](./0018-convergent-multi-device-execution.md)
- [ADR 0020: Agent input capture](./0020-agent-input-capture.md)
- [ADR 0057: Decade-scale agent memory](./0057-decade-scale-agent-memory.md)
- [ADR 0066: Model-checked agent wakes and confirmations](./0066-model-checked-agent-wakes-and-confirmations.md)
