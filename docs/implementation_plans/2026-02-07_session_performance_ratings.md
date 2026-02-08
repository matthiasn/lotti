# Session Performance Ratings - Implementation Plan

## Context

Lotti's Daily Operating System enables planned time blocks and budget tracking. The next step is capturing **qualitative data** about how work sessions went. When a user stops a running timer, we want to immediately prompt them for a brief performance rating. This data will power future analytics (time-of-day productivity patterns, task-type optimization, burnout detection) and AI-powered insights.

### Research Summary

Based on ESM (Experience Sampling Method) research, flow state literature, and mobile UX studies:

- **Buttons over sliders** for mobile UX (sliders have higher non-response rates and are harder to use on touchscreens)
- **3-4 dimensions** is the sweet spot: more yields survey fatigue, fewer loses signal
- **Immediate capture** (right when timer stops) minimizes retrospective bias and the peak-end distortion effect
- **Single-item measures** per dimension are scientifically valid for ESM when items are concrete and unambiguous

### Rating Dimensions (4 questions)

| # | Dimension | Question | UI | Storage |
|---|-----------|----------|-----|---------|
| 1 | **Productivity** | "How productive was this session?" | 10 tappable segments | `double` 0.0–1.0 |
| 2 | **Energy** | "How energized did you feel?" | 10 tappable segments | `double` 0.0–1.0 |
| 3 | **Focus** | "How focused were you?" | 10 tappable segments | `double` 0.0–1.0 |
| 4 | **Challenge-Skill** | "This work felt..." | 3 categorical buttons: "Too easy / Just right / Too challenging" | `double` 0.0–1.0 (mapped: 0.0, 0.5, 1.0) |

**Scale rationale**: The UI shows 10 visual tick marks as guides, but tapping stores the **exact tap position** as a continuous `double` (0.0–1.0). No snapping — a tap between tick 3 and 4 stores ~0.35. This is fully future-proof: the UI can evolve (change tick count, remove ticks entirely) without any data migration. The 0.0–1.0 storage is scale-agnostic.

---

## Architecture Overview

### Guiding Principles

1. **Rating is a first-class JournalEntity** — follows existing entity patterns exactly
2. **Linked via EntryLink** — new `RatingLink` type, directional from Rating → TimeEntry (and Rating → DayPlan)
3. **Flexible schema** — version identifier allows evolving questions without breaking existing data
4. **Bulk-fetch aware** — uses existing `getBulkLinkedEntities()` pattern to avoid N+1
5. **Sync-safe** — vector clocks, soft deletes, outbox integration come for free

---

## Step-by-Step Implementation

### Step 1: Data Model — `RatingData` and `JournalEntity.rating`

**New file:** `lib/classes/rating_data.dart`

```dart
@freezed
abstract class RatingData with _$RatingData {
  const factory RatingData({
    /// Schema version for the rating dimensions.
    /// Increment when adding/removing/reordering questions.
    @Default(1) int schemaVersion,

    /// The rated time entry's ID (denormalized for convenience).
    required String timeEntryId,

    /// Individual dimension ratings, each normalized to 0.0–1.0.
    required List<RatingDimension> dimensions,

    /// Optional free-text note about the session.
    String? note,
  }) = _RatingData;

  factory RatingData.fromJson(Map<String, dynamic> json) =>
      _$RatingDataFromJson(json);
}

@freezed
abstract class RatingDimension with _$RatingDimension {
  const factory RatingDimension({
    /// Stable key for this dimension (e.g., "productivity", "energy",
    /// "focus", "challenge_skill").
    required String key,

    /// Normalized value between 0.0 and 1.0.
    required double value,
  }) = _RatingDimension;

  factory RatingDimension.fromJson(Map<String, dynamic> json) =>
      _$RatingDimensionFromJson(json);
}
```

**Modify:** `lib/classes/journal_entities.dart` — add new union variant:

```dart
const factory JournalEntity.rating({
  required Metadata meta,
  required RatingData data,
  EntryText? entryText,
  Geolocation? geolocation,
}) = RatingEntry;
```

**Modify:** `lib/classes/journal_entities.dart` — add to `affectedIds` switch:
```dart
case RatingEntry():
  ids.add(ratingNotification);
```

**Modify:** `lib/services/db_notification.dart` — add notification constant:
```dart
const ratingNotification = 'RATING_NOTIFICATION';
```

**Modify:** `lib/database/conversions.dart` — add type mapping in `toDbEntity`:
```dart
rating: (_) => 'RatingEntry',
```

### Step 2: EntryLink Enhancement — Add `RatingLink` Type

**Modify:** `lib/classes/entry_link.dart` — add new union variant:

```dart
const factory EntryLink.rating({
  required String id,
  required String fromId,   // Rating entity ID
  required String toId,     // TimeEntry or DayPlan ID
  required DateTime createdAt,
  required DateTime updatedAt,
  required VectorClock? vectorClock,
  bool? hidden,
  DateTime? deletedAt,
}) = RatingLink;
```

