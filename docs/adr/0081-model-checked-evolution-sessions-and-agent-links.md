# ADR 0081: Model-Checked Evolution Sessions and Agent Links

- Status: Accepted
- Date: 2026-09-25

## Context

Two replicated parts of the agent runtime had no model: evolution sessions
(the 1-on-1s that evolve a template or a soul) and agent links. We wrote both
down in TLA+, `specs/tla/EvolutionSession.tla` and `specs/tla/AgentLinks.tla`,
modelled the code as it was, and model-checked them with TLC. These are the
holes TLC confirmed, each as a concrete trace.

**Evolution sessions.** A session row (`EvolutionSessionEntity`) is resolved
by `updatedAt` last-writer-wins like any agent register. Only the device that
holds the session in memory completes it, and completing it adopts a new
template or soul version. Any device abandons a session it reads as active,
because `startSession` and every approval sweep stale sessions
(`_abandonStaleActiveSessions`). Locally, a session is abandoned only while it
is active, and a completion is written over whatever status the row has.

1. **A sweep beat the approval it had not seen.** The owner approves. The
   peer, not having heard, starts a session a minute later and sweeps this
   one. The two writes are concurrent and the sweep is newer, so every
   replica ends with the session abandoned while its version is in effect.
   The feedback extraction reads an abandoned session as a negative signal
   for the next ritual, and it drops out of the approval rate and the
   last-ritual timestamp. TLC: `CompletedStays` in five steps,
   `AdoptionRecorded` in eight.
2. **An approval that failed part-way left an adopted version behind.** The
   version committed in its own transaction, then the notes, the recap and
   the session row. When one of those failed, the approval returned null with
   the version already active. If the user then left the chat, the session
   was abandoned under its own version (`AdoptionRecorded`: create, fail,
   leave, and the deliveries, seven steps), and
   a crash between the steps left it active until a later sweep abandoned it
   (two steps).
3. **A soul approval retried after such a failure minted a second version.**
   The template path cached the version it had created, but the soul path
   did not (`OneVersion`, three steps: create, fail, create). A failed outbox
   flush after the commit had the same effect: `SoulDocumentService.createVersion`
   threw, the approval returned null, and the proposal stayed for a retry.
4. **The receive of a session row could overwrite an approval.** The receive
   read the row, and an approval that committed before the receive wrote was
   lost on this device. The owner kept the session abandoned while every
   peer held it completed (`CompletedStays`, four steps).

**Agent links.** [ADR 0078](./0078-entry-link-versions-are-ordered.md) found that journal entry links had no version
order at all. Agent links had one: dominance by vector clock, then
`updatedAt`, then the canonical clock. The holes were elsewhere.

5. **A tombstone read as no row.** The receive read the local link with
   `getLinkById`, which filters `deleted_at IS NULL`. Any version that arrived
   after a removal, such as a late copy of the link it removed, replaced the
   tombstone. A replica that received the removal before the link kept the
   link for good (`NoLostSuccessor` in three steps, `Converged` in six).
6. **Backfill could not serve a removal.** The backfill responder read the
   same way, so it answered `deleted` for a removed link. A receiver that had
   lost the removal settled the gap with nothing applied and kept the live
   link (`Converged`, seven steps).
7. **A link written afresh was concurrent with the version it replaced.**
   Writers build links with `vectorClock: null` under reused ids: the Daily OS
   links' deterministic ids, the planner's template assignment, and any link
   removed and written again. `AgentSyncService.upsertLink` stamped only the
   writer's clock and overwrote the row. The trace needs no clock skew: B
   links an item to a task, A removes the link, and B links it again. B's
   clock `{B:2}` is concurrent with A's removal `{A:1, B:1}`, and the
   canonical clock order prefers the removal. A and C keep the removal, and B
   keeps the link. A write stamped earlier than its predecessor also lost to a
   third version its predecessor beat, on a lagging clock (`ClampTimestamp`).
8. **The link receive read and wrote in two steps.** A local write that
   committed in between was overwritten, as in hole 4 (`NoLostSuccessor`,
   seven steps).

