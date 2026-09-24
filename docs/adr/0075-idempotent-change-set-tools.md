# ADR 0075: Idempotent Change-Set Tools

- Status: Accepted
- Date: 2026-09-24

## Context

[ADR 0067](./0067-model-checked-change-set-lifecycle.md) left a residual it
could not close with a local transaction: **the same item decided on two
devices before they sync is applied on both.** Each device's claim succeeds
against its own replica, and each dispatches. `ChangeSetLifecycleRace`
violates `AtMostOnceApply` in five states. Closing it with coordination —
one device that applies a set's changes, or a lease on the item — would make
confirming depend on a peer being reachable. So this ADR takes the other
route ADR 0067 named: make every tool's effect idempotent across devices, so
that the second application changes nothing.

The dispatch can not be deduplicated by its decision: each device mints its
own `ChangeDecisionEntity` with a random id. What both devices share is the
item — one synced row, the same index. We extended
`specs/tla/ChangeSetLifecycle.tla` with what a confirmed change does to the
journal on each device — entities by id, one task field as a register that
the user can edit too, both synced by message in any order — and with the
user's reopen. TLC found:

1. **A create-style tool mints a random id per dispatch.** Two devices that
   confirm the same follow-up task create two tasks (`NoDuplicateEffects`,
   6 states). The same holds for time entries, checklist items and a
   migration's copy.
2. **A set-style tool overwrites whatever the field holds.** One device sets
   the title, the user edits it, and the other device's late application —
   after it has received the edit — sets the proposed title again
   (`NoClobber`, 4 states).
3. **A consolidated copy has an effect of its own.** A wake on one device
   copies a pending item into the survivor set while another device confirms
   the original; confirming the copy applies the change a second time
   (`NoDuplicateEffects`, 7 states) — ADR 0067's second residual.
4. **A migration's failed dispatch could not revert its own claim.** The
   follow-up task is applied and its placeholder mapped in memory; the
   migration is claimed, resolved from that mapping; the follow-up's sibling
   rewrite then writes the target into the claimed item — a change of the
   item, one revision later — and the revision guard ADR 0067 added refuses
   the migration's revert: confirmed, never applied (`StatusMatchesEffect`,
   7 states). The code reaches this only if the sibling rewrite's
   transaction starts after the migration's claim; today the follow-up's
   capture and that transaction request run in one continuation, so no
   confirm can be claimed in between — the model's steps are coarser than
   the code's. The design should not depend on that.
5. **A derived checklist was taken as spent when its link had not
   arrived.** A checklist and the task update that lists it sync apart. A
   device that held the other device's checklist, but not the task update,
   found the derived id taken and created a second checklist
   (`NoDuplicateEffects`, 6 states, with the entity and its link to the
   parent modelled as separate writes; found in review).
6. **Field proposals from the task's query chat recorded no base,** so they
   applied unconditionally on a late confirmation (found in review).
7. **The reopen ABA is now model-checked.** Each user decision runs in its
   own attempt slot, and `Reopen` puts a decided item back to pending. With
   the revision guard removed, a first confirm's failure reverts a second
   confirm of the reopened item, whose dispatch then succeeds on a pending
   item (`SucceededClaimStands`, 7 states) — the gap ADR 0067 and the specs
   README recorded.

We also checked what the journal does when both devices create the same id
before either has received the other's: `updateJournalEntity` finds the
clocks concurrent and keeps the local version, storing the incoming one as a
`Conflict` row for the user. One entity, not two — but not a silent merge,
since the two versions differ in their creation timestamps.

## Decision

1. **The item names its effect.** `ChangeItemEffect.effectKeyIn` is the
   item's `effectKey` when it carries one, and otherwise its position,
   `<change set id>:<index>` — the same on every device, and the same for
   every decision of the item. `ChangeSetConfirmationService` hands it to the
   dispatch together with the item's `base` (below), as the reserved
   arguments of `ChangeEffect` (`lib/features/agents/tools/change_effect.dart`),
   replacing whatever a proposal's arguments carried under those names; the
   dispatcher strips them before any handler reads its arguments.
2. **A create-style tool derives the id of what it creates** from the key and
   a role (`change-effect:<key>:<role>`, through
   `MetadataService.deterministicId`), and does nothing when that entity is
   already in the journal — written here, synced from the other device, or
   deleted since, since a second application must not bring back what the
   user removed. An insert refused because the id exists is checked again,
   for the entity that arrived between the check and the write. This covers
   `create_follow_up_task` (the task; the late device's result names the same
   task, so its migrations resolve to it), `create_time_entry` (no second
   timer starts), `add_checklist_item(s)` (one id per position, and the
   checklist of a task that has none), `migrate_checklist_item(s)` (the copy,
   and the target's checklist when it has none; the source is still
   archived) and the event agent's `suggest_follow_up_task`. The checklist
   of a task that has none comes from
   `ChecklistRepository.derivedChecklistFor`: a live checklist under the
   derived id is reused and listed on the task, and one the user deleted
   moves on to the next generation's derived id, the same on every device
   that knows the same deletions.
