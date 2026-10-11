# ADR 0132: Messages Without a Counter Are Delivered

- Status: Accepted
- Date: 2026-10-11

## Context

Settings, config flags, preferences and AI configurations carry no sequence
counter. No peer can see that one of them is missing, and backfill cannot
ask for it again. Delivery is their only guarantee: every message must
eventually reach the room, and every receiver must eventually apply it.
Five paths broke that.

- **The outbox gave up.** A row that failed `maxRetries` times went to
  `error` and stayed there until someone tapped Retry in the outbox
  monitor. About five minutes offline was enough. A failed bundle took
  every row in it to the cap together. ADR 0127's ledger settles an AI
  configuration once the outbox accepts it, so it could not help either.
- **A bundle dropped what it could not read.** A manifest entry that did
  not decode, or a child whose prepare threw, was logged and left out. A
  manifest this build could not resolve, such as a newer manifest
  version, applied nothing. In both cases the bundle was still acknowledged
  as applied, so the change never reached that device.
- **Prepare failures were final.** Any prepare error that was not an
  `IOException` became `permanentSkip`. That included a journal entity
  carrying a field from a newer build, and a rate-limited or failed media
  download (`MatrixException`). Nothing resurrected these events.
- **A relay answered `deleted` for a payload it never held.** A device
  whose sequence row only recorded that a counter exists answered
  `deleted` when asked for the payload. `deleted` is terminal at the
  requester. Two devices that had both lost a payload closed each other's
  gap for good.
- **A failed conflict was recorded as received.** When storing a
  concurrent journal version as a conflict threw, the write reported a
  skip. The receive then recorded the version as held, so no backfill
  asked for it again.

## Decision

- **`error` is not terminal.** When a drain finds the queue empty, it
  returns every row that has been in `error` for longer than
  `SyncTuning.outboxFailedRequeueAfter` (15 minutes) to `pending`, with
  one attempt left (`OutboxRepository.requeueFailed`). It then drains
  again at once. While rows wait in `error`, the outbox watchdog runs such
  a drained pass once per window, so they do not wait for the next write.
  A row that keeps failing costs one attempt per window, and a bundle that
  failed whole recovers row by row. `Outbox.tla` models this as
  `RequeueFailed`, and `FailedIsRetried` holds in `OutboxRequeue`.
- **A partly undecodable bundle is tried again whole.** The children that
  decoded still apply. The event is then skipped as `undecodable`
  (`PreparedSyncEvent.hasUndecodableParts`), and the queue resurrects
  those at each start (ADR 0129). Every child tolerates the replay. A
  manifest that cannot be resolved takes the same path.
- **Prepare failures are retried, not dropped.** A `MatrixException` is
  `retriable`. Any other failure that is not an `IOException` is
  `undecodable`, so an updated build applies it at its next start. The
  resurrection cap (50) bounds an event that never applies.
- **Only a device that held a payload says it is deleted.** A relay whose
  row for the requested counter is still `missing` or `requested` stays
  silent, and the requester keeps asking the others.
- **A conflict that cannot be stored fails the write.** The transaction
  rolls back, and the receive is retried.

## Consequences

- An outbox that keeps failing tries each failed row about four times an
  hour. The monitor still lists those rows as failed between attempts, and
  Retry and Remove work as before.
- A bundle from a newer build is applied again at every start until this
  build can read all of it, up to the resurrection cap.
- A payload that every remaining device has lost is never answered as
  deleted. It stays missing, and backfill keeps asking at its normal rate.
