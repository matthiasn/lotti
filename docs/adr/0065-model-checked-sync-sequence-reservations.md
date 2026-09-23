# ADR 0065: Model-Checked Sync Sequence Reservations

- Status: Accepted
- Date: 2026-09-23

## Context

The sync sequence log lets a device prove that no counter another device
handed out was lost. Its own-host half had been hardened one incident at a
time — persist-first reservations, `reserved` rows, `burnPending` retries, the
distinction between `burned` and `unresolvable` — and its history of fixes
("sync hot loop", "prevent replay of backfill requests", "stuck sync",
"race condition in catch up") is the history of a protocol reasoned about in
prose.

We wrote the protocol down in TLA+ (`specs/tla/SyncSequence.tla`) as the code
stood and model-checked it with TLC. Three holes came back as concrete traces:

1. **One crash between the payload commit and the outbox enqueue** lost the
   write for every peer. The row stayed `reserved`, which the responder defers
   and startup never touches, and without a later counter no peer even knew to
   ask. A reservation that died before its commit left a request open until
   the peer gave up.
2. **Two swallowed failures after a commit** — the early sequence bind, then a
   later step such as the FTS insert — made the outer VC scope release a
   counter whose payload was on disk, and the originator burned it.
3. **One swallowed reserved-row insert failure** let a request for an
   in-flight counter find no row, which the responder answered as a burn
   before the payload landed.

All three come from one gap: the originator could not tell "reserved, write
still running", "reserved, write landed, process died" and "reserved, write
never landed" apart.

## Decision

1. **A reservation names its payload.** `reserveNextVectorClock` and
   `getNextVectorClock` take the payload id and type; the `reserved` row
   records them as an intent. Every write path in the app passes it.
2. **Only a live reservation is deferred.** `VectorClockService` keeps a
   process-local map of reservations it has neither bound nor released. A
   crash forgets it, so an orphaned reservation is recognisable.
3. **One settlement rule for every own counter nothing has bound.**
   `BackfillResponseHandler.settleOwnCounter` binds and resends a counter whose
   named payload's clock covers it; defers a live or unnamed one, or one whose
   store is not wired yet; and burns everything else. The responder, the VC
   release handler and startup reconciliation all use it, so a release can no
   longer burn a payload that landed.
4. **A reservation is recorded before its counter is handed out.** When the
   sequence-log insert fails, the reservation is recorded in the settings
   database — the store that already holds the watermark — and startup moves
   it into the log. Only when both stores refuse does reserving throw, so no
   write can use the counter. A save therefore fails only when the settings
   database refuses a write — the database whose failure already fails the
   save through the watermark — never merely because the sync database is
   locked.
5. **`received` means durably in the outbox.** The write paths no longer bind
   before enqueueing; the enqueue writer binds after its insert. A crash in
   between leaves a `reserved` row that startup settles and resends.
6. **The model gates the code.** `specs/tla/` holds the spec, its TLC
   configurations and a pinned, checksum-verified tool runner. CI model-checks
   it whenever the spec or the code it describes changes, and a change to the
   protocol updates the spec in the same pull request.

## Consequences

- With every reservation named, one crash at any point loses no committed
  write and strands no backfill request; neither any two injected faults, nor
  one crash together with any one fault, can make the originator burn a
  payload that exists. TLC checks all of these, and four deliberate mutations
  of the fix — including dropping the settings fallback — are each caught.
- Delivery is still not claimed under swallowed enqueue failures or abandoned
  inbound events; the model says so explicitly instead of implying it.
- An unnamed reservation behaves as before. New write paths must name their
  payload, or they fall back to deferral after a crash.

## Related

- `specs/tla/SyncSequence.tla`, `specs/tla/README.md`
- [Sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md)