**Modify:** `lib/database/conversions.dart` — update `linkedDbEntity` type mapping:
```dart
type: link.map(
  basic: (_) => 'BasicLink',
  rating: (_) => 'RatingLink',
),
```

**No schema migration needed** — the `linked_entries.type` column is already `TEXT` and unconstrained. The UNIQUE constraint `(from_id, to_id, type)` naturally accommodates the new type.

### Step 3: Database Queries — Bulk Rating Lookup

**Add to:** `lib/database/database.drift`

```sql
-- Find ratings linked to a set of time entry IDs (avoids N+1).
-- Joins journal to exclude soft-deleted rating entities.
ratingsForTimeEntries:
SELECT le.from_id AS rating_id, le.to_id AS time_entry_id
  FROM linked_entries le
  INNER JOIN journal j ON j.id = le.from_id
  WHERE le.to_id IN :timeEntryIds
  AND le.type = 'RatingLink'
  AND COALESCE(le.hidden, false) = false
  AND j.deleted = false;

-- Find existing rating for a specific time entry (for re-open logic).
-- Orders by most recently updated to ensure deterministic result.
ratingForTimeEntry:
SELECT j.* FROM journal j
  INNER JOIN linked_entries le ON j.id = le.from_id
  WHERE le.to_id = :timeEntryId
  AND le.type = 'RatingLink'
  AND COALESCE(le.hidden, false) = false
  AND j.deleted = false
  ORDER BY j.updated_at DESC
  LIMIT 1;
```

**Add to:** `lib/database/database.dart`

```dart
/// Find existing rating entity for a time entry (for edit/re-open).
Future<RatingEntry?> getRatingForTimeEntry(String timeEntryId) async {
  final res = await ratingForTimeEntry(timeEntryId).get();
  if (res.isEmpty) return null;
  final entity = fromDbEntity(res.first);
  return entity is RatingEntry ? entity : null;
}

/// Bulk fetch rating IDs for a set of time entries.
Future<Map<String, String>> getRatingIdsForTimeEntries(
  Set<String> timeEntryIds,
) async {
  if (timeEntryIds.isEmpty) return {};
  final rows = await ratingsForTimeEntries(timeEntryIds.toList()).get();
  return {for (final row in rows) row.timeEntryId: row.ratingId};
}
```

**Schema version**: No bump needed — named queries in `.drift` don't require schema version changes.

### Step 4: Business Logic — `RatingRepository`

**New file:** `lib/features/ratings/repository/rating_repository.dart`

Responsibilities:
- Create or update a `RatingEntry` linked to a time entry
- Look up existing rating for a time entry (for re-open/edit)
- Link rating to time entry via `RatingLink`
- Optionally link rating to the day's `DayPlanEntry`

Key methods:
```dart
Future<RatingEntry> createOrUpdateRating({
  required String timeEntryId,
  required List<RatingDimension> dimensions,
  String? note,
});

Future<RatingEntry?> getRatingForTimeEntry(String timeEntryId);
```

**Re-rating logic** (stop → rate → restart same entry → stop again):
1. On stop → check if a `RatingLink` already exists for this time entry ID
2. If yes → re-open existing rating (pre-populate modal with previous values)
3. If no → create new rating entity + new `RatingLink`

### Step 5: State Management — Riverpod Controller

**New file:** `lib/features/ratings/state/rating_controller.dart`

```dart
@riverpod
class RatingController extends _$RatingController {
  @override
  Future<RatingEntry?> build({required String timeEntryId}) async {
    return ref.read(ratingRepositoryProvider).getRatingForTimeEntry(timeEntryId);
  }

  Future<void> submitRating(
    List<RatingDimension> dimensions, {
    String? note,
  });
}
```

**New file:** `lib/features/ratings/state/rating_prompt_controller.dart`

A simple notifier that holds the time entry ID to rate (or null). The UI layer listens to this and shows the modal when it becomes non-null.

```dart
@riverpod
class RatingPromptController extends _$RatingPromptController {
  @override
  String? build() => null;

  void requestRating(String timeEntryId) => state = timeEntryId;
  void dismiss() => state = null;
}
```

### Step 6: UI — Rating Modal

**New file:** `lib/features/ratings/ui/session_rating_modal.dart`

Design:
- **Modal bottom sheet** (fast to appear, dismissible by swipe-down or tap outside)
- **4 rows**, one per dimension:
  - Productivity: Tap-bar with 10 visual tick marks; stores exact tap position as continuous 0.0–1.0
  - Energy: Same tap-bar
  - Focus: Same tap-bar
  - Challenge-Skill: 3 segmented buttons ("Too easy" / "Just right" / "Too challenging")
- **Optional text field** for a quick note
- **"Save" button** at the bottom + **"Skip"** for dismissal
- Pre-populated with existing values if re-rating the same session
- Haptic feedback on selection
- Total interaction time target: **< 15 seconds**
- **Minimum session duration gate**: Skip prompt for sessions under **1 minute** (avoids noise from accidental start/stops)

### Step 7: Integration — Timer Stop Flow

**Modify:** `lib/features/journal/state/entry_controller.dart`

In the `save()` method, after `TimeService.stop()`:

