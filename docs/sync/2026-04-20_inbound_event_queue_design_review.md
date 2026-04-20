# Inbound Event Queue — Adversarial Design Review

**Date:** 2026-04-20
**Reviewed doc:** [`2026-04-20_inbound_event_queue_design.md`](./2026-04-20_inbound_event_queue_design.md)
**Audit it builds on:** [`2026-04-20_sync_freeze_and_log_bloat_audit.md`](./2026-04-20_sync_freeze_and_log_bloat_audit.md)
**Reviewer scope:** adversarial — hunt for what the author (who is deep in the
code) likely missed, not to ratify the design.

---

## 1. Executive verdict

**Request revision before Phase 1.** The two-layer model is sound and the
author is right that today's three overlapping signal sources over-negotiate.
But four load-bearing claims in the design are wrong or understated, each
fixable without abandoning the approach:

1. **Coalescing of missing-entries nudges silently fragments N→1 → 1→1 per
   event.** The design declares the completeness layer "unchanged" but the
   ordered-slice wrapper at
   `matrix_stream_processor.dart:398` is the sole thing keeping backfill
   nudges batched, and the queue's per-event drain destroys it.
2. **Marker advancement in `commitApplied` is non-monotonic as written,**
   which breaks under the very live-vs-bridge race the queue is designed to
   tolerate.
3. **`raw_json` round-tripping through `Event.fromJson(room, json)` has a
   decryption-race failure mode** the SDK actually exhibits and the doc is
   silent on.
4. **The `MatrixEventClassifier` filter is load-bearing today but
   unspecified in the producer code path.** §7.1's three-line live-stream
   listener enqueues state events and redactions indiscriminately.

None of these are showstoppers; all need explicit treatment in the design
before the 1k-LOC Phase 1 lands. Go ahead with Phase 0 **as amended by §5
below**; pause Phase 1 until the design incorporates the four fixes plus
the drain-before-disable rule in §3.7.

The alternative — abandon the rewrite and ship P3c/P4a/P4b from the audit
as incremental fixes — is tempting but not better. The audit's own §7 lists
at least 4 separate "priority N" PRs to reach what the queue design
achieves structurally, and none of them removes the `_scanInFlight /
_liveScanDeferred / _forceRescanCompleter / _catchUpInFlight` flag matrix
that #2984 added yet another mitigation for. The refactor is worth doing;
just not in the exact shape drafted.

---

## 2. Verified claims

Load-bearing claims from the design the reviewer checked against source and
confirmed.

### 2.1 SDK §4 claims — 6/6 verified

All six SDK-behaviour claims in §4 of the design match matrix-dart-sdk 7.0.0
source (`~/.pub-cache/hosted/pub.dev/matrix-7.0.0/`):

| Claim | Citation | Status |
| --- | --- | --- |
| `onTimelineEvent` fires per `EventUpdateType.timeline` event | `client.dart:2967–2968` | ✓ |
| `limited=true` calls `deleteTimelineForRoom` | `client.dart:2718–2722` | ✓ |
| `CachedStreamController` caches only the last value | `cached_stream_controller.dart:14–17` | ✓ |
| `Timeline.events` purged on limited sync | `timeline.dart:379–382` (the doc cites 345–347; the method is `_removeEventsNotInThisSync` and the body runs at the later line range in 7.0.0 current) | ✓ with citation drift |
| Wake-from-background: sync loop restart fires `onTimelineEvent` normally | `client.dart:2332–2356`, no special-casing on the stream | ✓ |
| Killed process: sync token persisted, first resync may be `limited=true` | `client.dart:2468–2469` (`storePrevBatch`) | ✓ |

### 2.2 `sync_db` is the right home

At review time, `lib/database/sync_db.dart` showed `schemaVersion = 11`
with a well-exercised `onUpgrade` migration at `sync_db.dart:1005–1099`.
Adding a v12 table for `inbound_event_queue` matches the idiom the file
already used — 10 additive migrations in place. The design's "default
sync_db" call is correct. (v12 and the table itself land in this PR.)

### 2.3 `AppLifecycleRescanObserver` really was deleted in #2983

