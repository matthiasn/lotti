# ADR 0099: Agent Link Slots Rank Every Assignment

- Status: Accepted
- Date: 2026-09-27
- Closes a residual of: [ADR 0081](./0081-model-checked-evolution-sessions-and-agent-links.md)

## Context

A template shows one soul (`soul_assignment` links, keyed by the template in
`from_id`) and one improver (`improver_target` links, keyed by the template in
`to_id`). Partial unique indexes admit one live link of each per template.
Every assignment is written under a fresh link id.

To keep that index satisfied, `AgentRepoLinks.upsertLink` handed the slot
over: writing a live assignment, locally or from sync, tombstoned the slot's
other live rows in place, with no clock bump and no sync message, and
hard-deleted any row with the same `(from_id, to_id, type)` under another id.
Two devices that reassigned one template concurrently each received the
other's assignment, and each arrival tombstoned the local one. Device A ended
up with B's soul and B with A's until the next assignment. ADR 0081 recorded
this as a residual. A copy of `specs/tla/AgentLinks.tla` with the handoff
found the swap, and the fix needed a decision between three options:

1. One deterministic link id per slot, which makes the assignment a register.
   That needs a migration of every existing link id and a plan for older
   clients that keep writing fresh ids.
2. A slot rule every replica applies the same way: keep every assignment,
   rank them by `(createdAt, id)` over all the versions known, and have
   writers clamp `createdAt`.
3. Emit the handoff's tombstones as synced writes. Two devices would then
   each remove the other's assignment, and the template could end up with no
   soul at all.

## Decision

**The slot rule (option 2).** A slot link is stored as it arrived, like any
other link. The slot shows the live link ranked first by `createdAt`, then id.
That is `AgentLinkSelection.orderedPrimaryFirst`, which every other
primary-link read already used. Nothing about the ranking is written as a
version, so replicas that hold the same versions show the same assignment in
any arrival order. It needs no migration of link ids, and an older client
still writes links the rule understands.

1. **`AgentLinkSlot` names the two slots** (`soul(templateId)`,
   `improver(templateId)`, `AgentLinkSlot.of(link)`).
2. **The repository re-ranks the slot after each write.** In one
   transaction, `AgentRepoLinks.upsertLink` reads every row of the slot,
   decodes the serialized versions, and picks the winner among the live ones.
   The winner gets `deleted_at IS NULL`. A live loser keeps its serialized
   version, but its SQL `deleted_at` column is set, so every read that filters
   `deleted_at IS NULL` skips it. Losers are hidden first and the winner is
   shown last, so the partial unique indexes hold throughout. Sync reads the
   serialized version (`getLinkByIdIncludingDeleted`, the interval reads), so
   a hidden link is sent on as the live version it is, and the receiver ranks
   it the same way.
3. **Nothing is hard-deleted.** Schema v22 exempts `soul_assignment` and
   `improver_target` from `idx_agent_links_unique_from_to_type`. Two
   concurrent assignments of one soul share a natural key under different ids,
   and every replica keeps both.
4. **A reassignment outranks what it replaced.** For a new slot link,
   `AgentSyncService.upsertLink` moves `createdAt` 1 µs past the newest link
   of the slot this device holds, tombstones and hidden links included. It
   does this only when the wall clock is not already later. Without that step,
   a reassignment made in the same instant as the link it replaced, or on a
   clock running behind that link's writer, would rank below it wherever both
   are live.
5. **Writers clear the whole slot.** `SoulTemplateOps.assignSoulToTemplate`
   and `unassignSoul` tombstone every live assignment `getSlotLinks` returns,
   hidden ones included. A concurrent assignment ranked below the visible one
   therefore does not appear when the user removes or replaces the soul.

The TLA+ model carries the handoff behind a switch. `AgentLinks.tla` gains
`Slot` (two fresh-id assignments of one slot), `SlotRule` and
`ClampCreatedAt`, the invariants `SlotConverged` and `SuccessorOutranks`, and
the configurations `AgentLinksSlot` and `AgentLinksSlotLossy`.

## Consequences

- `SlotConverged`, `Converged`, `NoLostSuccessor` and `SuccessorOutranks`
  hold for a slot on three replicas. This covers every arrival order, and in
  the lossy configuration any delivery lost and recovered by backfill. With
  `SlotRule = FALSE` (the old handoff), TLC finds the swap in six steps: two
  assignments and four deliveries. With `ClampCreatedAt = FALSE`, it finds a
  reassignment ranked below the link it replaced in two steps.
- The concurrent case now has a deterministic winner: the assignment with the
  later `createdAt`. The other device's choice is kept and hidden, not
  deleted. It shows again only if the winner is removed by a device that had
  not seen it.
- The SQL `deleted_at` column of a slot link now means "hidden from reads".
  It is set for a tombstone and for a live loser. `serialized` is the version.
- Rows that the old handoff tombstoned in place, without a clock, stay
  tombstoned on the device that did it. The next assignment of that template
  converges the slot.
- Schema v22 rebuilds one index. It rewrites no rows.

## Related

- [ADR 0081](./0081-model-checked-evolution-sessions-and-agent-links.md): the
  agent link order and the residual this closes
- `specs/tla/AgentLinks.tla`, `specs/tla/README.md`
- [Agent persistence and sync](../../knowledge/features/agents/persistence-and-sync.md)
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
