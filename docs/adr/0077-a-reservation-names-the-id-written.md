# ADR 0077: A Reservation Names the Id That Is Written

- Status: Accepted
- Date: 2026-09-24

## Context

[ADR 0065](./0065-model-checked-sync-sequence-reservations.md) made every
vector-clock reservation name its payload, so that after a crash
`BackfillResponseHandler.settleOwnCounter` can prove whether the write landed:
it looks the named payload up and binds and resends the counter when that
payload's clock covers it, and burns the counter otherwise. The proof is only
as good as the name. `SyncSequence.tla` modelled the name as a flag — "the
reservation names its payload" — so it could not express a reservation that
names the *wrong* payload, and nothing checked that the name is the id the
write lands under.

Three create paths broke that. Each built its metadata first, which picked an
id and reserved the clock naming it, and then swapped in a caller-chosen id
with `metadata.copyWith(id: id)`:

1. `PersistenceCreateOps.createTaskEntryImpl` — the relationship tool
   dispatcher creates a person's commitment task under a stable id.
2. `PersistenceCreateOps.createAiResponseEntryImpl` — skill inference and
   attributed AI responses are created under the id their attribution
   artifact already carries.
3. `RelationshipRepository.createRelationship` — the contact import creates a
   person under the id minted when the contact was ticked.

The reservation named the uuidV5 of the task's or response's data, or a fresh
v1 id; the row was written under the caller's id. On the normal path this is
invisible, because the outbox binds the counter to the id it sends. A crash
between the commit and the outbox bind — or a swallowed enqueue failure
followed by a restart — leaves the row `reserved` under the wrong name.
Startup settlement then finds nothing under that name, burns the counter and
tells every peer to stop asking for it: the created task, AI response or
person never reaches the other devices until it is next edited. Had the name
matched another entity whose clock covered the counter, settlement would
instead have bound the counter to that entity.

With a switch that lets a reservation name another entity, TLC finds both in
a few steps:

- `NoFalseBurn`: reserve counter 1 for `e1` naming `e2`, commit `e1`, crash,
  settle — `e2` does not cover 1, so the committed counter is burned.
- `BoundRowsHavePayload`: counter 1 for `e1` names `e2`, counter 2 for `e2`
  commits, crash, settle — `e2` covers 1, so counter 1 is bound and answered
  although `e1` never landed.

## Decision

1. **The id is chosen where the clock is reserved.**
   `MetadataService.createMetadata` takes the entry's `id`, and names that id
   on the reservation — an explicit id wins over `uuidV5Input`. The three
   paths pass their id in instead of patching it afterwards.
2. **The returned id is final.** `Metadata.copyWith(id: ...)` after
   `createMetadata` is a defect: it separates the written entry from the name
   its counter will be settled by. The method's documentation says so, and the
   audit found no other path that moves a reserved clock to a different id.
3. **The model can say it.** `SyncSequence.tla` records the reservation's
   name per counter (`named`), settles by that name, and states
   `BoundRowsHavePayload` against the write that reserved the counter.
   `MisnamedReservations` lets a reservation name another entity; every
   checked-in configuration sets it `FALSE`.

## Consequences

- A crash after creating an entry under an explicit id no longer burns its
  counter; startup settlement resends it. End-to-end regressions drive the
  real metadata, reservation, sequence-log and settlement code through that
  crash and fail with the old code (the counter ends `burned`).
- A new create path that needs a caller-chosen id must pass it to
  `createMetadata`. Direct reservations elsewhere (links, agent entities,
  notifications, consumption events) already name the id they write; the audit
  is recorded in the pull request.
- Counters already burned under the wrong name stay burned: `burned` is
  terminal. The affected entries reach other devices on their next edit.

## Related

- [ADR 0065](./0065-model-checked-sync-sequence-reservations.md)
- `specs/tla/SyncSequence.tla`, `specs/tla/README.md`
- [Sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md)