Confirmed via grep. The design's §10.1 statement is accurate.

### 2.4 Live-scan and processor internal flags are not externally referenced

`_seenEventIds`, `_completedSyncIds`, `_inFlightSyncIds`, `_scanInFlight`,
`_liveScanDeferred`, `_forceRescanCompleter`, `_deferredCatchup` — zero
external code-level readers outside the files that define them. Deletion
does not break cross-module contracts.

### 2.5 `MatrixStreamLiveScanController` has exactly two external call
sites and they are both pipeline-internal

`matrix_stream_consumer.dart:117` instantiates it; `matrix_stream_signals.dart:20,37`
takes it by constructor injection. Both files are part of the pipeline
being rewritten. No other module reaches into the controller.

### 2.6 Marker monotonicity is enforced today

`matrix_stream_processor.dart:741` calls
`msh.shouldAdvanceMarker(...)` → `matrix_stream_helpers.dart:87–100` →
`TimelineEventOrdering.isNewer`, which rejects a candidate older than the
stored marker. **This guard is load-bearing** — see §3.2 below.

### 2.7 The `runWithDeferredMissingEntries` depth counter exists exactly
as the reviewer suspected

`sync_sequence_log_service.dart:143–156`:

```dart
Future<T> runWithDeferredMissingEntries<T>(
  Future<T> Function() action,
) async {
  _deferredMissingEntriesDepth++;
  try {
    return await action();
  } finally {
    _deferredMissingEntriesDepth--;
    if (_deferredMissingEntriesDepth == 0 && _pendingMissingEntriesDetected) {
      _pendingMissingEntriesDetected = false;
      _emitMissingEntriesDetected();
    }
  }
}
```

Today, the pipeline wraps one ordered slice with this:
`matrix_stream_processor.dart:398` — a depth-1 window covering **all**
events in the slice. Moving to per-event apply opens N depth-1 windows,
each emitting independently.

---

## 3. Concerns raised

Ordered by severity: correctness → data loss → observability →
implementation cost. Each names the specific code reference, states why
it matters, and proposes a mitigation.

### 3.1 Concern (correctness) — Deferred missing-entries nudges fragment N→1 → N→N

**Issue.** The one-event-at-a-time worker drops the slice-level coalescing
of `onMissingEntriesDetected` emissions. A burst of 80 events with 5
gaps, applied as a slice today, emits 1 `_emitMissingEntriesDetected()`
and triggers 1 round of `BackfillRequestService._processBackfillRequests`.
Under the queue, 5 of the 80 per-event applies each emit — 5 nudges.
`BackfillRequestService._isProcessing` (`backfill_request_service.dart:68,
116, 223`) reduces the effective work to one actual round, **but only
because the first nudge wins the gate and the rest drop their work on
the floor.** Lost on the floor:

- Diagnostic log lines per nudge (more, not fewer).
- Potential for later-arriving gaps in the same burst to be processed
  in a separate round once `_isProcessing` clears.
- Backfill-request coalescing on the outbox side — today one burst
  produces one `SyncMessage.backfillRequest`; under the queue it produces
  up to N.

**Reference.** `sync_event_processor.dart:1791–1806` (wrapper),
`matrix_stream_processor.dart:398` (slice-level call site),
`sync_sequence_log_service.dart:143–156` (depth-counter implementation),
`backfill_request_service.dart:106–118` (nudge path).