```dart
if (stopRecording) {
  await Future<void>.delayed(const Duration(milliseconds: 100)).then((_) {
    getIt<TimeService>().stop();
  });
  // Emit rating prompt if session was >= 1 minute
  final duration = entry.meta.dateTo.difference(entry.meta.dateFrom);
  if (duration >= const Duration(minutes: 1)) {
    ref.read(ratingPromptControllerProvider.notifier).requestRating(id);
  }
}
```

The `TimeRecordingIndicator` or a wrapper widget at the app scaffold level listens to `ratingPromptControllerProvider` and shows the modal.

### Step 8: Sync Integration

**Automatic** — because:
- `RatingEntry` is a `JournalEntity` → goes through `updateJournalEntity()` which handles outbox, vector clocks, and sync
- `RatingLink` is an `EntryLink` → goes through `upsertEntryLink()` which handles the same
- No additional sync code needed

### Step 9: Daily OS Integration (Ratings on Budget Cards)

**Modify:** `lib/features/daily_os/state/unified_daily_os_data_controller.dart`

After fetching timeline entries and links, also fetch ratings in bulk:
```dart
final timeEntryIds = calendarEntries.map((e) => e.id).toSet();
final ratingIds = await journalDb.getRatingIdsForTimeEntries(timeEntryIds);
```

This allows budget cards to show a small rating indicator (e.g., colored dot based on average productivity score) without individual queries per entry.

### Step 10: Tests

1. **Unit tests** for `RatingData` / `RatingDimension` serialization/deserialization
2. **Unit tests** for `RatingRepository` (create, update, lookup, linking)
3. **Widget tests** for the rating modal (submission, pre-population, dismissal, skip)
4. **Integration tests** for the timer stop → rating flow (including minimum duration gate)
5. **Database tests** for bulk rating queries and `ratingForTimeEntry` JOIN query

---

## File Summary

| Action | File | Description |
|--------|------|-------------|
| **Create** | `lib/classes/rating_data.dart` | `RatingData` + `RatingDimension` freezed models |
| **Modify** | `lib/classes/journal_entities.dart` | Add `JournalEntity.rating()` variant + `affectedIds` |
| **Modify** | `lib/classes/entry_link.dart` | Add `EntryLink.rating()` variant |
| **Modify** | `lib/database/conversions.dart` | Add type mappings for rating entity + link |
| **Modify** | `lib/database/database.drift` | Add rating lookup queries |
| **Modify** | `lib/database/database.dart` | Add rating query methods, bump schema to 30 |
| **Modify** | `lib/services/db_notification.dart` | Add `ratingNotification` constant |
| **Create** | `lib/features/ratings/repository/rating_repository.dart` | Business logic for create/update/lookup |
| **Create** | `lib/features/ratings/state/rating_controller.dart` | Riverpod controller for rating data |
| **Create** | `lib/features/ratings/state/rating_prompt_controller.dart` | Notifier to trigger the modal |
| **Create** | `lib/features/ratings/ui/session_rating_modal.dart` | Rating modal bottom sheet UI |
| **Modify** | `lib/features/journal/state/entry_controller.dart` | Trigger rating prompt after stop |
| **Modify** | `lib/features/daily_os/state/unified_daily_os_data_controller.dart` | Bulk rating fetch for budget cards |
| **Modify** | `lib/database/journal_db/config_flags.dart` | Add `sessionRatings` config flag |
| **Create** | `test/features/ratings/` | Test files |

---

## Resolved Decisions

1. **Feature flag**: Yes — add a config flag to enable/disable the rating prompt. Disabled by default until ready.
2. **Rating visibility in timeline**: Not in v1. Ratings viewable when tapping into an entry. Timeline visualization deferred to follow-up.
3. **Daily summary rating**: Not in v1. The flexible schema allows adding a daily roll-up (linked to `DayPlanEntry`) later.
4. **Re-rating across task entries**: Each time entry gets its own rating. No cross-entry aggregation — future analytics can roll up per-task ratings across a day.
5. **Minimum session duration**: 1 minute. Sessions under 60 seconds skip the rating prompt.
6. **Scale UI**: Continuous tap-bar with 10 visual tick marks as guides. Exact tap position stored as `double` 0.0–1.0, no snapping.
7. **Challenge-Skill dimension**: 3 categorical buttons ("Too easy / Just right / Too challenging"), stored as 0.0, 0.5, 1.0.

---

## Verification Plan

1. Run `fvm flutter pub run build_runner build --delete-conflicting-outputs` to generate freezed/json code
2. Run analyzer via MCP `analyze_files` — ensure zero errors across entire project
3. Run formatter via MCP `dart_format`
4. Run all tests via MCP `run_tests` on full project
5. Manual test on simulator:
   - Start a timer on a task → stop after > 1 min → verify modal appears
   - Start a timer → stop after < 1 min → verify modal does NOT appear
   - Fill in ratings → verify `RatingEntry` + `RatingLink` created in DB
   - Start same entry timer again → stop → verify modal pre-populates with previous values
   - Dismiss modal via "Skip" → verify no rating created
   - Check sync outbox contains the new entities
