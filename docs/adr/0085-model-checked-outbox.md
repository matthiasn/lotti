# ADR 0085: The Outbox Merges One Enqueue at a Time and Sends Orphaned Claims in Their Turn

- Status: Accepted
- Date: 2026-09-25

## Context

The sync sequence model ([ADR 0065](./0065-model-checked-sync-sequence-reservations.md),
`specs/tla/SyncSequence.tla`) treats the outbox as a set of counters per
entity that is sent atomically and never fails. The outbox itself — the
enqueue writer's merge of a new version into the entity's pending row, the
claim, bundling, retries up to `maxRetries`, the claim lease, pruning and the
monitor's Retry and Remove — rested on prose and on the compare-and-set that
turns a merge into a fresh row once the pending row has been claimed.

`specs/tla/Outbox.tla` models that queue as the code stood: an enqueue reads
the pending row with `findPendingByEntryId` and writes it back after further
awaits; a fresh row is enriched with the last counter the sequence log
recorded; one `ClientRunner` callback at a time claims a bundle, sends it and
marks it; sends fail, time out and land anyway; marks throw; the process dies
between the send and the mark; leases run out. TLC confirmed four holes:

1. **Two enqueues of one entity lost a counter.** Nothing kept two enqueues of
   the same entity apart. Both read the pending row holding version 1; the
   enqueue of version 2 wrote `{v2, covers v1}`, then the enqueue of version 3
   wrote `{v3, covers v1}` over it, and counter 2 was in no row
   (`NoLostCounter`, six steps). Every write path awaits its own enqueue, but
   two paths writing one entity — two agent wake chains, an edit racing a
   backfill response — do not wait for each other.
2. **An enqueue arriving after a newer one put the older payload back.** The
   merge of an inline payload (an agent entity or link, an entry link) always
   took the incoming message, so a late enqueue of version 1 onto a pending
   version 3 left `{v1, covers 3}` (`CoversOnlyOlder` in four steps,
   `MergeNeverRegresses` in the same shape). A peer marks every covered counter
   received, so it would never ask for version 3, which the row no longer sent.
3. **A fresh row covered a counter newer than its payload.** When version 3
   was in flight and a late enqueue of version 2 inserted a fresh row, the
   enrichment from the sequence log added counter 3 to it (`CoversOnlyOlder`,
   eight steps) — the same false promise as hole 2.
4. **An orphaned claim landed after the newer version.** A claim that ends
   without a mark — the process dies between the send and markSent, or
   markSent and markRetry both throw — leaves its rows `sending` until the
   one-minute lease runs out. Meanwhile a newer version of the entity,
   enqueued as a fresh row because the old one was not pending, was claimed
   and sent; then the lease ran out and the older payload went out last
   (`NewestLandsLast`, fourteen steps). Receivers that order by vector clock
   drop it; a config flag's receiver applies whatever arrives last.

With callers that enqueue one entity in order, the old merge was sound: the
in-order configuration with the three merge fixes switched off passes. Pruning
(only `sent` rows), `SentWasDelivered`, and liveness (every row ends sent, in
`error`, or removed; every enqueued version reaches the room unless its row
failed for good) held already.

## Decision

1. **Enqueues of one outbox entry run one at a time.**
   `OutboxEnqueueWriter._serializedByKey` chains the journal-entity,
   entry-link, agent-payload and config-flag enqueues per outbox entry id, so
   the pending-row read and its write are never interleaved with another
   enqueue of the same entry. Different entities still enqueue concurrently.
   The processor is not excluded: the update's compare-and-set on `pending`
   already turns a claim in between into a fresh row.
2. **A merge keeps the newer inline payload.** When the pending row's clock
   strictly dominates the incoming one, the merge keeps the pending entry link
   or agent payload and only folds the incoming clock into the covered ones.
   A journal entity already took the entry's current clock from the database.
3. **A fresh inline row covers only an older counter.**
   `enrichCoveredVcsFromSequenceLog` takes the payload's clock and adds the
   last recorded clock only when the payload has reached it. Journal rows pass
   no payload clock: their sender reads the entry's current version at send
   time, so the enrichment stays as it was for them.