Some suspected gaps were not confirmed. A completed session is never
reopened: `active` is written only at creation, and the override keeps
`active` below both terminal statuses. A completed session names one version
once hole 3 is closed. The version rows and their head are
`specs/tla/VersionHeads.tla`, which this model composes with rather than
repeats.

## Decision

1. **A concurrent pair of session rows keeps the more final status:**
   completed, then abandoned, then active. The rule sits in
   `resolveConcurrentAgentEntityOverride` and matches what the writers
   already do on one device. Only the owner completes, completion creates
   the version, and an abandonment is written only over an active row.
   Because the rank never drops along a causal edge, replicas converge in
   any arrival order. That is the `RankDrop` condition of
   [ADR 0068](./0068-model-checked-agent-convergence.md).
2. **An approval is one transaction.** The version, the notes, the recap and
   the completed session row commit together in `approveProposal` and
   `completeSoulSession`, so a failure leaves nothing to repeat or orphan. An
   approval of a session that is already completed returns the version the
   row names instead of creating one. That is the case where a transaction
   committed and then failed flushing the outbox. The template path's
   version cache and its recovery-by-matching-directives
   (`_createVersionIdempotent`) are gone.
3. **A session row is received in one transaction,** as agent state and
   change sets already were.
4. **A link's stored version includes its tombstone.** `AgentRepository.getLinkByIdIncludingDeleted`
   is what the receive, the backfill responder and the backfill verifier
   read. The receive decision is one pure function, `resolveAgentLinkVersions`.
5. **A local link write succeeds the stored version.** `upsertLink` reads it,
   tombstone included, in the write's transaction. The clock covers both
   versions, and `updatedAt` is never older than the stored one, as
   ADR 0068 does for entity registers.
6. **A link is received in one transaction.**

## Consequences

- `Converged`, `OneVersion`, `AdoptionRecorded`, `CompletedStays` and
  `NeverReactivated` hold for three replicas with an owner that crashes and
  writes that lag the clock by one tick. `Converged` and `NoLostSuccessor`
  hold for a link written and removed on three replicas, with any delivery
  lost and recovered by backfill. Each fix, set back to the old behaviour,
  has the counterexample listed above (`specs/tla/README.md`).
- A failed approval now loses the notes it had drained, because they roll
  back with the version. Notes are advisory, and `_persistNotes` already
  accepted that loss for a failure before the commit.
- Every local link write, including every message's `msgprev` edge, costs
  one primary-key read in its transaction.
- A local link write now wins over a removal it never saw, on every replica.
  That was already true on the writing device. The writers are user actions
  and agent tools that mean to set the link.
- Links written before this change can still carry clocks that do not cover
  their predecessors. Such pairs are ordered by `updatedAt` until the next
  write.
- A successor must *strictly* dominate the version it replaces. A host an
  older build created starts at counter 0, and its first write extends the
  stored clock by `host: 0`. That compared *equal* until
  [ADR 0080](./0080-a-present-counter-ranks-above-an-absent-host.md) ranked
  an absent host below 0, and the receive kept the stored version. This
  change relies on ADR 0080 and does not work around it. A regression in
  `agent_sync_service_test.dart` covers a host's first relink and first
  removal over a synced link, for first counters 0 and 1. With ADR 0080's
  compare reverted, the counter-0 case fails.
