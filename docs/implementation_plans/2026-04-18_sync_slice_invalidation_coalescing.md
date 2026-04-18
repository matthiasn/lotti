# Sync Slice Invalidation Coalescing (Pattern 3)

## Status

Not started. Scoping only — do not implement without further agreement.

## Problem

Slow query log for 2026-04-18 shows sync-driven UI-controller thrash:

```text
256 855 ms  / 409 calls   SELECT * FROM journal WHERE deleted = FALSE AND id IN (?…)
134 220 ms  / 272 calls   SELECT le.from_id, le.to_id FROM linked_entries le
                           INNER JOIN journal j ON j.id = le.from_id WHERE le.to_id IN (?…)
 10 239 ms  / 299 calls   SELECT * FROM journal WHERE type = 'Task' AND deleted = FALSE
                           AND task = 1 AND task_status IN (?…) AND category IN (?…)
```

Worst single sample: a 9-id primary-key `IN` lookup took **4.2 s**. The
PK path itself cannot cost that — the measured time is wait/queue time
behind the writer lock, not execution time. So the DB was already
saturated by a sync slice's per-event writes, and the readers piled up
behind it.

The query sites themselves are already batched (single `IN (?…)` per
caller invocation):

- `lib/database/database.dart:865-916` — `getJournalEntitiesForIds[Unordered]`
- `lib/features/journal/state/entry_controller.dart:503`
- `lib/features/ai_chat/repository/task_summary_repository.dart:119`
- `lib/features/daily_os/state/unified_daily_os_data_controller.dart:351`
- `lib/features/ai/repository/vector_search_repository.dart:139, 256, 284`
- `lib/database/database.dart:1637` (`getLinkedEntities`)

None of them sit inside a per-event loop. What multiplies the call
count is **how often each controller rebuilds** during a sync slice.
With ~800 sync events processed in one replay, each controller's
stream subscription fires once per journal row write, re-running its
single batched query every time.

## Mechanism

`SyncEventProcessor.process(...)` is awaited per event in
`matrix_stream_processor.dart:267`. Each call writes into
`JournalDb` via `_handleMessage`, which fires Drift stream listeners.
Every Riverpod controller that has a `watch(...)` on the journal table
re-runs its body on every write.

Observed Drift watchers triggered by journal writes:

- `unified_daily_os_data_controller` — day-plan + linked-from lookups
- `task_summary_repository` — linked entities per task
- `entry_controller` — single-entry reads, linked entries
- `ai_chat` / `vector_search_repository` — linked entities for chat RAG
- `time_history_header_controller` — category lookups

For a typical 800-event slice these UIs can rebuild tens to hundreds
of times in rapid succession. Each rebuild is itself batched, but the
DB sees the sum of all rebuilds stacked up.

## Options — in preference order

### A. Wrap the slice apply in a Drift transaction

```dart
await _journalDb.transaction(() async {
  for (final e in ordered) {
    await _eventProcessor.process(event: e, journalDb: _journalDb);
  }
});
```

Drift coalesces stream emissions at transaction boundaries, so all
subscribed controllers fire once per slice instead of once per event.

- **Pros:** simplest code change; biggest lock-contention win; UI
  ends up reflecting the full slice atomically.
- **Cons:** behavioural change to error handling. Today a single
  event failing retries independently; inside a transaction the
  whole slice rolls back. Retry semantics in `matrix_stream_processor`
  (`_retryTracker`, `_missingBaseEventIds`, `schedule(...)`) must
  still function — at minimum catch per-event errors inside the
  transaction, record retry state, and continue without rolling back.
  Alternative: wrap in `batch(...)` instead of `transaction(...)`
  (Drift `Batch` API) for writes only, which coalesces listener
  notifications without the all-or-nothing rollback.

**Open questions before implementing:**
- Does `Batch` coalesce stream listeners the same way a transaction
  does? Verify with a focused test.
- Are there any writes in `_handleMessage` that happen outside the
  journal DB and couldn't be rolled back cleanly (file writes,
  attachment saves, agent DB writes)? Those must be reordered or
  kept outside the transaction.
- Does `SyncSequenceLogService.recordReceivedEntry` need its own
  transaction scope, or should it be inside the slice transaction?

### B. Debounce downstream controllers on a single "slice complete" signal

Instead of changing the apply path, subscribe the expensive
controllers to a `sliceComplete` stream from
`matrix_stream_processor` rather than to raw Drift journal updates.
Emit one signal per ordered-processing burst. Controllers refresh
once per slice.

- **Pros:** no transactional semantics change; each controller
  decides how to react.
- **Cons:** every controller that cares about journal state has to
  migrate to the new signal — ~5+ call sites. Easy to miss one and
  end up with stale UI. Needs a deprecation path for the raw Drift
  watch.

### C. Per-controller debounce on the existing `UpdateNotifications`

Controllers already receive `UpdateNotifications.notify(...)` calls.
Add a debounce (e.g. 50 ms) on their reactive side so rapid bursts
coalesce before the expensive query re-runs.

- **Pros:** most local change; each controller can choose whether
  to debounce.
- **Cons:** introduces perceived UI staleness under normal (non-sync)
  single-user edits. Must tune per controller. Does not help the
  DB writer contention during the slice itself — only reduces how
  many times the query runs.

## Verification plan

1. **Reproduce the storm** in a test: use the `FakeMatrixStream` +
   `SyncEventProcessor` wiring already used in
   `test/features/sync/matrix/pipeline/matrix_stream_processor_test.dart`
   to feed a 500-event slice. Instrument the test DB to count
   `journal id IN (?)` query executions during the slice.
2. Baseline: current code should show hundreds of query executions
   for ~5 active controllers.
3. Apply the chosen fix (start with Option A using `batch`).
4. Re-run. Target: ≤1 query execution per controller per slice.
5. **Slow query budget:** re-enable slow-query logging on a real
   device, apply a real catch-up, confirm the cumulative time in the
   top-3 query fingerprints drops by at least an order of magnitude.

## Out of scope

- Query-plan changes on the individual SQL statements. The problem
  is **frequency**, not per-call cost. Any partial-index work on
  `journal WHERE type IN ('JournalEntry','WorkoutEntry')` is a
  separate concern and does not belong in this plan.
- UI refresh latency tuning (the debounce in Option C). If A lands,
  C becomes unnecessary.
- Rewriting `UpdateNotifications` into a bus. The current fan-out
  works; we are only changing when it fires.

## Risks

- **Transaction rollback semantics** breaking partial-slice retry
  behaviour. Mitigation: keep the `_retryTracker` outside the
  transaction, catch-and-log per-event errors inside it, never let
  an individual event failure abort the slice.
- **Sync-sequence log writes** are in the same DB family as the
  journal. Confirm they coalesce with journal writes under the same
  transaction/batch. If not, wrap them separately.
- **AgentDb writes** (different Drift DB instance) will not be
  covered by a `JournalDb` transaction. Confirm they don't create
  cross-DB consistency gaps.

## References

- `lib/features/sync/matrix/sync_event_processor.dart:599-673` —
  per-event `process()` entry point.
- `lib/features/sync/matrix/pipeline/matrix_stream_processor.dart:260-320` —
  the per-event await loop where a transaction boundary would go.
- `lib/database/database.dart:865-916` — batched id-lookup queries.
- `logs/slow_queries-2026-04-18.log` — evidence for the 409-call
  storm and the 4.2 s worst case.
- `docs/implementation_plans/2026-03-12_sync_inbox_attachment_dedupe_and_logging.md`
  — prior pass that fixed a different sync-volume class
  (attachment dedupe), confirms the pipeline wiring conventions.
