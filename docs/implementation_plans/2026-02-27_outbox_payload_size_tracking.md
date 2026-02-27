# Outbox Payload Size Tracking

## Context

The sync system uses an outbox table (Drift ORM, `SyncDatabase`) to queue items for sending via Matrix. Currently, the outbox tracks status, retries, timestamps, and message content — but not the **byte size** of what is actually being sent. The goal is to record payload sizes at enqueue time so we can later visualize daily sync volume (MB sent per day) and break it down by type (audio, photo, JSON entry).

The outbox service already computes `fileLength` for attachments (audio/image files) at enqueue time (`outbox_service.dart:665-672`) but discards it after logging. The JSON message byte size is computed as `utf8.encode(jsonString).length` for accurate UTF-8 byte counts. This plan captures both values in a new database column.

## Implementation Steps

### Step 1: Add `payload_size` column and bump schema version (v4 → v5)

**File:** `lib/database/sync_db.dart`

- Add `IntColumn get payloadSize` to the `Outbox` table (nullable, default null, named `payload_size`). Stores total bytes (attachment file size + JSON message size).
- Bump `schemaVersion` from 4 to 5.
- Add migration: `if (from < 5) { await m.addColumn(outbox, outbox.payloadSize); }`.

### Step 2: Add daily volume aggregation query to `SyncDatabase`

**File:** `lib/database/sync_db.dart`

Add a method `getDailyOutboxVolume({int days = 7})` that runs a raw SQL query:
```sql
SELECT
  CAST(created_at / 86400000 AS INTEGER) AS day_epoch,
  SUM(COALESCE(payload_size, 0)) AS total_bytes,
  COUNT(*) AS item_count
FROM outbox
WHERE status = <sent>
  AND created_at >= <cutoff>
GROUP BY day_epoch
ORDER BY day_epoch
```
Returns a list of `OutboxDailyVolume` records (date, totalBytes, itemCount). This model class will be defined in a companion file.

### Step 3: Record payload size at enqueue time

**File:** `lib/features/sync/outbox/outbox_service.dart`

- In `enqueueMessage()`: compute `utf8.encode(jsonString).length` and include it in `commonFields` as `payloadSize`.
- In `_enqueueJournalEntity()`: add `fileLength` on top of the JSON length already in `commonFields`.
- In `_enqueueEntryLink()`: uses the JSON length from `commonFields` (no file attachment).
- In `_enqueueSimple()`: uses the JSON length from `commonFields`.
- On merge: update `payloadSize` via `updateOutboxMessage`.

### Step 4: Update `updateOutboxMessage` to preserve/update payload size

**File:** `lib/database/sync_db.dart`

When merging outbox items (`updateOutboxMessage`), the payload size should be updated to reflect the new message size. Add an optional `payloadSize` parameter.

### Step 5: Add `OutboxDailyVolume` model

**File:** `lib/features/sync/outbox/outbox_daily_volume.dart` (new)

Simple data class:
```dart
class OutboxDailyVolume {
  const OutboxDailyVolume({
    required this.date,
    required this.totalBytes,
    required this.itemCount,
  });

  final DateTime date;
  final int totalBytes;
  final int itemCount;

  double get totalMegabytes => totalBytes / (1024 * 1024);
}
```

### Step 6: Add tests

**Files:**
- `test/database/sync_db_test.dart` — test migration, column storage, aggregation query
- `test/features/sync/outbox/outbox_service_test.dart` — verify payload_size is set when enqueuing

### Step 7: Run code generation

Since we modified the Drift table, run `make build_runner` to regenerate `sync_db.g.dart`.

## Key Files to Modify

| File | Change |
|------|--------|
| `lib/database/sync_db.dart` | Add column, migration, aggregation query |
| `lib/features/sync/outbox/outbox_service.dart` | Record payload size at enqueue |
| `lib/features/sync/outbox/outbox_daily_volume.dart` | New model class |
| `test/database/sync_db_test.dart` | Test new column and query |
| `test/features/sync/outbox/outbox_service_test.dart` | Test payload size recording |

## Existing Code to Reuse

- `fileLength` computation in `_enqueueJournalEntity` (`outbox_service.dart:665-672`) — already exists
- `jsonString` from `json.encode(messageToEnqueue)` (`outbox_service.dart:249`) — already computed
- `BackfillStats` / `BackfillHostStats` pattern (`lib/features/sync/tuning.dart`) — for aggregation model pattern
- `fl_chart` dependency — already in `pubspec.yaml` for future visualization

## Verification

1. Run `make build_runner` to regenerate Drift code
2. Run `dart-mcp.analyze_files` — must be zero warnings
3. Run `dart-mcp.dart_format`
4. Run targeted tests: `dart-mcp.run_tests` for `test/database/sync_db_test.dart` and `test/features/sync/outbox/outbox_service_test.dart`
5. Verify migration works with in-memory database in tests

## Scope Note

This plan covers the **persistence layer only** (Steps 1-7). The visualization UI (chart widget, page integration) will be a follow-up task once the data is being recorded and queryable.