4. **A drain first returns orphaned claims to the queue.**
   `MatrixOutboxService.sendNext` calls `OutboxRepository.releaseOrphanedClaims`
   (`SyncDatabase.releaseSendingOutboxItems`) before it claims. The runner
   runs one callback at a time and only `sendNext` claims, so no claim of this
   process is in flight there and every `sending` row is an orphan. It goes
   back to `pending` with its retry count untouched and is sent in its turn,
   before newer rows of its entity. The send may have landed, so this is a
   duplicate, never a loss.
5. **Dispose waits for the drain in flight.** Found in review, then
   confirmed by TLC with a `Teardown` action (the generation disposed and the
   same profile restarted, as `ProfileSwitcher.runWithGenerationClosed`
   does): `dispose` closed the runner but returned while its drain still
   awaited a send. The next generation released that row (decision 4) and
   sent it and a newer version; then the old send landed last
   (`NewestLandsLast`, eleven steps). `sendNext` now records its run in
   `_activeSend` and returns at once when disposed, and `dispose` awaits the
   run before it tears anything else down; the drain stops after its current
   pass. The old generation cannot overwrite the new one's statuses:
   `ServiceDisposer` closes its `SyncDatabase` before the next generation
   opens the file, so its late marks throw. A per-instance claim token was
   rejected as unnecessary for that reason, and it would need a schema change.
6. **The model gates the code**, as in ADR 0065: `Outbox.tla` and its three
   configurations run in CI whenever the outbox, its database mixins, the
   runner or the outbox monitor change, and a Glados trace in the enqueue
   writer's suite drives the real writer, database, repository and processor
   through generated interleavings and checks the same properties.

## Consequences

- An entity's enqueues wait for each other. Each is a handful of database
  round trips, and the same entity is rarely enqueued twice at once, so the
  wait is short and only ever between writes of one entity.
- A version enqueued after a newer one still gets its counter covered, but
  its content is not sent: the newer payload already carries it.
- After a crash or a double mark failure, the rows a claim left behind are
  resent on the next drain instead of a minute later. That was always a
  duplicate; now it is one that arrives in order. The claim lease stays as a
  second guard.
- A profile switch or restart can take up to one send longer to dispose the
  outbox. `ServiceDisposer` allows each service three seconds; a send still
  running after that is recorded as a disposal failure (and makes the strict
  closed-generation path report a quiescence failure) and is the timed-out
  send residual below.
- **Residual: a timed-out send can land after a newer one.** The processor
  abandons a send after `sendTimeout` and retries the row, but the Matrix send
  keeps running and can land after the retry or a newer version
  (`OutboxOperator` allows it; with `NewestLandsLast` it fails in twelve
  steps). Payloads ordered by vector clock drop the late copy; a config flag
  or an AI configuration, applied in arrival order, is overwritten with the
  older value on the peer. Options: send with a stable Matrix transaction id
  per outbox row, so the retry reuses the abandoned event; give those payloads
  a clock or timestamp that the receiver compares; or stop timing sends out
  while the SDK still retries them. Each changes the wire or the protocol and
  needs a decision.
- **Residual: Retry on an old failed row sends a stale value.** A row in
  `error` stays there while newer versions of its entity go out, and the
  monitor's Retry sends it after them (twenty steps). Options: drop an
  `error` row once a newer row of its entity is sent; merge a retried row
  into the newest pending one; or hide Retry on a superseded row. Each
  changes what the monitor shows and needs a decision.
- **Residual: a clockless payload follows its callers' order.** Two callers
  setting one config flag at once enqueue in whichever order their writes
  finish; the lock only makes the last enqueue win.

## Verification

Three TLC configurations check the code as it is now, with 2,978,126 distinct
states in total. Reverting each decision breaks a property in 4 to 14 steps.
The Dart regressions in `outbox_enqueue_writer_test.dart`,
`outbox_service_send_test.dart`, `outbox_repository_test.dart` and
`sync_db_outbox_test.dart` each fail with their decision reverted, and so does
the conformance trace. `specs/tla/README.md` has the traces and the residuals.

## Related

- [ADR 0065](./0065-model-checked-sync-sequence-reservations.md): the sequence
  log whose counters the outbox carries.
- [ADR 0078](./0078-entry-link-versions-are-ordered.md): receivers order entry
  link versions by clock.
- `specs/tla/Outbox.tla`, `knowledge/features/sync/send-path.md`.
