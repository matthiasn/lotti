# Mobile scroll stutter and save stalls — investigation and fix plan

Date: 2026-10-13. Branch: `fix/mobile-scroll-jank-plan`.

## Symptom

On Android, scrolling stutters on task details, pages and settings — the UI
holds for several frames at a time. Reported as a recent regression.

## What the evidence says

Source: one day of mobile logs (13:00–14:17), slow-query and super-slow-query
logs, sync log, error logs. The logs carry no frame timings, so none of the
frame-drop suspects below is proven; the save-stall finding is.

- Every SQLite database the sync path touches runs on a background isolate
  (`openDbConnection(background: true)`, `lib/database/common.dart`), so a slow
  query **cannot drop frames by itself**. It stalls whatever awaits it.
- The sync *logic* — outbox, inbound worker, bridge, attachment pipeline, the
  Matrix SDK — runs on the UI isolate. That is where frames can be lost.
- `UserActivityGate` (1.2 s idle threshold, no max wait) gates only the outbox
  and the inbound apply worker. Attachment download/save, backfill requests,
  the backfill responder, recovery and deep backfill are ungated. In the logs,
  65 attachment download/decode/save steps ran *while* the gate held the outbox
  back. The gate itself has not changed behaviour since August.
- Sync bursts: 13:00–13:03, 13:28, 14:03, 14:13 (by sync-log volume and
  slow-query time). Two ~5.3 MB PNGs were received at 13:00:54 and 13:00:57.

## Fix 1 — Matrix attachment decryption off the UI isolate (stutter, highest)

`createMatrixClient` (`lib/features/sync/matrix/client.dart`) never sets
`nativeImplementations`, so matrix 12.0.1 falls back to
`NativeImplementations.dummy` and `Event.downloadAndDecryptAttachment` runs
`decryptFile` (AES-CTR + SHA-256 check) on the UI isolate. Multi-MB images
cost tens to hundreds of ms of UI time each.

Not a recent regression (never set; SDK version unchanged) — but it is the
most direct frame-dropping work the logs show during the bursts.

- Pass `nativeImplementations: NativeImplementationsIsolate(compute)` to
  `Client(...)`. Pure Dart, part of the SDK, no native dependency, Flathub-safe.
- Check what else that switches to the isolate (key derivation, encryptFile on
  send, thumbnail generation) and that each is still correct; the outbox send
  path then also stops encrypting on the UI isolate.
- Test: `test/features/sync/matrix/client_test.dart` asserts the client is
  built with `NativeImplementationsIsolate`. Re-run with the change reverted.

## Fix 2 — gate the attachment pipeline on user activity (stutter)

`AttachmentIngestor` / `_AttachmentSaver`
(`lib/features/sync/matrix/pipeline/attachment_ingestor.dart`,
`attachment_saver.dart`) download, decode and write files with no regard for
interaction. Even with Fix 1, the I/O completions, gzip result handling and the
follow-up DB writes land on the UI isolate mid-scroll.

- Inject `UserActivityGate` into the ingestor (it is already in get_it and
  wired through `lib/get_it_sync.dart`) and `await waitUntilIdle()` before each
  queued download starts — not inside one, so an in-flight download is never
  held open across a long interaction.
- Mind the existing 45 s download timeout (`attachment.save` timed out at
  13:09:13): the wait must happen before the timeout starts.
- No max wait exists on the gate today; continuous scrolling starves both
  gated paths indefinitely. Decide whether attachments need a ceiling (e.g. let
  one through every N seconds) — check how the inbound worker copes first.
- Consider the same gate for `BackfillRequestService._processBackfillRequests`
  (periodic timer, ungated) — it is also the caller of the slow query in Fix 4.
- Tests: fakeAsync, activity event → no download starts until the idle
  threshold passes; idle → starts immediately.

## Fix 3 — nudge banner sources refresh on every agent write (stutter, regression candidate)

`activeRelationshipNudgesProvider`
(`lib/features/relationships/state/relationship_nudge_providers.dart`) watches
`agentUpdateStreamProvider(agentNotification)` — the *global* agent
notification. Every agent-DB write (99 agent transactions in the log window,
mostly sync) re-runs `listAgents` plus per-agent `getLinksFrom`,
`getRelationshipById` and `getEntitiesByAgentId`, deserialising the results on
the UI isolate. The merged `activeNudgeBannersProvider` returns a fresh list
each time, so the dock in `lib/beamer/beamer_app_chrome_part.dart` — which
wraps every shell page — rebuilds on each run. The relationships feature is
recent, so this fits "regression" better than Fix 1.

