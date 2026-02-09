# Flexible Rating System — Implementation Plan

## Context

The current rating system (PR #2647) is hardcoded to 4 session-specific dimensions (productivity, energy, focus, challenge-skill). This prevents adding other rating contexts like Day Ratings (morning planning / evening reflection) and Task Ratings. We need to refactor the data model and UI to be catalog-driven, so different contexts can define different questions without code changes or DB migrations.

**Key insight**: A single entity (task, day) can receive **multiple ratings at different lifecycle moments** — e.g., a task rated when starting vs when completing, or a day rated in the morning vs evening. The data model must support multiple distinct rating catalogs per target entity.

## Scope

This PR covers **Phases 1-3**: making the rating system catalog-driven and rewiring the existing session rating to use it. Day Ratings (linking to DayPlanEntry) and Task Ratings will follow in separate PRs, building on this flexible foundation.

## Design Decisions

### 1. Catalog ID as Primary Discriminator

Instead of a coarse `ratingType`, use a granular `catalogId` that uniquely identifies which specific catalog was used. This is the key to supporting multiple ratings per entity:

- `'session'` — existing session-end rating (default for backward compat)
- Future examples: `'day_morning'`, `'day_midday'`, `'day_evening'`, `'task_started'`, `'task_completed'`

**The invariant**: At most **one rating per (targetId, catalogId) pair**. Multiple catalogs can point to the same target.

#### Enforcement: Deterministic Entity IDs

The uniqueness invariant is enforced at the entity ID level using **deterministic UUID v5 IDs**, following the same pattern used by `DayPlanEntry` (which has deterministic IDs like `dayplan-YYYY-MM-DD`).

The rating entity ID is derived from the `(targetId, catalogId)` pair using a JSON-encoded tuple as the UUID v5 seed. JSON encoding eliminates delimiter collision risks (no ambiguity if `targetId` or `catalogId` contain special characters):

```dart
// In RatingRepository._createRating:
final metadata = await _persistenceLogic.createMetadata(
  dateFrom: now,
  dateTo: now,
  categoryId: categoryId,
  uuidV5Input: jsonEncode(['rating', targetId, catalogId]),  // deterministic!
);
// Produces e.g.: '["rating","entry-abc-123","session"]'
```

This guarantees:
- **Local uniqueness**: Creating a second rating for the same `(targetId, catalogId)` produces the same entity ID → the DB upsert merges them naturally.
- **Sync convergence**: Two devices rating the same target with the same catalog independently produce the same entity ID. Vector clock conflict resolution handles value differences, but they never create duplicates.
- **No DB constraint needed**: The PRIMARY KEY on `journal.id` plus deterministic ID generation enforces the invariant without a separate UNIQUE constraint.

**Upsert guarantee**: Every journal entity write goes through `JournalDb.upsertJournalDbEntity()` (`database.dart:214`), which uses Drift's `insertOnConflictUpdate` — a SQL `INSERT OR REPLACE` on primary key. This applies to both `PersistenceLogic.createDbEntity()` (new entities) and `updateDbEntity()` (existing entities). There is no plain-insert path. The deterministic ID + mandatory upsert semantics together enforce the invariant at all levels — application lookup-then-update for the common case, and DB-level conflict resolution as the safety net for concurrent/sync edge cases.

Add `catalogId` to `RatingData` with `@Default('session')` for backward compat. Also store it as the `subtype` column in the journal table (currently empty for RatingEntry), enabling efficient SQL filtering.

### 2. DB Subtype for Efficient Queries

The journal table already has a `subtype` column. Currently RatingEntry maps to `''`. Change `conversions.dart` to map it to the `catalogId`:

```dart
// In toDbEntity, subtype mapping:
rating: (r) => r.data.catalogId,
```

Update the `ratingForTimeEntry` drift query to also filter by subtype, using `COALESCE(NULLIF(...))` to handle legacy rows transparently:

```sql
ratingForTimeEntry:
SELECT j.* FROM journal j
  INNER JOIN linked_entries le ON j.id = le.from_id
  WHERE le.to_id = :timeEntryId
  AND le.type = 'RatingLink'
  AND COALESCE(NULLIF(j.subtype, ''), 'session') = :catalogId
  AND COALESCE(le.hidden, false) = false
  AND j.deleted = false
  ORDER BY j.updated_at DESC
  LIMIT 1;
```

Add a companion query to fetch **all** ratings for a target (for summary views). **Important**: normalize legacy subtype in the ORDER BY so legacy `''` rows sort with `'session'` rows, not as a separate blank group:

```sql
allRatingsForTarget:
SELECT j.* FROM journal j
  INNER JOIN linked_entries le ON j.id = le.from_id
  WHERE le.to_id = :targetId
  AND le.type = 'RatingLink'
  AND COALESCE(le.hidden, false) = false
  AND j.deleted = false
  ORDER BY COALESCE(NULLIF(j.subtype, ''), 'session') ASC, j.updated_at DESC;
```

Note: At the Dart level, `RatingData.catalogId` has `@Default('session')` so legacy entries with no `catalogId` in their JSON will deserialize correctly. But the SQL ORDER BY must also normalize to prevent grouping anomalies when consuming raw query results.

**No migration needed**: The few existing rating entries are handled by the `COALESCE(NULLIF(...))` in queries. New entries will get the correct `subtype` from `conversions.dart`. No schema version bump or data backfill required.

### 3. Field Rename: `timeEntryId` → `targetId`

The field `RatingData.timeEntryId` assumes session-specific semantics. Since ratings can now target any entity (time entries, day plans, tasks), rename to `targetId`:

```dart
@freezed
abstract class RatingData with _$RatingData {
  const factory RatingData({
    /// The rated entity's ID. For session ratings this is the time entry ID.
    /// For day ratings it will be the DayPlanEntry ID, for task ratings the Task ID.
    @JsonKey(name: 'timeEntryId') required String targetId,
    // ...
  }) = _RatingData;
}
```

`@JsonKey(name: 'timeEntryId')` preserves wire-format backward compatibility:
- Legacy JSON with `"timeEntryId"` deserializes correctly into `.targetId`
- New serialization writes `"timeEntryId"` key for sync compat with older clients
- Dart code uses the semantically correct `.targetId` everywhere

All Dart references (`repository.dart`, `controller.dart`, `modal.dart`, `summary.dart`, tests) are updated from `.timeEntryId` to `.targetId`. The JSON shape is unchanged.

### 4. Self-Describing Answers (Two Audiences)

Each stored answer carries metadata for **two audiences**:

1. **The user** — `question`: the localized question text captured in whatever language the user had active at rating time.
2. **LLMs** — `description`: an English semantic explanation of what the dimension measures, how to interpret the 0-1 scale, and what constitutes "good" vs "bad".

This snapshot approach means each rating is a **self-contained document**. Catalog definitions can evolve over time (reworded questions, adjusted descriptions) without retroactively changing the meaning of historical data. The data duplication cost is trivial (a few hundred bytes per rating) compared to the value of immutable, self-describing records.

```dart
@freezed
abstract class RatingDimension with _$RatingDimension {
  const factory RatingDimension({
    required String key,           // stable key, e.g. "productivity"
    required double value,         // 0.0-1.0 normalized answer
    String? question,              // localized question shown to user
    String? description,           // English LLM-facing semantic description
    String? inputType,             // 'tapBar', 'segmented', 'boolean'
    List<String>? optionLabels,    // for segmented: ["Too easy", "Just right", "Too hard"]
  }) = _RatingDimension;
}
```

New fields are all optional → existing serialized data deserializes fine with nulls.

### 5. Question Catalog — Localized Code Constants

Catalogs are Dart functions that take `AppLocalizations` and return localized `RatingQuestion` lists. The `description` field is always English (for LLM consumption) and does not go through localization. The `question` field is localized.

```dart
@freezed
abstract class RatingQuestion with _$RatingQuestion {
  const factory RatingQuestion({
    required String key,
    required String question,        // localized, from AppLocalizations
    required String description,     // English, for LLM context
    @Default('tapBar') String inputType,
    List<RatingQuestionOption>? options,
  }) = _RatingQuestion;
}

@freezed
abstract class RatingQuestionOption with _$RatingQuestionOption {
  const factory RatingQuestionOption({
    required String label,   // localized option label
    required double value,   // normalized value when selected
  }) = _RatingQuestionOption;
}
```

A catalog registry maps `catalogId` → catalog function:

```dart
typedef CatalogFactory = List<RatingQuestion> Function(AppLocalizations messages);

final Map<String, CatalogFactory> ratingCatalogRegistry = {
  'session': sessionRatingCatalog,
  // Future: 'day_morning': dayMorningCatalog, etc.
};
```

Each catalog function returns localized questions with English descriptions:

```dart
List<RatingQuestion> sessionRatingCatalog(AppLocalizations messages) => [
  RatingQuestion(
    key: 'productivity',
    question: messages.sessionRatingProductivityQuestion,
    description: 'Measures subjective productivity during the work session. '
        '0.0 = completely unproductive, 1.0 = peak productivity.',
  ),
  // ...
];
```

When saving, the `RatingQuestion` metadata is snapshotted into each `RatingDimension` answer — capturing both the localized question and the English description at the time of rating.

### 6. Unknown Catalog Fallback

Ratings can arrive via sync from newer clients that define catalogs not yet known to this app version. The rendering and edit paths must handle unregistered `catalogId` values gracefully:

**Read-only rendering (RatingSummary)**: Always possible because dimensions are self-describing. If the catalog is not in the registry, fall back to stored dimension metadata (`question`, `description`, `inputType`, `optionLabels`). For truly legacy data without stored metadata, fall back to displaying the dimension `key` as a label.

**Edit/re-rate flow (RatingModal)**: If the catalog is not in the registry, **disable editing** — the rating is displayed read-only. The user sees the stored data but cannot modify it. This prevents data loss from rendering an unknown catalog with wrong questions.

**Fallback chain for rendering a dimension label**:
1. Stored `dimension.question` (preferred — captured at rating time)
2. Catalog lookup: `registry[catalogId]?.call(messages)` → find matching key → use `.question`
3. Dimension `key` as-is (last resort)

### 7. Day Rating Link Target (future PR, documented here for architecture)

Day ratings link to the `DayPlanEntry` for that date via the existing `RatingLink`. The `RatingData.targetId` field stores the DayPlanEntry's ID. The `catalogId` distinguishes morning/midday/evening.

### 8. Dynamic UI

Replace the hardcoded `SessionRatingModal` with a generic `RatingModal` that:
1. Receives a `catalogId` and `targetId`
2. Looks up the catalog from the registry
3. Renders each question dynamically based on `inputType`
4. Collects answers into `List<RatingDimension>` with embedded question metadata

The existing `_TapBar` and `_ChallengeSkillRow` become reusable widgets selected by `inputType`.

## Files to Modify/Create

### Data Model Changes
- **`lib/classes/rating_data.dart`** — Add optional fields to `RatingDimension` (question, description, inputType, optionLabels). Add `catalogId` field to `RatingData` with `@Default('session')`. Rename `timeEntryId` → `targetId` with `@JsonKey(name: 'timeEntryId')` for wire compat.

### New Files
- **`lib/classes/rating_question.dart`** — `RatingQuestion` (with `description`) and `RatingQuestionOption` freezed classes.
- **`lib/features/ratings/data/rating_catalogs.dart`** — Catalog registry and session catalog definition.
- **`lib/features/ratings/ui/rating_input_widgets.dart`** — Extracted reusable input widgets (RatingTapBar, RatingSegmentedInput).

### UI Changes
- **`lib/features/ratings/ui/session_rating_modal.dart`** — Refactor to generic `RatingModal` that renders from catalog. Guard: if catalog not in registry, show read-only view.
- **`lib/features/ratings/ui/rating_summary.dart`** — Render dynamically from stored dimension metadata (with catalog fallback for legacy data, then key fallback).
- **`lib/features/ratings/ui/rating_prompt_listener.dart`** — Pass `catalogId` through.

### State/Repository Changes
- **`lib/features/ratings/state/rating_controller.dart`** — Accept `catalogId` parameter alongside `targetId`. Pass both to DB and repository.
- **`lib/features/ratings/state/rating_prompt_controller.dart`** — Extend state to carry both `targetId` and `catalogId`.
- **`lib/features/ratings/repository/rating_repository.dart`** — Pass `catalogId` through to `RatingData`. Use deterministic UUID v5 ID (`jsonEncode(['rating', targetId, catalogId])`) when creating. Snapshot question metadata into dimensions on save.

### Database
- **`lib/database/database.drift`** — Update `ratingForTimeEntry` query to filter by `subtype` (catalogId) with COALESCE for legacy compat. Add `allRatingsForTarget` query with COALESCE in ORDER BY.
- **`lib/database/database.dart`** — Update `getRatingForTimeEntry` signature to accept `catalogId`. Add `getAllRatingsForTarget`.
- **`lib/database/conversions.dart`** — Map RatingEntry subtype to `data.catalogId`.

### Wiring
- **`lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart`** — Pass catalogId to modal.
- **`lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart`** — Same.
- **`lib/features/journal/state/entry_controller.dart`** — No changes needed (session flow unchanged, catalogId defaults to 'session').

### Tests (update existing, add new)
- **`test/classes/rating_data_test.dart`** — Add tests for new fields, backward compat, legacy JSON deserialization, targetId rename with JsonKey.
- **`test/features/ratings/ui/session_rating_modal_test.dart`** — Update for renamed widget, catalog-driven rendering.
- **`test/features/ratings/ui/rating_summary_test.dart`** — Update for dynamic rendering, unknown catalog fallback.
- **`test/features/ratings/repository/rating_repository_test.dart`** — Add catalogId parameter tests, deterministic ID tests.
- **`test/features/ratings/state/rating_controller_test.dart`** — Update for catalogId.
- **`test/features/ratings/state/rating_prompt_controller_test.dart`** — Update for extended state.
- **New: `test/features/ratings/data/rating_catalogs_test.dart`** — Catalog structure tests.
- **New: `test/features/ratings/ui/rating_input_widgets_test.dart`** — Extracted widget tests.

## Step-by-Step Execution Order

### Phase 1: Data Model (backward-compatible foundation) ✅ COMPLETE
1. Extend `RatingDimension` with optional fields (`question`, `description`, `inputType`, `optionLabels`)
2. Add `catalogId` field to `RatingData` with `@Default('session')`
3. Run `build_runner` to regenerate freezed/json
4. Update `conversions.dart` — map RatingEntry subtype to `data.catalogId`
5. Update `database.drift` — add `catalogId` filter to `ratingForTimeEntry` (with COALESCE for legacy compat), add `allRatingsForTarget` query
6. Update `database.dart` — adjust method signatures
7. ~~Add data-only migration~~ — Not needed; COALESCE handles legacy entries transparently
8. Update `rating_data_test.dart` — verify backward compat (old JSON without new fields deserializes correctly)
9. Analyze + format + test ✅

### Phase 2: Question Catalog ✅ COMPLETE
10. Create `lib/classes/rating_question.dart` — `RatingQuestion` (with `description`), `RatingQuestionOption`
11. Run `build_runner`
12. Create `lib/features/ratings/data/rating_catalogs.dart` — catalog registry + session catalog with English descriptions
13. Write catalog tests
14. Analyze + format + test ✅

### Phase 2.5: Addressing Review Feedback ✅ COMPLETE
15. Rename `RatingData.timeEntryId` → `targetId` with `@JsonKey(name: 'timeEntryId')` for wire compat ✅
16. Run `build_runner` ✅
17. Update all Dart references from `.timeEntryId` to `.targetId` (repository, controller, modal, summary, tests) ✅
18. Fix `allRatingsForTarget` query ORDER BY to use `COALESCE(NULLIF(j.subtype, ''), 'session')` ✅
19. Update `RatingRepository._createRating` to use deterministic UUID v5 ID: `uuidV5Input: jsonEncode(['rating', targetId, catalogId])` ✅
20. Update tests for rename and deterministic ID ✅
21. Analyze + format + test ✅

### Phase 3: Dynamic UI (rewire session rating) ✅ COMPLETE

- ✅ Parameter renaming throughout: `timeEntryId` → `targetId` in modal, controllers, repository
- ✅ `RatingController` provider parameter renamed to `targetId`, method renamed to `getRatingForTargetEntry`
- ✅ `RatingRepository.getRatingForTargetEntry()` added, `createOrUpdateRating()` accepts `targetId`
- ✅ `ModernRateSessionItem` updated to use renamed provider parameter
- ✅ Extracted `RatingTapBar` and `RatingSegmentedInput` to `rating_input_widgets.dart`
- ✅ Refactored `SessionRatingModal` → `RatingModal` — catalog-driven, snapshots question metadata on save
- ✅ Unknown catalog guard: read-only view with no save button for unregistered catalogs
- ✅ `RatingPromptController` state changed to `RatingPrompt` record `({String targetId, String catalogId})`
- ✅ `RatingController` accepts `catalogId` as family parameter
- ✅ `RatingRepository` passes `catalogId` through to DB layer
- ✅ `RatingSummary` renders dynamically with fallback chain (stored → catalog → key) for both labels and inputType
- ✅ All call sites updated: `ModernRateSessionItem`, `RatingPromptListener`, `EntryController`
- ✅ Unknown-catalog tests for both `RatingModal` and `RatingSummary`
- ✅ All tests updated and passing

### Phase 4: Polish ✅ COMPLETE
- ✅ CHANGELOG updated
- ✅ `flatpak/com.matthiasn.lotti.metainfo.xml` updated
- ✅ Feature README created at `lib/features/ratings/README.md`
- ✅ Full project analyzer green, formatted
- ✅ All related test suites passing

## Backward Compatibility

- **Old ratings (no `catalogId`)**: Deserialize with `@Default('session')` → treated as session ratings
- **Old ratings in DB (subtype = '')**: Handled transparently by `COALESCE(NULLIF(j.subtype, ''), 'session')` in **both** `ratingForTimeEntry` and `allRatingsForTarget` queries. No migration needed — the few existing entries are not worth migrating.
- **Old ratings (no question metadata in dimensions)**: `question`, `description`, `inputType`, `optionLabels` are all nullable → deserialize as null. `RatingSummary` falls back to localized labels from catalog when stored metadata is null, then to dimension key as last resort.
- **`timeEntryId` → `targetId` rename**: `@JsonKey(name: 'timeEntryId')` preserves JSON key. Wire format unchanged. Old clients continue to work.
- **No schema migration**: `subtype` column already exists. No DDL or data changes needed.
- **Sync**: Existing sync works unchanged — RatingEntry and RatingLink serialization is backward compatible. New optional fields are ignored by older clients. Deterministic IDs ensure sync convergence for same `(targetId, catalogId)` pair.
- **Unknown catalogs from newer clients**: Ratings with unregistered `catalogId` values render in read-only mode using self-describing dimension metadata. No data loss, no crashes.

## Multi-Rating-Per-Entity Architecture

The `(targetId, catalogId)` pair is the unique key, enforced via deterministic UUID v5 entity IDs:

| Target Entity | catalogId | When triggered |
|---|---|---|
| Time Entry | `session` | When stopping a recording |
| DayPlanEntry | `day_morning` | Morning planning (future PR) |
| DayPlanEntry | `day_midday` | Midday check-in (future PR) |
| DayPlanEntry | `day_evening` | Evening reflection (future PR) |
| Task | `task_started` | Moving to in-progress (future PR) |
| Task | `task_completed` | Moving to done (future PR) |

Each row is a separate `RatingEntry` entity linked via its own `RatingLink` to the target. The `subtype` column enables efficient per-catalog lookups. The `allRatingsForTarget` query enables summary views showing all ratings for an entity. Deterministic IDs prevent duplicates under concurrency and sync.

## Alignment with Daily OS

The Daily OS plan (`2026-01-14_daily_os_implementation_plan.md`) is already implemented through Phase 3:

1. **DayPlanEntry exists** — `JournalEntity.dayPlan` with deterministic ID `dayplan-YYYY-MM-DD`. Day ratings (future PR) will link to these via `RatingLink`.

2. **Daily OS already handles session ratings** — `unified_daily_os_data_controller.dart` bulk-fetches `ratingIds` for time entries and skips `RatingEntry` when resolving parent links. No interference from our changes.

3. **`ratingsForTimeEntries` bulk query** — Currently returns one rating per time entry (last-write-wins map). For this PR (session-only), no change needed. In the future Day Ratings PR, this query may need a `subtype` filter to return catalog-specific results, and `getRatingIdsForTimeEntries` may need to return `Map<(String, String), String>` keyed by `(targetId, catalogId)`.

4. **`subtype` column** — No conflict. DayPlanEntry maps to `subtype = ''`. RatingEntry also currently maps to `''`. Our change to populate it with `catalogId` is isolated to RatingEntry.

## Verification

1. Run `dart-mcp.analyze_files` — zero warnings
2. Run `dart-mcp.dart_format` — clean
3. Run targeted tests: `test/classes/rating_data_test.dart`, `test/features/ratings/`
4. Manual: Stop a time entry → session rating modal appears with same 4 questions → save → verify stored data includes question metadata and catalogId
5. Manual: Create old-format rating in test → verify summary renders correctly (fallback to catalog labels)
6. Manual: Verify deterministic ID — rate same time entry twice → same entity updated, not duplicated
7. Test: Open `RatingModal` with unregistered `catalogId` → verify read-only rendering (no save button, no editable inputs)
8. Test: `RatingSummary` with dimensions lacking stored metadata and unknown `catalogId` → verify graceful fallback to dimension key labels