**Why it matters.** The design declares "completeness layer unchanged"
(§9, §10.3). It isn't. The coalescing is a **property of the call site**,
not of `SyncSequenceLogService`. The design is silent on this. Behaviour
changes that affect observability (log volume) will be noticed
immediately after Phase 2 — and the sync team just spent three PRs
(#2982–#2984) bringing log volume down from 13 MB/17h to a target floor.
Regressing that is a poor outcome for a refactor billed as structural
cleanup.

**Mitigation (add to the design, pre-Phase-1).** The worker drain loop
should apply events in "committed-order batches" inside a single
`runWithDeferredMissingEntryNudges` window: drain up to K ≤
`SyncTuning.processOrderedChunkSize` events ready-now from the queue,
wrap the batch in one window, commit each entry after its own apply
succeeds. This preserves the one-table queue model and the one-worker
model, but reinstates the slice-level coalescing of nudges. Not a
trivial wording change: the design's §6.3 "drain until empty, one at a
time" prose needs explicit revision, and the `commitApplied` API needs
to allow "applied-but-window-open" transition.

### 3.2 Concern (correctness) — `commitApplied` marker advancement is non-monotonic as written

**Issue.** §6.5 says:

```text
commitApplied(entry) := {
  DELETE FROM inbound_event_queue WHERE queue_id = entry.queueId;
  IF entry.event_id starts with '$':
    settings_db.set('lastReadMatrixEventId', entry.event_id);
  settings_db.set('lastReadMatrixEventTs', entry.origin_ts);
}
```

Under the live-vs-bridge convergence race the design explicitly wants to
tolerate, the worker can apply an event with `origin_ts=100` before
applying a bridge-fetched event with `origin_ts=60`:

- T=100 wall: live delivers X (`origin_ts=100`). Worker applies X.
  Marker ts → 100.
- T=200 wall: bridge returns a slice covering `origin_ts 50..150`. UNIQUE
  drops X; events at ts=60, 70, 80 insert.
- T=201 wall: worker drains the queue `origin_ts` ascending from now on,
  so it applies the ts=60 event next. `commitApplied` sets marker ts → 60.

Marker regression. This breaks the "bridge /messages from lastReadMatrixEventTs
forward" invariant (§6.5 crash recovery paragraph), because next startup
will now bridge from ts=60, re-fetching everything between 60 and the
actual high-water mark.

**Reference.** The existing code does NOT have this bug — see §2.6.
`matrix_stream_helpers.dart:87–100` (`shouldAdvanceMarker`) is monotonic
by `TimelineEventOrdering.isNewer`. The queue design's commitApplied
ignores this guard.

**Why it matters.** Not a correctness bug on `apply` itself (idempotent
against vector-clocks), but it makes the startup bridge fetch unbounded
in the bad case. The bad case is exactly the "live + bridge convergence"
scenario the doc (§5.2) says the UNIQUE constraint solves.

**Mitigation.** Design must specify: `commitApplied` only advances
`lastReadMatrixEventTs` when `shouldAdvanceMarker(candidateTs=entry.originTs,
candidateEventId=entry.eventId, lastTimestamp=current, lastEventId=current)`
returns true. Delete from queue always; advance marker conditionally.
One-line fix in the design text; big fix to omit.

### 3.3 Concern (data loss / decryption race) — `Event.fromJson` round-trip captures ciphertext if serialised pre-decryption

**Issue.** §6.1 stores `Event.toJson()` in `raw_json`; the worker
reconstructs via `Event.fromJson(room, json)` at peek time. This round-trip
is **safe only if the Event is fully decrypted at enqueue time.**

The SDK's decryption pipeline (`client.dart:2909`) runs before
`onTimelineEvent.add(timelineEvent)` for events whose session keys are
available. But for events that arrive **before** their Megolm session
key (a common case on wake or first-device-handshake), the SDK places
them on `_eventsPendingDecryption` and fires `onTimelineEvent` for the
encrypted form. Decryption then re-fires later when the key arrives,
mutating the same `Event` object in place or re-emitting.

Under the queue design:
- Encrypted Event hits the live stream producer at T=100 → enqueue
  serialises `raw_json` with `type=m.room.encrypted`, ciphertext content.
- Session key arrives at T=105 → SDK decrypts. But the serialised JSON
  in the queue is still the ciphertext.
- Worker peeks at T=110 → `Event.fromJson(room, ciphertext_json)` →
  undecrypted Event hits `_eventProcessor.apply` → the apply path fails
  to classify, may fall into the retry tracker, never decrypts.

**Reference.** `matrix-7.0.0/lib/src/encryption.dart:283–295` (decryption
in-place construction of a new Event replacing encrypted content);
`client.dart:2909–2916` (_eventsPendingDecryption); `event.dart:238–262`
(toJson serialises `content` which is whatever the in-memory field
holds). The design's §6.2 notes "construction is deferred until peek
time so the queue itself doesn't hold SDK objects" — this reasoning
actively masks the concern because it treats the Event as a JSON-only
value.

**Why it matters.** E2EE is the baseline for this app (sync between
user's own devices). Megolm key rotation and first-handshake gaps are
not rare edge cases. Today, the pipeline either applies an Event once
it's fully decrypted or keeps re-polling via live scan (which re-reads
`tl.events` — which the SDK mutates in place on decryption). The queue
snapshots the pre-decryption state and forgets to re-snapshot. Silent
data drop.

**Mitigation.** Two options, design must pick one and document:

- **Option A — Only enqueue after decryption settles.** The live
  producer holds off on enqueue for `type=m.room.encrypted` events; the
  SDK's decryption callback re-emits and that is what enqueues. Requires
  a second listener point or a delayed-enqueue queue-before-the-queue.
  Side effect: decryption failures never enqueue, so we lose observability
  of permanent decryption failures unless the design adds a separate
  tracker.
- **Option B — Enqueue raw; worker re-resolves via room.getEventById
  at peek time** rather than `Event.fromJson`. The SDK's cached event
  state reflects latest decryption. `Event.fromJson` becomes a fallback
  for rows where `room.getEventById` returns null (e.g. after a
  `limited=true` purge).

The design picks option A-implicitly (§6.1 says worker deserialises at
drain time), but A is not what §6.1 actually describes.

### 3.4 Concern (silent unintended enqueue) — Producer code has no event-type filter

**Issue.** §7.1's live producer:

```dart
sessionManager.timelineEvents.listen((event) {
  if (event.roomId != currentRoomId) return;
  unawaited(queue.enqueueLive(event));
});
```

Today, `MatrixEventClassifier.isSyncPayloadEvent` is the gate deciding
which events drive apply work, called at
`matrix_stream_processor.dart:508` and `:646`. `onTimelineEvent` surfaces
more than sync-payload messages: state events (`m.room.member`,
`m.room.name`, …) appear in the timeline array when they have server-
assigned event IDs and are included; redactions (`m.room.redaction`)
are included; receipts and typing are NOT (they go through
`_handleEphemerals`, `client.dart:2844–2868`).

The queue will accept:
- Every state event (including Megolm key rotation events, which are
  frequent).
- Every redaction.
- Every sync-payload message.

The apply worker then pulls each one out, calls into
`SyncEventProcessor.apply`, and the classifier eventually rejects. But
it has cost both ways: queue depth grows faster than expected, `raw_json`
bytes accumulate, and the drain rate is slower per useful event.

**Reference.** `matrix_event_classifier.dart` (definition, small file);
§7.1 of the design (unfiltered producer).

**Why it matters.** This is not a correctness issue. It is a capacity-
planning issue the design's §6.6 table doesn't cover: "O(10) entries at
any moment" and "capped at ~1000" assume the queue holds only payload
events. In practice a full E2EE Megolm key rotation under a chatty
re-sync can pump hundreds of state events into the queue in seconds.

**Mitigation.** Design must specify: `enqueueLive` calls
`MatrixEventClassifier.isSyncPayloadEvent(event)` and silently drops
non-payload events. Same for `enqueueBatch`. Cheapest place to apply
the filter; fits the single-responsibility story the design tells.

### 3.5 Concern (cross-DB atomicity) — `commitApplied`'s "one DB batch" isn't

**Issue.** §6.5 says "in one DB batch: DELETE FROM inbound_event_queue
… settings_db.set(...)". But `inbound_event_queue` lives in `sync_db`
(`sync.sqlite`) and the read-marker lives in `settings_db`
(`settings.sqlite`). There is no cross-DB transaction primitive in
drift/sqlite. The two writes are sequential and a crash between them
leaves them inconsistent.

**Reference.** `lib/features/sync/matrix/last_read.dart:18–24` (marker
lives in `settingsDb`). `lib/database/sync_db.dart:13` (`syncDbFileName =
'sync.sqlite'`, separate DB). Compare with the design's
"same DB batch" language.

**Why it matters.** Most crash orderings are benign:
- DELETE then crash → marker not advanced → re-apply on restart,
  idempotent. Fine.
- Marker advance then crash → queue entry still there → re-apply,
  idempotent. Fine.
- **But:** marker advance, queue DELETE, journal row actually depends
  on `_sequenceLogService` state that never got written because apply
  had already returned? Only a concern if the apply path splits its
  writes across DBs too (it does: journal rows in journal_db, sequence
  log in sync_db). None of these is a correctness regression on top of
  today, but the design's framing makes it read as if cross-DB atomicity
  is guaranteed, and it isn't.

**Mitigation.** Drop the "one DB batch" claim. State explicitly: apply
commits journal writes; then sync_db transaction deletes queue entry
+ writes a durability record (could be a `last_applied_event_id` row in
the queue table itself); then settings_db marker advance. Crash between
steps means we re-apply on restart, idempotent. Also: move the
`lastReadMatrixEventTs` marker into `sync_db` (same DB as the queue)
so the delete + marker-advance can become one real transaction, and
leave `settingsDb` only for user-preference things.

### 3.6 Concern (Event holds live Room reference) — §6.2 caveat is too soft

**Issue.** §6.2 says "the in-memory Event object is not persisted (it
holds back-references to the SDK's state)". This is literally true but
glosses over what "back-references" actually means:

`event.dart:58` declares `final Room room;` as a required field.
`Event.fromJson(room, json)` at `event.dart:206–236` requires the Room
to be passed in (it's not in the JSON). `Event` then uses
`room.client.database` for `downloadAndDecryptAttachment`
(`event.dart:828`), `room.unsafeGetUserFromMemoryOrFallback` for sender
lookup (`event.dart:55`), and Room state for decryption path.

Scenarios where the queue has rows but the Room is gone:

- User logs out mid-session. Queue has 50 entries. On next login with a
  different account, the queue's `room_id` entries point to a room the
  new Client doesn't know about.
- User switches away from the sync room in-app (rare, but exists).
- Crash + restart where the Client is created before the Room snapshot
  is ready; worker peek happens in that window.

**Reference.** `event.dart:58` (room field), `event.dart:206–236`
(fromJson signature), `sync_room_manager.dart:55–62` (`_currentRoom`
can be null for a window).

**Why it matters.** Not a frequent hit in normal usage but a real
edge case. Today, `MatrixStreamLiveScanController` reads `tl.events`
directly against the current Room — if there's no Room, there's no
slice. The queue persists event JSON past Room lifetime, so we get a
stranded entry the worker can't materialise.

**Mitigation.** Worker's peek path checks: is the current Room the one
`room_id` refers to? If no, DELETE the stranded entry (or move to a
"stranded" side table for diagnostics). Log once per session. Add to
the §14 open-questions list explicitly.

### 3.7 Concern (Phase 2 flag-off data loss) — Bootstrap entries strand in queue

**Issue.** §12 Phase 2 says "flag to false" is the rollback. Works for
live-path events (they continue arriving via `onTimelineEvent`, which
the old path reads directly). **Does not work for bootstrap entries.**
`collectHistoryForBootstrap` only writes to the queue; it does not
write to journal. If the flag flips off mid-bootstrap:

- Queue contains 500 bootstrapped events.
- Worker stops draining (new code path, flag off).
- Old path doesn't read the queue.
- 500 events stay in `sync_db` forever until the flag is flipped back
  on (at which point they may be stale — rows still exist but
  server-side the events may have been retained past them).

**Reference.** §7.3 (`BootstrapSink` → `queue.appendBootstrapPage`,
no alternate path); §12 Phase 2 ("flag to false").

**Why it matters.** Real deployment scenario: a user runs "Fetch all
history" with the flag on, it takes 20 minutes, something goes wrong,
support tells them to toggle the flag. They lose 20 minutes of
pagination unless they re-run. Refactor-for-reversibility is the design's
own framing.

**Mitigation.** Document "drain before disable": any transition from
`useInboundEventQueue=true` to `false` while the queue is non-empty
must either (a) drain the queue first (running the worker to
completion), or (b) refuse the flag change with a user-facing explanation.
Also: bootstrap's "Fetch all history" UI hides behind the flag already
(§11), but the queue's PERSISTENT state doesn't go away when the button
hides.

### 3.8 Concern (observability regression) — Queue opacity for debugging a specific event's path

**Issue.** Today, a specific event's journey through the pipeline is
greppable across `signal.clientStream`, `liveScan.summary`,
`batch.summary`, `attachmentIndex.record`, `attachment.observe`,
`processor.apply`. The event ID appears in each log line. Post-refactor,
the equivalents are `queue.enqueue (eventId=...)`, `queue.peek`,
`processor.apply`, `queue.commitApplied (eventId=...)`. The design
doesn't enumerate the logging plan.

**Reference.** §10.2 acknowledges Drift stream coalescing loss but
doesn't address the observability loss.

**Why it matters.** The sync team's operational posture for this
feature has been "follow an event through the logs when a user
reports a missed message". Three hours of debugging last week
(#2984) relied on exactly that. Changing the log shape without a
matched plan regresses operations immediately.

**Mitigation.** Design must spell out the per-event log lines it
will emit. Target: identical grep surface — given an eventId, the
log contains at minimum an enqueue/apply/commit triple with
producer attribution. Should not be deferred to Phase 2
"measurement".

### 3.9 Concern (identifier imprecision) — Design §10.1 names the wrong file for several fields

**Issue.** §10.1 lists `_scanInFlight`, `_scanInFlightDepth`,
`_scanEpoch`, `_scanStartedAt`, `_liveScanDeferred`, `_liveScanTimer`,
`_forceRescanCompleter`, `_deferredCatchup` under "MatrixStreamProcessor"
deletions. They are not in `matrix_stream_processor.dart`; they live
in:
- `matrix_stream_live_scan.dart` (`_liveScanTimer`, `_scanInFlight`
  group).
- `matrix_stream_catch_up.dart` (`_forceRescanCompleter`,
  `_deferredCatchup` group).

**Why it matters.** Low severity — a reviewer of the Phase 1 PR will
notice the discrepancy immediately. But it suggests the design
author lost track of the exact class-boundary the refactor crosses,
which matters because those classes have different test files
(`matrix_stream_live_scan_test.dart`, `matrix_stream_catch_up_test.dart`)
and different responsibilities. The deletion plan's test-impact scope
is implicitly 2× larger than §10.1 implies.

**Mitigation.** Correct the file attribution in §10.1. Verify the
test files (listed below) are explicitly in the "to be deleted or
rewritten" set.

### 3.10 Concern (Phase 0 diagnostic coverage insufficient)

**Issue.** §12 Phase 0 measures two things: `limited=true` frequency
and `onTimelineEvent` ordering. Neither measures the design's most
load-bearing assumption — that **apply throughput in the one-event
serialised model meets the catch-up rate we have today**. Today's
chunked transaction commits up to 20 events per transaction with
Drift stream coalescing. The design's one-per-transaction is a
20× ratio shift on stream notifications; the design concedes
"needs measurement" (§10.2, §14.1) but defers it to post-ship.

Additionally, the 48-hour capture window (§12 Phase 0) is described
without reference to mobile post-wake behaviour, which is where
`limited=true` is expected to cluster. A desktop-only capture would
under-count; a mobile capture that catches one background cycle
would dominate. Needs explicit platform coverage.

**Reference.** `SyncTuning.processOrderedChunkSize=20` (tuning.dart:143,
with a comment specifically explaining the trade-off the design
undoes). `client.dart:2332–2356` (SDK sync restart on wake — not
platform-gated but heavily platform-correlated via OS background
policy).

**Why it matters.** If Phase 0 finds apply rate under the new model
is 3× slower than today during a catch-up burst, the whole design
is not an improvement — we'd move from a freeze-on-writer-lock
failure mode (which P1a already fixed in #2981) to a slow-drain
failure mode. Need to know before code is written, not after.

**Mitigation.** Add to Phase 0:
- Apply-throughput metric: events/sec during live, during catch-up,
  during bootstrap. Capture baseline. Target in phase 0 diagnostic
  PR, not post-ship.
- Drift stream emission count per minute from journal watchers
  during a catch-up burst. Baseline the coalescing benefit.
- Platform split: explicitly capture on both desktop **and** mobile,
  with at least one mobile background wake cycle observed.
- An extra diagnostic: log every `timeline?.prevBatch` on a limited
  sync, alongside the stored marker timestamp, so the gap size the
  bridge would have to span is measurable — not just the frequency
  of limited syncs.

---

## 4. Missing considerations

Topics the design is silent on that must be addressed before Phase 1.

### 4.1 How does the queue interact with `UserActivityGate`?

The audit §3 (point 3) notes today's inbound pipeline bypasses the
activity gate, and that is part of the reason the 3,011 lines/s
burst at 15:12:49 ran during active user time. The design moves the
ingestion boundary without stating whether the worker honours the
activity gate. If not, the gate work done in #2981-era for outbox
has no analogue on inbound — this design perpetuates the existing
deficiency.

### 4.2 Bootstrap under `limited=true`

§7.3 describes cold-start bootstrap via `collectHistoryForBootstrap`
and §7.2 describes limited-sync bridge. What if a `limited=true` fires
in the middle of a bootstrap? Bootstrap is paginating historical
events, bridge wants to fetch forward-to-now from marker. Neither
owns the room's live state while the other runs. The design's
implicit answer is "both write to the queue, UNIQUE deduplicates" —
OK on insert but which one advances the marker, and what happens
when bootstrap's `originTs` values are far in the past and bridge's
are recent? See §3.2 marker-regression concern; these two producers
aggravate the hazard.

### 4.3 Retry policy under the queue

The design says `attempts` and `next_due_at` columns absorb today's
`RetryTracker` semantics. But today's retry tracker is in-memory
with a 10-minute TTL (per the audit §4). Moving retries into durable
storage changes semantics subtly: a retry scheduled at T=10 will
still attempt at T+backoff even after an app restart. Today, restart
clears the retry tracker. Is the new behaviour intentional? Probably
yes (durability is the point of the queue) but the design doesn't
say, and the follow-on effect is that a wedge on one bad event can
outlast an app restart unless explicit bookkeeping drops the entry.

### 4.4 Back-pressure signal path to UI

§6.6 mentions `QueueStats.depth` on the Sync Settings page. But when
bootstrap sees the high-water mark and returns a pending future,
what does the user see? Progress indicator. Which widget updates
from which stream? None of this is specified. Today,
`backfill_settings_page.dart` shows gap counts; the new three-signal
panel (§11) needs a live stream, not just a pull API.

### 4.5 Test-suite impact not accounted for

Subagent audit found **7 test files** that reference the
to-be-deleted classes. The design's §13 lists the new tests but
doesn't call out the existing tests that need migration or deletion:

- `matrix_stream_live_scan_test.dart` (11+ cases)
- `matrix_stream_helpers_test.dart` (4 cases for `buildLiveScanSlice`)
- `matrix_stream_signals_test.dart` (6 cases)
- `matrix_stream_consumer_signal_live_scan_test.dart`
- `matrix_stream_catch_up_test.dart`
- `matrix_stream_processor_test.dart` (22+ `processOrdered` call sites)
- `matrix_stream_consumer_test.dart`

Several of these are integration-shaped and test cross-module
behaviour the new design reshapes, not deletes. The Phase 3 PR's
size is underestimated.

### 4.6 Feature flag plumbing not in place

At review time, no `useInboundEventQueue` flag existed in the codebase.
The design assumed trivial flag plumbing; propagation still needs to
reach `matrix_stream_consumer`, `MatrixService.init`, the Sync Settings
UI (for the Fetch-all-history button), and the worker construction
itself. Three sites minimum, and the flag must be readable synchronously
at init time (i.e. settings_db fetch before first wiring), not async —
the design's §12 Phase 1 says "add flag, default false, nothing wired"
but doesn't spell out where the flag is read. (This PR lands the flag
itself — see `useInboundEventQueueKey` — but not the wiring.)

---

## 5. Revised phase gates

The design is salvageable. For each phase, these additional
conditions should be met before advancement.

### Phase 0 — Diagnostic PR

- [ ] Apply-throughput baseline metric landed (events/sec during
  live, catch-up, bootstrap). Not just line-count.
- [ ] Drift journal-watcher emission rate metric landed.
- [ ] Logging plan for Phase 1 enqueue/peek/commit triple specified
  in advance, not improvised.
- [ ] 48h capture covers at least one mobile background wake on at
  least one tester device.
- [ ] `timeline?.prevBatch` logged on every `limited=true`.
- [ ] Design doc revised to incorporate concerns 3.1–3.7 (explicit
  edits, not just "ack").

### Phase 1 — InboundEventQueue + bridge (new code, flag-gated, unwired)

- [ ] Worker drain uses batched `runWithDeferredMissingEntryNudges`
  windows (concern 3.1).
- [ ] `commitApplied` goes through `shouldAdvanceMarker`
  (concern 3.2).
- [ ] `enqueueLive` / `enqueueBatch` apply
  `MatrixEventClassifier.isSyncPayloadEvent` filter at boundary
  (concern 3.4).
- [ ] Decryption policy explicit and tested:
  - A producer-level test that an encrypted-then-decrypted Event
    round-trips correctly (concern 3.3).
- [ ] Room-lifetime handling explicit with a per-session stranded-
  entry sweep (concern 3.6).
- [ ] `lastReadMatrixEventTs` moved to `sync_db` **or** design
  explicitly accepts and documents the cross-DB non-atomicity
  (concern 3.5).
- [ ] Feature flag wired through all 3 sites (concern 4.6).

### Phase 2 — Flag-on switch

- [ ] Drain-before-disable rule enforced (concern 3.7).
- [ ] Parallel log emission (old + new) for the apply-throughput
  metric, compared against Phase 0 baseline. Go/no-go gate.
- [ ] Bootstrap concurrency with limited-sync bridge tested on
  fake timeline (concern 4.2).
- [ ] UI back-pressure story shipped (concern 4.4).
- [ ] UserActivityGate behaviour explicit (concern 4.1): either the
  worker honours it, or a note in Sync Settings explains it
  doesn't.

### Phase 3 — Old path deletion

- [ ] Test-migration plan for the 7 affected test files
  (concern 4.5), executed without deleting coverage.
- [ ] Explicit rollback plan beyond "git revert" — queue table stays
  in schema, document that reverting code only leaves an orphaned
  table that a future migration must drop, not trusting git revert
  to undo schema.

---

## 6. Go / no-go recommendation

| Phase | Ship as currently drafted? | Conditions |
| --- | --- | --- |
| Phase 0 | ✗ | Expand diagnostics per §3.10 and §5. Also incorporate concerns 3.1–3.7 as design-doc revisions (text-only, no code). |
| Phase 1 | ✗ | Requires the nine gates in §5 Phase 1. The `runWithDeferredMissingEntryNudges` fragmentation (§3.1) and `commitApplied` non-monotonicity (§3.2) are the hard blockers. |
| Phase 2 | ✗ | Drain-before-disable rule plus apply-throughput comparison gate. |
| Phase 3 | ? | Re-evaluate after Phase 2 data lands. Deletion list is probably fine on code; test-migration is the hidden cost. |

---

## 7. What this review does NOT say

- It does not say "abandon the refactor." The problem the design
  attacks is real, the two-layer separation is genuinely cleaner,
  and the audit's alternative (4 incremental PRs) reaches a smaller
  fraction of the cleanup at probably similar net cost.
- It does not say "the author missed obvious things." Several of the
  concerns here depended on reading code the author hasn't touched
  in weeks (the depth counter; the marker monotonicity helper); they
  are not things the doc's §14 would catch.
- It does not say "the queue should live elsewhere." `sync_db` is
  the right home; the design is correct on that call.

What it does say: the design is a 90% draft. The remaining 10% is
four concrete correctness fixes, three observability fixes, and a
diagnostic-PR expansion. Land those, then ship Phase 1.
