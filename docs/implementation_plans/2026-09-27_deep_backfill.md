# Deep backfill — a manual inventory round that repairs what counters cannot see

Status: **Phase 1 done (model checked), Phase 2 implemented.** The runtime
behaviour is documented in
[sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md#deep-backfill);
this plan records how the model was mapped onto the code.

## The gap

Counter backfill (`SyncSequence.tla`, [sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md))
repairs a hole between `(hostId, counter)` pairs that a device has recorded, and
the responder answers only a counter that its own `sync_sequence_log` maps to a
payload (`getEntryByHostAndCounter`). Old installations miss history that
neither side can name:

- "Populate sequence log" records only the counters in each row's *current*
  clock, so superseded counters never get a row on either side.
- Gap detection only runs for hosts in `host_activity` and for the originator.
- A record a device never heard of leaves no counter to be missing.

One real installation has ~300 records on one side and many more on the agent
node. Totals that small make advertising every record feasible.

## The protocol

A round is started by hand from the sync maintenance page. It is manual only
for now; a schedule can follow once it has proved itself.

1. **Inventory.** The device pages every synced record by id, **tombstones
   included**, and advertises `(payloadType, id, vectorClock)` in batches of
   5000. Each batch also carries the id range `[lo, hi)` it covers, and the
   clocks of any open conflict versions in that range. A batch is a gzipped
   JSON attachment (`m.file`), named by a new `syncInventory` message.

   **The ranges of one round tile the whole id keyspace, per record type.**
   The first batch's `lo` is unbounded (null) and the last batch's `hi` is
   unbounded (null). Each batch's `lo` is the previous batch's `hi`, which is
   the first id of the next page. A type with no rows still emits exactly one
   batch, `(null, null)` and empty. A batch only ever covers ids it can
   vouch for, so a recipient-only id anywhere — before the first row, between
   pages, after the last, or in an empty table — falls in some range and is
   pushed. The model's `Range(k)` partitions the whole keyspace in the same
   way.
2. **Diff.** Each recipient runs **one range query per record table per batch**
   (`WHERE id >= :lo AND id < :hi`, primary-key range scan) and compares clocks
   in memory. There is no per-record lookup (no N+1).
   - The recipient lacks the record, or holds an older or concurrent version →
     **request** it from the advertiser. The one exception is a concurrent
     version the recipient already holds as an open conflict, which is skipped.
   - The recipient holds a newer or concurrent version → **push** it to the
     advertiser. This includes records the batch's range covers but does not
     list, i.e. records the advertiser has no row for. The exception is a
     version the advertiser lists as one of its open conflicts, which is
     skipped.
   - Equal → nothing.
   - **Conflict versions travel like rows.** The recipient also requests each
     of the advertiser's listed conflict versions that neither its row nor its
     own conflicts keep. It pushes each of its own conflict versions that the
     advertiser's row and listed conflicts do not keep. Otherwise a concurrent
     version held only as a conflict on one device never reaches a third
     device whose row equals the others' (the model's `ConflictsTravel`).
3. **Answer.** The advertiser answers an id request with its current row,
   deletions included, and every open conflict version of the record. Answers and pushes are ordinary `journalEntity` /
   `entryLink` / `agentEntity` / … messages, received through the one write
   decision. Nothing on the receive side is new.

**Requests carry a target host**, and only that device answers, so several
peers never answer one request. Answers and pushes go to the room like any
sync message. A device that did not ask receives a version through the
ordinary write decision, which can only help it.

**An outstanding request is settled by coverage, not by sender.** A request
row records the advertised clock it asked for. It is cleared as soon as the
local row, or one of the entry's open conflicts, covers that clock, whoever
delivered the version. The version's own `originatingHostId` names where it
came from, not who answered, and nothing ties an answer to its request.
Coverage handles both cases this raises:
- A row never waits on a particular responder.
- A version that satisfies one advertiser's request leaves another
  advertiser's newer request open.

The model's `ClearOnlyCovered` switch shows the alternative: clearing every
request for the id on any receipt re-requests a version whose answer is still
on its way.

## The model

