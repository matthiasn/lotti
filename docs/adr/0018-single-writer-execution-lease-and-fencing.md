# ADR 0018: Single-Writer Execution via Per-User Lease and Fencing Tokens

- Status: Proposed
- Date: 2026-05-30

## Context

Lotti syncs agent data across devices (Matrix E2EE, vector-clock stamped), so
multiple devices are concurrent writers. Pure log appends converge for free
under CRDT semantics. But *behavior execution* — LLM calls, notifications,
schedule commits, external writes — must not be replicated naively: if two
devices observe the same trigger and both run a behavior, side effects duplicate
and state diverges. The anchor paper leaves multi-agent contention over the
shared graph unresolved.

Today there is **no cross-device coordinator**: `WakeRunner` enforces
single-flight only *in-process* (an in-memory lock map), and
`sync_event_processor_agent_handlers` applies an incoming agent entity/link
unless the *local* vector clock dominates — so `concurrent` writes are applied
by arrival order. Matrix provides causal/eventual delivery, **not** a
linearizable primitive, so a hard lease cannot be assumed for free.

"Vector clock + last-write-wins" must also be applied correctly. A vector clock
can detect true concurrency (which a scalar/hybrid logical clock cannot), so LWW
should apply only on the concurrent branch — and only that branch needs a
tiebreak.

## Decision

1. Separate **facts** (log appends, recorded model/tool responses — replicate
   freely, converge via CRDT semantics) from **execution** (running behaviors
   and their side effects).
2. Side-effecting actions serialize behind a **per-user leader lease + a
   monotonically increasing fencing token**; the resource side rejects any write
   carrying a lower token. A bare lease is insufficient — a paused holder can
   issue a stale write past expiry.
3. Exactly one device executes at a time **while connected to the lease
   coordinator**; others project the resulting events. This is **not** a free
   extension of the in-process `WakeRunner` lock — it requires a real lease
   backend (a designated-primary election with the fencing token persisted in
   synced state, or an external coordinator). **Offline the hard guarantee
   degrades:** a partitioned device cannot know it still holds the lease, so
   during a partition side effects must be **idempotent and reconciled on
   reconnect** (dedupe via content-address; reject stale fencing tokens), not
   assumed-unique. "Exactly one executes" is therefore a connected-case guarantee
   plus an offline reconciliation contract — state both in the backend design.
4. Convergent projection rule: classify each event pair with the vector clock
   (`a_gt_b`/`b_gt_a` honored by replay order; `concurrent` falls to a tiebreak).
   Apply `updatedAt` LWW **only on the `concurrent` branch**. Extend the partial
   order to a single deterministic total order with a replica-independent
   tiebreak: dominance, then a stable `hostId + id` key.
5. Make the LWW comparator a genuine total order: **break equal `updatedAt` by
   `hostId`** (then `id`) so identical timestamps cannot diverge across replicas.
   This is distinct from clock skew: a fast/skewed physical clock wins a
   concurrent branch because its `updatedAt` is strictly greater (the
   equal-timestamp tiebreak never fires), so bounding *that* needs a monotonic
   hybrid logical clock (or bounded drift) on the comparator — not the tiebreak.
6. Keep the vector clock — it detects concurrency, which the human gate needs in
   order to know a real conflict exists. A hybrid logical clock may optionally
   harden the concurrent-branch tiebreak but does not replace the vector clock.

## Execution Topology

```mermaid
flowchart TD
  Lease["Per-user lease + fencing token"] --> A["Device A: runs behaviors + side effects"]
  A -->|append events| Sync["Sync: Matrix E2EE, vector-clocked"]
  Sync -->|union merge| B["Device B: projection only"]
  B -->|no execution without lease| Stop["execution suppressed"]
```

## Consequences

- No duplicated side effects across devices **while connected to the
  coordinator**; under partition, uniqueness degrades to
  *idempotent-and-reconciled* (stale fencing tokens rejected on reconnect). The
  planner commits a schedule in one place in the connected case.
- Convergent, deterministic projection on every device.
- Cost: lease + fencing infrastructure and lease handoff; the secondary `hostId`
  tiebreak must be added before convergence can be claimed.
- Pure log appends remain lock-free.

## Related

- `docs/daily_os_ai_runtime_architecture.md` (§8, Thread G)
- `lib/features/sync/vector_clock.dart`
- `lib/features/agents/README.md` (Wake Orchestration: vector-clock self-suppression)
- Kleppmann, "How to do distributed locking"
- ADR 0001, ADR 0016