- Residuals, documented in `specs/tla/README.md`:
  - **Two devices that reassign a template's soul (or an improver's target)
    concurrently swap the assignments.** `AgentRepoLinks.upsertLink` keeps
    one live link per slot. When a live assignment arrives, it tombstones
    the other one locally, without a clock bump or a sync message. A and B
    each receive the other's link and keep it, so A ends with B's soul and B
    with A's, and nothing heals it until the next assignment. The same
    handoff hard-deletes a row that shares the slot's natural key. A copy of
    the model with this handoff (not checked in) finds the swap in five
    steps. The fix changes how an assignment is identified or ordered, so it
    needs a decision. The options are: one deterministic link id per slot
    (`soul_assignment:<templateId>`), which makes the assignment a register
    but needs a migration of existing links and a plan for older clients
    that keep minting random ids; a slot rule every replica applies the same
    way, where the assignment ranked highest by `(createdAt, id)` among
    every version known here, live or not, holds the slot, the writers clamp
    `createdAt` above the slot's, and the unique index admits the derived
    losers; or emitting the handoff's tombstones as synced writes, which
    turns receives into writes.
  - **Agent entities have hole 5 too.** The entity receive reads the local
    row with `getEntity`, which also filters tombstones, and so does the
    backfill of entities. A soft-deleted entity, such as a parsed capture
    item replaced by a re-parse, can come back when a late copy arrives.
    That is the same fix applied to `_resolveIncomingAgentEntity`, the bundle
    prefetch and the entity backfill, and it is left for its own change.
  - **Other entity types still receive in two steps.** Only agent state,
    change sets and evolution sessions are read and written in one
    transaction.
  - **`approveSoulProposal`**, the mid-session soul approval that does not
    complete the session, still creates its version in its own transaction.
    A retry after a failed outbox flush can create a second version.

## Addendum (2026-09-25): agent entity removals stick on every device

Decision from the user: an agent entity that was removed stays removed on
every device, as a removed link does. This closes the residual above,
"Agent entities have hole 5 too", and the one after it, "Other entity types
still receive in two steps".

`specs/tla/AgentReplication.tla` gains a third kind, `"removal"`: a register
removed and written again, whose tombstone (`deletedAt`) is ordered like any
other field. The same model now also loses deliveries and recovers them by
backfill, and can split the receive into a read and a write. Modelled as the
code was, TLC found these holes:

9. **A late copy of the live version replaced a removal.** The entity receive
   read the stored row with `getEntity`, which filters `deleted_at IS NULL`,
   so a removal read as no row (`NoLostSuccessor`, three steps: A writes,
   A removes, A receives its own first version late). A parsed capture item
   replaced by a re-parse, a deleted day plan, template or soul came back.
10. **Backfill could not serve a removal.** The responder, the verifier and
    own-counter settlement read the same way. A device that lost the removal
    was answered `deleted`, settled the gap with nothing applied and kept the
    entity (`Converged`, three steps).
11. **A row written over a removal did not succeed it.** The local write
    resolution read the persisted row with `getEntity` as well. A day plan
    drafted again over a peer's removal carried the drafting host's counter
    alone, concurrent with the removal. With the removal stamped later, the
    peers kept it while the drafting device kept the plan, and a late copy of
    the first version then won over the draft (`NoLostSuccessor`, six steps).
12. **A re-creation was handed the removal back.** Built afresh, because its
    writer reads no row, the draft was resolved against the tombstone as if
    concurrent, and a removal at the same instant or later won
    (`LocalWriteTakesEffect`, two steps).