- Drop the global `agentNotification` watch, or narrow it: the per-agent
  `agentUpdateStreamProvider(identity.agentId)` watches already cover nudge
  changes; the global one exists to see agents being created/retired. Find a
  narrower notification for that (lifecycle changes only).
- Make `activeNudgeBannersProvider` stop notifying when the merged entries are
  unchanged (`updateShouldNotify` with deep equality, or `select` at the dock).
- Check `activeGoalNudgesProvider`
  (`lib/features/goals/state/goal_agent_providers.dart`) for the same pattern.
- Fix the error at 14:02:55 while here: `Ref.invalidateSelf` called from the
  deadline `Timer` after the provider was disposed (timer created after an
  `await`, after disposal). Guard with `ref.mounted` / register the timer only
  if still mounted.
- Tests: an unrelated agent write does not re-run the provider; unchanged
  entries do not rebuild the dock; disposal before the timer fires does not
  throw.

## Fix 4 — 2–3.5 s watermark UPDATE stalls saves (not stutter, but a hang)

`markAnnouncedHeadRequests` (`lib/database/sync_db_lifecycle.dart`), added in
`ec037ae0db` (#4500, 2026-09-26), runs inside its transaction:

```sql
UPDATE sync_sequence_watermarks SET last_counter = MIN(last_counter, COALESCE((
  SELECT MIN(counter) - 1 FROM sync_sequence_log
  WHERE host_id = ? AND counter >= 1 AND status IN (1, 2)
), last_counter)), updated_at = ? WHERE host_id = ?
```

Logged 7/7 times at 2122–3496 ms (13:00:16, 13:01:34, 13:01:51, 13:03:55,
13:28:40, 14:02:57, 14:03:55). EXPLAIN on a desktop copy:
`SEARCH sync_sequence_log USING INDEX sqlite_autoindex_sync_sequence_log_1
(host_id=? AND counter>?)` — it walks the PK index in counter order and fetches
every row to test `status`. With no `missing`/`requested` rows (the steady
state) it reads every row of the host; the phone's counters are ~379k. With
`INDEXED BY idx_sync_sequence_log_host_status` the same query touches only the
status-1/2 rows and is effectively free.

While it holds the sync.sqlite writer, `VectorClockService._recordReservedCounter`
(every local save) waited 1.4–3.4 s, and agent.sqlite commits waited
1.5–2.4 s. That reads to the user as a tap/save that hangs.

- Add `INDEXED BY idx_sync_sequence_log_host_status` to the subquery (the repo
  already uses `INDEXED BY` this way in `sync_db_backfill.dart`). No schema
  change.
- Audit other `MIN(counter)` / `status IN (1, 2)` subqueries over
  `sync_sequence_log` for the same plan shape.
- Second-order: the slow-query log also shows 609 range selects
  `sync_sequence_log WHERE host_id = ? AND counter BETWEEN ? AND ?` (p50 41 ms)
  and an inbound `abandoned` scan reaching 2.5 s (queue wait). Look after the
  main fix lands.
- Test: a plan test in the sync DB suite asserting the query uses
  `idx_sync_sequence_log_host_status` (not the autoindex) on a seeded table.

## Verifying the root cause

Do this before or alongside Fix 1–3 to know which one actually matters:

1. **A/B**: disable sync on the phone, scroll task details. Stutter gone →
   sync-induced (Fix 1/2/3). Stutter stays → rendering; look at recent UI
   changes on the shared shell/chrome instead.
2. **Trace**: profile build on the device, DevTools → Performance, "Track
   widget builds" on, scroll during a sync burst (e.g. right after receiving
   media from desktop). UI-thread flame chart: look for `decryptFile`/SHA-256
   (Fix 1), `activeRelationshipNudgesProvider` re-runs and `NudgeBannerDock`
   rebuilds (Fix 3). Performance overlay to tell UI- from raster-thread jank.
3. After each fix, repeat the trace; compare worst-frame times.

## Order

Fix 4 (smallest, certain) → Fix 1 → Fix 3 → Fix 2. One PR each; Fix 4 and
Fix 1 are independent of the trace result.
