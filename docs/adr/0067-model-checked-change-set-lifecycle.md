# ADR 0067: Model-Checked Change-Set Lifecycle

- Status: Accepted
- Date: 2026-09-24

## Context

[ADR 0066](./0066-model-checked-agent-wakes-and-confirmations.md) made
confirming one item of a change set safe on one device: a confirm claims the
item in a transaction before it dispatches. But a change set is more than one
item on one device. It is one synced row that several writers change — a
failed dispatch reverts or auto-retracts its item, a created follow-up task
rewrites its migration's `targetTaskId`, a rejected follow-up cascades to its
migrations, the agent retracts stale items and consolidates older sets — and
every device that shows it edits it.

Only the claim was a transaction. Every other writer read the whole set,
awaited, and wrote the whole set back; sync compared a received set against a
read of the local row taken before its write; and the resolver settled two
concurrent versions of the set by picking one of them whole (the
last-writer-wins timestamp of a change set is its `createdAt`, which never
changes, so the canonical clock order decided).

We modelled all of it in `specs/tla/ChangeSetLifecycle.tla` — two devices,
up to three items, sync as messages delivered in any order — and TLC
returned five holes:

1. **A failed dispatch put back a sibling's claim.** Item A's dispatch failed
   and its revert read the set; item B was claimed and applied; the revert
   wrote its copy back, putting B to pending. A retry applied B again. The
   auto-retraction of a non-retryable failure, the migration cascade and a
   staged retraction had the same shape.
2. **The sibling rewrite put back a migration's claim.** A created follow-up
   task rewrites its migration's target in the set. The migration, resolvable
   from the service's memory before the rewrite lands, could be claimed and
   applied in between — and the rewrite put it back to pending.
3. **A consolidated copy claimed a change that never landed.** A wake folding
   an older set into the survivor copied a claimed item with its status,
   `confirmed`; the claim's dispatch then failed and reverted the original,
   and the copy went on saying the change was applied.
4. **Sync dropped decisions made concurrently on two devices.** One device
   confirmed an item, another decided a different one; the whole-row winner
   discarded one device's decision, and an applied change read pending again
   everywhere.
5. **Sync wrote a peer's version over a local claim.** The receive read the
   local row, a local claim committed, and the receive wrote the peer's
   version — which covered the row it had read — over the claim.

Each ends with a change applied twice once the user retries, which TLC shows
in eight or nine steps with every fix removed.

## Decision

1. **Every local write of a set is one transaction that changes only what it
   owns.** `ChangeSetResolutionStore.transitionChangeSetItem` moves one item
   from an expected status to a new one on a fresh read, in one transaction;
   the claim is its `pending` case, a failed dispatch reverts or retracts
   only an item still `confirmed`, a reopen moves only an item still holding
   the decision it read (and neutralises the verdict in the same
   transaction), and the cascade claims each migration like a user
   rejection. The sibling rewrite and the staged retraction re-read and write
   in one transaction.
2. **Every change of an item bumps its revision.** `ChangeItem.revision`
   counts the item's status and argument changes; every writer uses
   `withStatus` / `withArgs`.
3. **Concurrent versions of a set merge item by item.**
   `resolveIncomingChangeSet` keeps, for each index, the version that changed
   the item last (higher revision); at the same revision the more final
   status wins — a confirm took effect, so it beats a concurrent rejection or
   retraction, and any decision beats pending. Items only one version
   appended are kept, the set status is derived, and the vector clock is the
   join, so both devices converge on one row without another write. Versions
   that disagree on which proposal an index holds, or a tombstone, fall back
   to the whole-row winner.
4. **Sync applies a received set in one transaction** over a fresh read of
   the local row (not the bundle's prefetched snapshot).
5. **Consolidation moves only pending items.** A decided item stays in the
   set it was decided in; only pending items are shown, so the card looks the
   same.
6. As in ADR 0065 and ADR 0066, the model gates the code: CI model-checks
   every configuration, and a Glados trace in the confirmation service's suite
   drives the real services through generated interleavings of writers and
   read deliveries, checking the model's invariants.

## Consequences

- `AtMostOnceApply`, `AppliedStaysDecided`, `StatusMatchesEffect`,
  `Converged` and `MigrationAfterTarget` hold for one device with a
  follow-up task, its migration and a plain item under every interleaving of
  its writers, and for two devices syncing through messages in any order, as
  long as no item is decided on both devices before they sync.
- Rows gain an item `revision` field. Older clients ignore it and drop it
  when they rewrite a set; a concurrent merge with such a write falls back to
  the status rank.
- Residuals, documented in `specs/tla/README.md` and each confirmed by TLC:
  - **The same item decided on two devices before they sync** is applied on
    both. The replicas converge, but no local transaction can prevent the
    second apply. Closing it needs coordination — one device that applies a
    set's changes, a lease on the item, or tools idempotent per decision id —
    which is a product decision.
  - **Consolidation on one device racing a decision on another** leaves a
    pending copy of an item the other device applied. Closing it needs the
    copy to carry a link to its original, checked before the copy is
    claimed, or consolidation that groups sets for display instead of copying
    rows.
  - The ADR 0066 residuals stand: a tool that throws after its effect landed,
    and a crash between the claim and the dispatch.

## Related

- `specs/tla/ChangeSetLifecycle.tla`, `specs/tla/ChangeSetConfirm.tla`,
  `specs/tla/README.md`
- [Task agents](../../knowledge/features/agents/task-agents.md)
- [Vector clocks and conflict resolution](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
- [ADR 0006: Change-set deferred tool confirmation](./0006-change-set-deferred-tool-confirmation.md)
- [ADR 0066: Model-checked agent wakes and confirmations](./0066-model-checked-agent-wakes-and-confirmations.md)