13. **Every other type was received in two steps,** reading the row (or the
    outbox bundle's prefetched snapshot of it) and writing after an await. A
    local write that committed in between was overwritten
    (`NoLostSuccessor`, eight steps).

Three holes were outside the model's reach and were found by the audit of
every writer that soft-deletes an agent entity:

14. **A removal did not always rank at its own instant.** Last-writer-wins
    orders a concurrent pair by `updatedAt`, or `createdAt` for append-only
    variants. The soul, soul-head and version removals set `deletedAt` alone,
    and an append-only row has no other timestamp to move. A removal then
    sorted with the edit it came after, or tied with it, and the canonical
    clock order could bring the entity back on every device. TLC checks
    convergence either way; this is about which version the devices converge
    on.
15. **A removal of an append-only row was stamped on its snapshot.** The
    local write path resolved only writes to mutable registers against the
    persisted row. A re-parse that read the old parsed items and then
    removed them overwrote an edit that synced in meanwhile, under a clock
    concurrent with it.
16. **The recommendation decision was revived on no clock.** Withdrawing a
    project recommendation's decision removes its source change set, and
    deciding again writes it afresh under its deterministic id with an empty
    clock. The revival was concurrent with the removal, which the removal's
    instant now wins. The device that decided again showed the decision and
    its peers did not.

### Decision

7. **The stored version includes its tombstone** wherever sync orders
   versions: `AgentRepository.getEntityIncludingDeleted` is what the receive
   (`resolveReceivedAgentEntity`), the backfill responder and verifier,
   own-counter settlement, the sequence log's canonical clock and the local
   write resolution read.
8. **Every agent entity is received in one transaction.** The stored row is
   read, resolved and written together, for every type. The outbox bundle's
   prefetch is gone, and so is the separate change-set receive path, which
   the general one now covers.
9. **A removal succeeds the version it replaces.** A local removal of any
   variant, append-only ones included, is stamped with a clock that covers
   the stored version, as a write to a mutable register already was.
10. **A removal ranks at its instant.** `effectiveUpdatedAt` is the later of
    the variant's timestamp and `deletedAt`. A removal concurrent with an
    edit is last-writer-wins by these instants: the later of the two stands
    on every device. Edits of an append-only variant never move its
    timestamp, so a removal wins over any edit concurrent with it. No type
    that is removed has a status override.
11. **A row built afresh over a tombstone is a re-creation and keeps its
    fields** (`resolveLocalAgentWrite`). Its clock covers the tombstone, so
    it succeeds the removal everywhere, and its `updatedAt` is raised to the
    removal's instant at least. A write that carries a clock older than the
    tombstone is an edit of a stale snapshot and is still resolved against
    it as concurrent.
12. **A writer that revives an append-only row under a deterministic id
    carries the stored clock.** The recommendation decision and its source
    set read the stored version, tombstone included, and build on its clock.

### Consequences

- `Converged`, `NoLostSuccessor` and `LocalWriteTakesEffect` hold for the
  removal kind on three replicas with stale and clockless writes and a clock
  that lags by one tick (`AgentReplicationRemoval`), and on two replicas
  with any delivery lost and recovered by backfill
  (`AgentReplicationRemovalLossy`). Each switch set back has a
  counterexample (`specs/tla/README.md`). The other configurations keep
  their state counts.
- A bundle of N agent entities costs N primary-key reads, each in its own
  receive transaction, instead of one batched read before them. Every
  removal costs one primary-key read, as a write to a mutable register does.
- On a mutable register a removal wins over a concurrent edit only when it
  is the later of the two: an edit made after a removal it had not seen
  brings the entity back on every device. On an append-only variant the
  removal always wins.
- A row built afresh over a removed one always brings it back. The writers
  that do so read with `getEntity`, which hides the tombstone, so they
  cannot tell a re-creation from a first creation. Three writers re-create
  under a reused id today: the day plan's drafting, the recommendation
  decision, and the seeding of the default templates and souls
  (`AgentTemplateSeeding.seedDefaults`, `SoulTemplateOps.seedDefaults`),
  which runs at every start and creates a default the user deleted again.
  The seeding did so before this change too, on the starting device and,
  unless a peer's clock ran ahead, on the others. That the removal of a
  default does not stick is a product question this change does not
  decide: the options are to seed only on a first start, to skip an id
  whose tombstone is stored, or to keep restoring the defaults.
- An append-only row re-created afresh (no clock) under a reused id is
  written as given, without reading the stored version: only removals of
  append-only variants read it, to keep appends at one write. The one such
  writer, the recommendation decision, carries the stored clock itself.
- Residuals: the soul-assignment swap and `approveSoulProposal` above stay
  open. Hard deletes (`AgentRepository.hardDeleteAgent`, retention pruning)
  leave no tombstone and are not synced, so a late copy can still restore
  such a row; they are unchanged.

## Related

- [ADR 0068](./0068-model-checked-agent-convergence.md): the entity
  resolver, the local write resolution and the `RankDrop` condition
- [ADR 0078](./0078-entry-link-versions-are-ordered.md): the same class of
  hole for journal entry links
- `specs/tla/EvolutionSession.tla`, `specs/tla/AgentLinks.tla`,
  `specs/tla/AgentReplication.tla` (the removal kind),
  `specs/tla/VersionHeads.tla`, `specs/tla/README.md`
- [Templates, souls and evolution](../../knowledge/features/agents/templates-souls-evolution.md)
- [Agent persistence and sync](../../knowledge/features/agents/persistence-and-sync.md)
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