[`specs/tla/DeepBackfill.tla`](../../specs/tla/DeepBackfill.tla) checks the
protocol with TLC before any code exists. Configurations, properties, state
counts and the counterexample of every design switch are in
[`specs/tla/README.md`](../../specs/tla/README.md#deepbackfill--an-inventory-round-that-repairs-what-counters-cannot-see).
Its properties:

- `EventuallyConverged`: every device ends up holding the union of all
  versions (tombstones included), with any divergence shown as a conflict
  rather than kept silently.
- `NoLostTombstone`.
- `NoDuplicateRequest`.
- `EventuallyQuiet`: no conflict ping-pong from round to round.
- `RoundTerminates`: the round finishes across batches, under loss and a
  crash mid-flow.

What the model showed, and the plan therefore requires:

- **Range bounds.** Without them a recipient cannot tell "absent on the
  advertiser" from "not in this batch", so a record only the recipient holds
  never travels when only one device runs maintenance.
- **Durable outstanding requests.** A crash that forgets which ids are already
  requested sends the same request twice.
- **Conflicts are advertised, and held conflicts are skipped.** Otherwise a
  pair of concurrent versions is re-sent on every round forever.
- **Every batch is processed.** Fairness per sender alone let a re-emitted
  batch starve another. The inbound queue's in-order processing is what
  provides per-batch fairness.

## Phase 2: model action → code

| Model action | Component | Notes |
|---|---|---|
| `StartRound` | "Deep backfill" action on `matrix_sync_maintenance_page.dart`, driving a new `DeepBackfillService` (getIt, in `get_it_sync.dart`) | Disabled while a round is running on this device, and off in the demo world (`InertOutboxService`) |
| `EmitBatch` | `DeepBackfillService` pages each table by id with a keyset query (`WHERE id > :last ORDER BY id LIMIT 5000`), reading only `id`, the clock (`json_extract(serialized, '$.meta.vectorClock')` / `'$.vectorClock'`, the notifications' `vector_clock` column) and the deletion flag | Tables: `journal`, `linked_entries`, `agent_entities`, `agent_links`, notifications, consumption events. One batch = one gzipped JSON file uploaded via `MatrixPayloadSender`, named by a new `SyncMessage.syncInventory(roundId, batch, payloadType, lo, hi, attachmentEventId)` variant. Clockless rows cannot be ordered (`RefuseNullClock`): they are named in the batch's `unclocked` list, never listed as versions (omitting them made a peer push them back every round) |
| `Diff` | A new `DeepBackfillReceiver`, called from the event processor for `syncInventory` | Per batch: download and decode the file; run one range query over the matching table; compare with `VectorClock.compare`; open conflicts come from the conflicts table in the same range. Requests, pushes and the outstanding rows are written in **one transaction** with the outbox enqueue |
| `Req` | New `SyncMessage.recordRequest(payloadType, idsAttachmentEventId, targetHostId, requesterId)` | The id list travels as an attachment: a 5000-id list is far past Matrix's 64 KB text-event limit, which the existing 2000-entry `backfillRequest` is suspected to exceed as well (to verify separately) |
| `out` (durable) | New sync-DB table `deep_backfill_requests(target_host_id, payload_type, entry_id, vector_clocks, requested_at)`: the versions asked for | Settled once the local row or an open conflict covers every one of `vector_clocks`. It is checked when the next batch from that advertiser is diffed: the outstanding set only ever decides whether a record is requested again, so settling just before that decision is the same as settling on every receive. Expired after a timeout longer than a delivery (the model's `Expire`) |
| `Answer` | A new id-keyed responder: for each payload type, one batched `…IncludingDeleted` load of the requested ids, then the same per-type enqueue `_answerFromEntry` performs. That per-type enqueue is extracted into a helper taking the loaded payload, so neither path needs a `SyncSequenceLogItem` and the counter path keeps its hints and `deleted` answers | Answers only when `targetHostId` is this host. An id with no row is skipped: rows are never removed (purges keep tombstones), and the requester's timeout frees it |
| `Push` | The same per-type enqueue as `Answer` | A push the advertiser no longer needs is refused by the write decision |
| Conflict versions on the wire | `MatrixPayloadSender._readJournalPayload` | A queued journal message whose version the row does not cover is served from the entry's open conflict of exactly that version. Before this change such a message failed on every attempt, so nothing that sends today changes |
| `Receive` | Unchanged: `JournalDb.updateJournalEntity` / `detectConflict`, the agent and link receive paths | The model reuses the journal decision of ADR 0083/0092 and the merge for agent records |

Tests follow the repository's contract: one test file per source file. There
will also be a Glados conformance trace in the style of
`backfill_response_handler_model_conformance.dart`, driving the diff over
in-memory databases and checking `NoDuplicateRequest` and the union after
quiescence.

## Deliberately out of scope

- Scheduling. The round is manual. A periodic trigger needs only
  `StartRound` to be fair, which is what the liveness properties already
  assume.
- Relays. Only the advertiser answers its own inventory. A third device's
  newer copy reaches the others as a recipient push when that device diffs
  their inventories, whether or not it runs a round itself.
- Clockless legacy rows.
- The sequence log. A deep-backfilled version is recorded like any received
  payload. Rows the log still lacks are not reconstructed.
