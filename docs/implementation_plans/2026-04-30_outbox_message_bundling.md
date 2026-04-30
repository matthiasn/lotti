# Outbox Message Bundling — Implementation Plan

Date: 2026-04-30
Status: Approved (open questions resolved interactively)
Related work:
- PR #3009 `feat: agent wake sync bundling` (merged) — wake-cycle bundling we mirror here.
- PR #2957 `feat: bundled attachments` (closed) — earlier media-attachment bundling attempt; explicitly out of scope.
- ADR 0013 — outbox priority queue.

## 0. Goals & Non-Goals

**Goals**
- Reduce sync message volume by ~10× when the outbox has many small text-only items
  (agent suggestions, checklist bursts, sync backfill replay).
- Bundle at the **dequeue side** (the `OutboxProcessor`), so existing enqueue paths
  and per-row metadata (priority, payloadSize, subject, vector clocks, sequence-log
  recording) keep working untouched.
- Send media-attachment items (image/audio) **unchanged and individually**,
  preserving existing receiver behavior for those types.
- Preserve strict ordering inside the same priority/createdAt slice.

**Non-Goals (this PR)**
- No changes to incoming-attachment dedup work in
  `docs/implementation_plans/2026-03-12_sync_inbox_attachment_dedupe_and_logging.md`
  (separate effort).
- No bundling of **media attachments** (images, audio). Note that JSON sidecar
  files (e.g. `/agent_bundles/*.json`, `/outbox_bundles/*.json`) are technically
  Matrix attachments too — throughout this plan, "attachment" means **media
  attachment** only. PR #2957 is closed; explicitly out of scope here.