3. **A set-style tool applies only while the field holds the value the
   proposal was made against.** The task agent records it when it queues a
   proposal to set the title, status, priority, estimate, due date or
   language (`ChangeItem.base`, read fresh rather than from the wake's cached
   snapshot), and so does the task's query chat, from the task it loaded for
   the answer (`QueryTaskActionContext.metadata`). No other proposal source
   builds these task-field items. The dispatcher compares it with the task before any handler
   runs; a field that moved on — applied already on another device, or
   edited since — is left alone, and the dispatch reports success, because a
   failure would revert or retract the item over a confirm that landed
   elsewhere.
4. **A consolidated copy carries its original's key**, so confirming the
   copy on one device and the original on another creates one entity.
5. **A migration resolved from the in-memory mapping is claimed with its
   resolved target**: the claim writes the arguments it dispatches with, in
   the same change of the item, and the sibling rewrite finds nothing left
   to rewrite. A reverted migration also keeps its resolved target across a
   restart.
6. As in ADR 0065–0067, the model gates the code. `ChangeSetLifecycle` gains
   attempt slots, `Reopen`, entities and the field register, and the switches
   `RevisionGuard`, `ClaimResolvesTarget`, `DerivedIds`, `CopyCarriesKey`,
   `CasGuard` and `ReuseLive` as mutation points; `ChangeSetLifecycleRace` now
   checks `NoDuplicateEffects` and `EffectsConverge` instead of
   `AtMostOnceApply`, and four configurations are added (`RaceSet`,
   `Reopen`, `ConsolidateSync`, `RaceLink`). A Glados trace over a real journal database applies
   five confirmed items any number of times with the user's edits in
   between, and after every step the journal must equal applying each once.

## Consequences

- ADR 0067's first residual is narrowed. An item decided on two devices is
  still dispatched on both, but the journal ends up as if it was applied
  once: `NoDuplicateEffects`, `NoClobber` and `EffectsConverge` hold for two
  devices under every interleaving TLC explores, dispatch failures included.
  What stays open, each recorded in `specs/tla/README.md`:
  - **Both devices create the entity before either has the other's.** One
    id, and the journal parks the other version as a `Conflict` row for the
    user. A silent merge needs the created content to be identical — the
    creation timestamps come from each device's clock — and a journal rule
    that merges identical concurrent versions. That is a product decision,
    not taken here. The same holds for two concurrent applications of a
    field change, as it did before.
  - **A value compare-and-set cannot see an ABA**: a user who restores the
    field to the proposal's base between the two applications gets the
    proposed value again (TLC: `NoClobber` with `UserRestoresBase`).
  - **Status still records the dispatch, not the effect.** If one device's
    dispatch fails and reverts while the other's applied, the merged item
    reads pending though its change landed; confirming it again applies
    nothing. `StatusMatchesEffect` is therefore still not checked under the
    race.
  - Two devices creating the same follow-up task concurrently may each
    assign it a task agent; `createTaskAgent`'s duplicate check is local.
  - Not covered: `assign_task_label(s)` is a set-add, so a late add can bring
    back a label removed in between; `update_checklist_item(s)` and
    `update_time_entry` record no base (the checklist's approval protections
    stand); the project agent's `create_task` and `update_project_status`
    keep random ids and no base — its Undo deletes the created task, and a
    derived id would need a re-confirm to bring the deleted task back.
    `link_task` is idempotent already (one link per endpoints and type), and
    the relationship agent's `create_and_link_task` already derives its id.
  - A skipped compare-and-set reports success: a user who edits a field and
    then confirms the older proposal for it sees the proposal confirmed and
    the field unchanged.
  - Clients that predate `effectKey` and `base` drop them when they rewrite
    a set, as they drop `revision`: a copy then falls back to its own
    position, and a field change applies unconditionally.
- ADR 0067's second residual is narrowed too: a copy consolidated on one
  device while the original is confirmed on another applies nothing more.
  The copy stays pending beside the applied original (`StatusMatchesEffect`
  fails in `ChangeSetLifecycleConsolidateSync`); confirming it is a no-op.
- The reopen ABA of ADR 0067 is model-checked (`SucceededClaimStands`).
- ADR 0066's residuals stand: a tool that throws after its effect landed is
  reverted and can be retried — now harmlessly for the tools above — and a
  crash between the claim and the dispatch leaves the item confirmed without
  its effect.

## Related

- `specs/tla/ChangeSetLifecycle.tla`, `specs/tla/README.md`
- `lib/features/agents/tools/change_effect.dart`
- [Task agents](../../knowledge/features/agents/task-agents.md)
- [ADR 0066: Model-checked agent wakes and confirmations](./0066-model-checked-agent-wakes-and-confirmations.md)
- [ADR 0067: Model-checked change-set lifecycle](./0067-model-checked-change-set-lifecycle.md)