- No changes to wake-cycle agent bundling (PR #3009): outbox bundles will pass
  through `SyncAgentBundle` as a single child, not unpack it.
- No changes to the `Outbox` table schema. Bundle is a *transport-time* construct.

## 1. Architecture Overview

The current pipeline (post #3009):

```text
enqueueMessage(msg) ──► Outbox row (priority, filePath?, payloadSize, subject)
                                    │
                                    ▼
                       OutboxProcessor.processQueue()
                                    │
                                    ▼
                        claim()  ──►  send(msg)  ──►  markSent()
                        (one row)     (one Matrix event)
```

We change *only* the dequeue side:

```text
OutboxProcessor.processQueue()
        │
        ▼
claimNextBatch(maxSize=kOutboxBundleMaxSize)
        │
        ├─ if first claimed row has filePath != null  ──► send single (unchanged path)
        │
        └─ else claim consecutive text-only rows up to maxSize, stopping
           when the next pending row is a media attachment or absent
                │
                ▼
           build SyncOutboxBundle(children: [SyncMessage,…])
                │
                ▼
           send bundle  ──► markSentBatch on every row in the batch (atomic)
                          ──► on failure: markRetryBatch on every row in the batch
```

On the **receiver** side, an unpack step in `SyncEventProcessor` walks the
bundle's children in order and dispatches each child through its existing
handler, exactly as if N individual messages had arrived.

Why dequeue-side and not enqueue-side:
- Enqueue paths already do merge/dedup/sequence-log work per type. Touching them
  risks ordering and VC bugs.
- Dequeue-side bundling is symmetric to PR #3009's wake-side bundling: we reuse
  the proven "buffer → emit one envelope → child-iterate on receiver" shape.
- A backfill replay that floods the outbox with 100+ messages is naturally
  batched without enqueue-time assumptions.

## 2. Resolved Open Questions

- **Boundary rule**: Claim consecutive text rows up to 50, stop at the first
  media attachment. (Q1 was actually a no-op — both phrasings collapse to this
  rule.)
- **Priority crossing**: Bundle freely across priorities. Order is
  `(priority ASC, createdAt ASC)`; the first 50 text rows in that order go into
  one bundle regardless of priority changes within the run.
- **Flag default**: `useOutboxBundlingFlag` defaults to **off**. Users opt in via
  the flags settings page. We flip the default in a later release once the
  receiver code has been in the field long enough.

## 3. New Types & Touch Points

### 3.1 New constant

`lib/features/sync/tuning.dart`:

```dart
/// Maximum number of text-only outbox rows packed into a single SyncOutboxBundle.
/// Tweakable; tested up to 100. Media-attachment rows (filePath != null) are
/// never bundled.
static const int outboxBundleMaxSize = 50;
```

### 3.2 New SyncMessage variant

`lib/features/sync/model/sync_message.dart` — add a freezed factory:

```dart
const factory SyncMessage.outboxBundle({
  required List<SyncMessage> children,
  String? jsonPath,                 // file-backed delivery, like SyncAgentBundle
  String? originatingHostId,
}) = SyncOutboxBundle;
```

Run `make build_runner`.

**Invariants enforced in code**:
- Inline bundles carry children directly; file-backed/sidecar bundles travel
  on the wire with `children: []` plus a `jsonPath` referencing the
  attachment that holds the real children.
- No child is itself a `SyncOutboxBundle` (no nested bundles).
- No child carries a media attachment.

### 3.3 New repository method

`lib/features/sync/outbox/outbox_repository.dart`:

```dart
/// Claim a contiguous run of pending rows in priority/createdAt order:
///  - if the head row has filePath != null, return [headRow] (single attachment),
///  - else return up to [maxSize] consecutive rows whose filePath is null,
///    stopping at the first attachment row or when the queue is exhausted.
/// All returned rows are atomically transitioned to status=sending with the
/// same lease.
Future<List<OutboxItem>> claimNextBatch({
  required int maxSize,
  required Duration leaseDuration,
});
Future<void> markSentBatch(List<int> ids);
Future<void> markRetryBatch(List<int> ids);
```

This is implemented as a single drift transaction so the lease, status, and
ordering invariants hold under concurrent drains.

### 3.4 Files modified

| File | Change |
|---|---|
| `lib/features/sync/tuning.dart` | Add `outboxBundleMaxSize`. |
| `lib/features/sync/model/sync_message.dart` (+ generated) | Add `SyncOutboxBundle`. |
| `lib/features/sync/outbox/outbox_repository.dart` | Add `claimNextBatch`, `markSentBatch`, `markRetryBatch`. |
| `lib/features/sync/outbox/outbox_processor.dart` | Switch from `claim()` to `claimNextBatch()`; build bundle when batch > 1; send + mark batch atomically; preserve all retry / failure-diagnostics behavior. |
| `lib/features/sync/outbox/outbox_service.dart` | Pattern-match `SyncOutboxBundle` in the freezed switch; the dequeue-built bundle is the only construction site, so no enqueue path is added. |
| `lib/features/sync/matrix/matrix_message_sender.dart` | Add `_sendOutboxBundlePayload` mirroring `_sendAgentPayload`: if serialized JSON > inline cap, write to `/outbox_bundles/<bundleId>.json`, upload, send text event with jsonPath; otherwise inline. |
| `lib/features/sync/matrix/sync_event_processor.dart` | Add `_resolveOutboxBundle` and unpack: iterate children in order, dispatch each through its existing resolver/applier. Sequence log records each child's VC, never the bundle itself. |
| `lib/features/sync/ui/view_models/outbox_list_item_view_model.dart` | Label for `SyncOutboxBundle` in outbox UI ("Outbox bundle (N)"). |
| `lib/l10n/app_*.arb` (six files) | Add `syncPayloadOutboxBundle` (informal tone for de/fr/es; formal for ro). Run `make l10n` and `make sort_arb_files`. |
| `lib/utils/consts.dart` + `lib/database/journal_db/config_flags.dart` + `flags_page.dart` + ARBs | Add `useOutboxBundlingFlag` (default **off**) so users opt in. Update `expectedFlags` in `test/database/database_test.dart`. |
| `CHANGELOG.md` | Entry under current pubspec version. |
| `flatpak/com.matthiasn.lotti.metainfo.xml` | Matching release-note bullet. |
| `docs/adr/0014-outbox-message-bundling.md` | New ADR documenting the design. |

## 4. Step-by-Step Implementation Order

Each step ends in a **green analyzer + targeted tests passing** checkpoint
before moving on.

**Step 1 — Constant and model**
1. Add `outboxBundleMaxSize = 50` to `SyncTuning` in `tuning.dart`.
2. Add `SyncOutboxBundle` factory to `sync_message.dart`.
3. `make build_runner`.
4. Add an exhaustive switch arm in any pattern matches that would otherwise stop
   compiling (outbox UI label, Matrix sender, sync event processor). Stub them
   to throw `UnimplementedError` — tests in the next steps will replace stubs.

**Step 2 — Config flag**
1. Add `useOutboxBundlingFlag` constant in `consts.dart`.
2. Register it in `config_flags.dart` with default `status: false`.
3. Update `expectedFlags` test list.
4. Add UI row in `flags_page.dart` with icon + ARB-backed title/description.
5. Add ARB keys in all six languages (informal tone). `make l10n`,
   `make sort_arb_files`.

**Step 3 — Repository batch claim**
1. Add `claimNextBatch` to `OutboxRepository` and its drift transaction.
2. Add `markSentBatch(ids)` and `markRetryBatch(ids)`.
3. Unit tests for: head-is-attachment path, head-is-text-with-N-text-followers,
   head-is-text-then-attachment-at-position-K, exhausted queue, empty queue,
   lease behavior, mixed priorities packed into one bundle.

**Step 4 — Processor wiring**
1. In `OutboxProcessor.processQueue`, replace `claim()` with
   `claimNextBatch(maxSize: outboxBundleMaxSize, …)`.
2. Branch:
   - **Single item**: unchanged path — call existing `_send(item)` and
     `markSent`/`markRetry`. Attachments and trailing leftovers fall here. Zero
     behavior change.
   - **Multi-item**: build `SyncOutboxBundle(children: items.map(decodeMessage))`,
     call `_sender.send(bundle)`. On success → `markSentBatch(ids)`. On failure →
     `markRetryBatch(ids)` and apply the same backoff and retry-cap logic as
     today; head-of-queue diagnostics keep tracking the *first* row's subject.
3. Gate the multi-item branch behind `useOutboxBundlingFlag`. When disabled,
   `claimNextBatch(maxSize: 1)` is used so the codepath collapses to the
   original one-at-a-time behavior.

**Step 5 — Matrix sender**
1. Add `_sendOutboxBundlePayload` modeled on `_sendAgentPayload`. Write JSON
   to `/outbox_bundles/<uuid>.json` if oversized; otherwise inline; strip
   child payloads from the inline event when file-backed delivery is used.
   Reuse existing upload helper.

**Step 6 — Receiver unpack**
1. Add `_resolveOutboxBundle` in `sync_event_processor.dart`. Read inline
   children, fall back to attachment if `jsonPath` is set.
2. Iterate children in order, dispatch to existing per-type resolvers/appliers.
   No special bundle entry in the sequence log.

**Step 7 — UI**
1. `OutboxListItemViewModel` label arm for `SyncOutboxBundle`:
   `"Outbox bundle (${children.length})"`.
2. Localization in all six ARBs.

**Step 8 — Docs**
1. Write `docs/adr/0014-outbox-message-bundling.md`.
2. CHANGELOG and metainfo entry.

**Step 9 — Final verification (mandatory before reporting done)**
1. `dart-mcp.dart_fix`
2. `fvm dart format .`
3. `dart-mcp.analyze_files` — must be **fully green** per the project's
   zero-warning policy.
4. `dart-mcp.run_tests` on touched test files, then a full run.
5. Existing integration tests under `integration_test/sync_resilience_test.dart`
   must pass unchanged with the flag on.

## 5. Behavioral Correctness Against the Scenarios

**Scenario A — image at position 100 in a 500-row queue**
1. Tick 1: rows 1..50 → bundle of 50.
2. Tick 2: rows 51..99 → bundle of 49 (stops one before the image).
3. Tick 3: row 100 → image alone.
4. Ticks onward: bundles of 50 until the queue is empty.

**Scenario B — image at position 60**
1. Tick 1: rows 1..50 → bundle of 50.
2. Tick 2: rows 51..59 → bundle of 9.
3. Tick 3: row 60 → image alone.
4. Resumes with bundles of up to 50.

The brief's "10 in tick 2" wording matches this if we count 51..60 inclusively
*as* the boundary slice; the implementation stops one before the image, which
is the only safe interpretation when the next row carries a media attachment.

## 6. Backward Compatibility & Safe Rollout

- The new `SyncOutboxBundle` JSON shape is invisible to older receivers. They
  will receive a text event whose body contains a JSON they don't understand,
  log "unknown sync message", and skip — fail-soft, same as today for any
  unknown variant.
- Roll-out plan: ship the **receiver** code first (Step 6) with the flag
  default-off. Users opt in once their paired devices are on a version that
  unpacks bundles.
- An emergency kill-switch is present via the existing flags UI.

## 7. Testing Strategy — 100% Coverage of New Lines

The project rule is "every new line covered by `fvm flutter test --coverage`."
Tests are structured to mirror each new code unit.

### 7.1 Repository (Step 3)

`test/features/sync/outbox/outbox_repository_test.dart` — extend with:
- empty queue → `[]`
- single text row → `[row]`, status flips to sending
- 51 text rows → returns first 50, leaves 51 in pending
- 100 text rows → 50 + 50 + 0 across three calls
- text-text-attachment at pos 3 with `maxSize=50` → returns first 2
- attachment at head → returns `[head]` regardless of `maxSize`
- attachment-then-text → first call returns the attachment, second returns up
  to 50 text
- mixed priorities packed into one bundle (priority-0 text + priority-1 text)
- lease semantics: a row already in `sending` with expired lease becomes
  claimable again
- batch claim atomicity — a fault-injection mock makes a row update fail; the
  whole transaction rolls back
- `markSentBatch` / `markRetryBatch` apply to every id in one transaction

### 7.2 Processor (Step 4)

`test/features/sync/outbox/outbox_processor_test.dart` — extend with:
- **Scenario A reproduction**: 500 text rows + image at pos 100. Verify the
  exact send pattern: 1 bundle of 50, 1 bundle of 49, 1 single image, then
  bundles of 50 until empty.
- **Scenario B reproduction**: 60 rows, image at pos 60. Verify
  `[bundle(50), bundle(9), single(image)]`.
- All-text below cap: 7 rows → one bundle of 7.
- All-text exactly at cap: 50 rows → one bundle of 50, queue empty.
- Single image in queue: unchanged single-send path is taken (verified by
  `verifyNever` on bundle send).
- Bundle send success → every row in batch reaches `status=sent`.
- Bundle send failure → every row reaches `status=pending` with `retries`
  incremented; head-of-queue diagnostics mention the first row's subject;
  backoff timer scheduled exactly once.
- Bundle send timeout (`outboxSendTimeout`) → batch retry.
- Retry cap reached on a bundle: every row in the batch transitions to
  `status=error` and the queue advances.
- Flag off: `claimNextBatch(maxSize: 1)` is called and behavior collapses to
  one-at-a-time. Verified by intercepting the repo call.
- Concurrent drains do not double-send: the lease in `claimNextBatch` prevents
  a second call from claiming overlapping rows.

### 7.3 Sender (Step 5)

`test/features/sync/matrix/matrix_message_sender_test.dart` — extend with:
- Inline path: small bundle (e.g., 5 children) — JSON inline in text event,
  no upload.
- File-backed path: large bundle — upload called, jsonPath set, inline
  children stripped.
- Oversized single child (rare) — same fallback as today: bundle delivered
  as file.
- Upload failure → exception bubbles up to processor → triggers retry path
  verified in §7.2.
- Strip-children correctness: text event JSON length stays under inline cap.

### 7.4 Receiver / Event processor (Step 6)

`test/features/sync/matrix/sync_event_processor_test.dart` — extend with:
- Inline bundle of 3 mixed-type children (journal entity, entry link, agent
  entity) — each applied via its existing handler in order; sequence log
  records 3 VCs.
- File-backed bundle resolved from jsonPath — same outcome.
- Empty children list (defensive) — no-op, logged.
- One bad child mid-bundle (e.g., decode error) — that child is skipped and
  logged; subsequent children still applied. Asserts the existing
  per-message fail-soft contract.
- Older-client simulation: an unknown variant inside `children` is logged
  and skipped without aborting the bundle.
- Ordering: a sequence of three vector-clock-related writes for the same
  subject produces the same final state as if delivered as three individual
  messages.

### 7.5 UI / view model (Step 7)

`test/features/sync/ui/view_models/outbox_list_item_view_model_test.dart`:
- `SyncOutboxBundle(children=[…3 items])` → label is `"Outbox bundle (3)"`
  in `en`, with the localized form in each ARB language smoke-tested.

### 7.6 Config flag (Step 2)

- Existing flag tests in `test/database/database_test.dart` updated
  `expectedFlags`.
- Widget test for `flags_page` verifying the new row renders with the
  localized title (one language is enough per existing pattern).

### 7.7 Coverage gate

After all of the above:
- `fvm flutter test --coverage`
- Confirm `lib/features/sync/outbox/outbox_processor.dart`, the new lines in
  `outbox_repository.dart`, `matrix_message_sender.dart` (new lines),
  `sync_event_processor.dart` (new lines), and the new SyncMessage variant
  arms show 100% line and branch coverage in the lcov report.

### 7.8 Regression / ordering / integration

- **Existing `outbox_service_test.dart`** runs unchanged. All enqueue paths
  are untouched, so it must stay green by construction.
- **Existing `outbox_processor_test.dart`** retry/timeout/backoff cases run
  with `maxSize=1` (single-row batches) and must pass exactly as today.
- **`integration_test/sync_resilience_test.dart`** runs end-to-end against a
  real DB with the flag on. Verifies the user-visible ordering invariants
  (last-writer-wins, vector-clock convergence) and that 100+ message
  backfills converge to identical state on both peers.
- A new integration test creates Scenarios A and B against a real DB and
  verifies the wire-level send pattern (bundle counts, attachment-alone)
  and the receiver state.

## 8. Suggested Commit Sequencing

One PR, multiple commits:

1. `feat(sync): add SyncOutboxBundle model and bundle-size constant`
2. `feat(sync): add useOutboxBundlingFlag (default off)`
3. `feat(sync): claimNextBatch in OutboxRepository with batch mark helpers`
4. `feat(sync): bundle-aware OutboxProcessor with flag-gated single-row fallback`
5. `feat(sync): MatrixMessageSender support for SyncOutboxBundle (inline + file-backed)`
6. `feat(sync): receiver unpacks SyncOutboxBundle via SyncEventProcessor`
7. `feat(sync): localized "Outbox bundle (N)" label in outbox UI`
8. `docs(sync): ADR 0014, implementation plan, CHANGELOG, metainfo`
