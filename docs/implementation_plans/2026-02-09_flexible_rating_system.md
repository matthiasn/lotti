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

Add `catalogId` to `RatingData` with `@Default('session')` for backward compat. Also store it as the `subtype` column in the journal table (currently empty for RatingEntry), enabling efficient SQL filtering.

### 2. DB Subtype for Efficient Queries

The journal table already has a `subtype` column. Currently RatingEntry maps to `''`. Change `conversions.dart` to map it to the `catalogId`:

```dart
// In toDbEntity, subtype mapping:
rating: (r) => r.data.catalogId,
```

Update the `ratingForTimeEntry` drift query to also filter by subtype:

```sql
ratingForTimeEntry:
SELECT j.* FROM journal j
  INNER JOIN linked_entries le ON j.id = le.from_id
  WHERE le.to_id = :timeEntryId
  AND le.type = 'RatingLink'
  AND j.subtype = :catalogId
  AND COALESCE(le.hidden, false) = false
  AND j.deleted = false
  ORDER BY j.updated_at DESC
  LIMIT 1;
```

Add a companion query to fetch **all** ratings for a target (for summary views):

```sql
allRatingsForTarget:
SELECT j.* FROM journal j
  INNER JOIN linked_entries le ON j.id = le.from_id
  WHERE le.to_id = :targetId
  AND le.type = 'RatingLink'
  AND COALESCE(le.hidden, false) = false
  AND j.deleted = false
  ORDER BY j.subtype ASC, j.updated_at DESC;
```

**Backward compat**: Existing ratings have `subtype = ''` in the DB. We need a one-time backfill or handle it in the query. Simplest: update the query to use `COALESCE(NULLIF(j.subtype, ''), 'session') = :catalogId` — or run a migration that sets `subtype = 'session'` for all existing RatingEntry rows. The latter is cleaner and doesn't require a schema version bump (it's a data-only UPDATE, not a DDL change).

### 3. Self-Describing Answers

Extend `RatingDimension` to carry the question metadata alongside the answer:

```dart
@freezed
abstract class RatingDimension with _$RatingDimension {
  const factory RatingDimension({
    required String key,           // stable key, e.g. "productivity"
    required double value,         // 0.0-1.0 normalized answer
    String? question,              // the question text (self-describing)
    String? inputType,             // 'slider', 'segmented', 'boolean'
    List<String>? optionLabels,    // for segmented: ["Too easy", "Just right", "Too hard"]
  }) = _RatingDimension;
}
```

New fields are all optional → existing serialized data deserializes fine with nulls.

### 4. Question Catalog — Pure Dart Constants

Define catalogs as `List<RatingQuestion>` constants. No DB storage needed.

```dart
@freezed
abstract class RatingQuestion with _$RatingQuestion {
  const factory RatingQuestion({
    required String key,
    required String question,
    @Default('slider') String inputType,  // 'slider' | 'segmented' | 'boolean'
    List<RatingQuestionOption>? options,   // for segmented inputs
  }) = _RatingQuestion;
}

@freezed
abstract class RatingQuestionOption with _$RatingQuestionOption {
  const factory RatingQuestionOption({
    required String label,
    required double value,
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

Each catalog function returns localized questions:

```dart
List<RatingQuestion> sessionRatingCatalog(AppLocalizations messages) => [
  RatingQuestion(key: 'productivity', question: messages.sessionRatingProductivityQuestion),
  RatingQuestion(key: 'energy', question: messages.sessionRatingEnergyQuestion),
  RatingQuestion(key: 'focus', question: messages.sessionRatingFocusQuestion),
  RatingQuestion(
    key: 'challenge_skill',
    question: messages.sessionRatingDifficultyLabel,
    inputType: 'segmented',
    options: [
      RatingQuestionOption(label: messages.sessionRatingChallengeTooEasy, value: 0.0),
      RatingQuestionOption(label: messages.sessionRatingChallengeJustRight, value: 0.5),
      RatingQuestionOption(label: messages.sessionRatingChallengeTooHard, value: 1.0),
    ],
  ),
];
```

### 5. Day Rating Link Target (future PR, documented here for architecture)

Day ratings link to the `DayPlanEntry` for that date via the existing `RatingLink`. The `RatingData.timeEntryId` field stores the DayPlanEntry's ID. The `catalogId` distinguishes morning/midday/evening.

### 6. Dynamic UI

Replace the hardcoded `SessionRatingModal` with a generic `RatingModal` that:
1. Receives a `catalogId` and `targetId`
2. Looks up the catalog from the registry
3. Renders each question dynamically based on `inputType`
4. Collects answers into `List<RatingDimension>` with embedded question metadata

The existing `_TapBar` and `_ChallengeSkillRow` become reusable widgets selected by `inputType`.

## Files to Modify/Create

### Data Model Changes
- **`lib/classes/rating_data.dart`** — Add optional fields to `RatingDimension` (question, inputType, optionLabels). Add `catalogId` field to `RatingData` with `@Default('session')`.

### New Files
- **`lib/classes/rating_question.dart`** — `RatingQuestion` and `RatingQuestionOption` freezed classes.
- **`lib/features/ratings/data/rating_catalogs.dart`** — Catalog registry and session catalog definition.
- **`lib/features/ratings/ui/rating_input_widgets.dart`** — Extracted reusable input widgets (RatingTapBar, RatingSegmentedInput).

### UI Changes
- **`lib/features/ratings/ui/session_rating_modal.dart`** — Refactor to generic `RatingModal` that renders from catalog.
- **`lib/features/ratings/ui/rating_summary.dart`** — Render dynamically from stored dimension metadata (with catalog fallback for legacy data).
- **`lib/features/ratings/ui/rating_prompt_listener.dart`** — Pass `catalogId` through.

### State/Repository Changes
- **`lib/features/ratings/state/rating_controller.dart`** — Accept `catalogId` parameter alongside `timeEntryId`.
- **`lib/features/ratings/state/rating_prompt_controller.dart`** — Extend state to carry both `targetId` and `catalogId`.
- **`lib/features/ratings/repository/rating_repository.dart`** — Pass `catalogId` through to `RatingData`. Store question metadata in dimensions.

### Database
- **`lib/database/database.drift`** — Update `ratingForTimeEntry` query to filter by `subtype` (catalogId). Add `allRatingsForTarget` query.
- **`lib/database/database.dart`** — Update `getRatingForTimeEntry` signature to accept `catalogId`. Add `getAllRatingsForTarget`.
- **`lib/database/conversions.dart`** — Map RatingEntry subtype to `data.catalogId`.

### Wiring
- **`lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart`** — Pass catalogId to modal.
- **`lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart`** — Same.
- **`lib/features/journal/state/entry_controller.dart`** — No changes needed (session flow unchanged, catalogId defaults to 'session').

### Tests (update existing, add new)
- **`test/classes/rating_data_test.dart`** — Add tests for new fields, backward compat.
- **`test/features/ratings/ui/session_rating_modal_test.dart`** — Update for renamed widget, catalog-driven rendering.
- **`test/features/ratings/ui/rating_summary_test.dart`** — Update for dynamic rendering.
- **`test/features/ratings/repository/rating_repository_test.dart`** — Add catalogId parameter tests.
- **`test/features/ratings/state/rating_controller_test.dart`** — Update for catalogId.
- **`test/features/ratings/state/rating_prompt_controller_test.dart`** — Update for extended state.
- **New: `test/features/ratings/data/rating_catalogs_test.dart`** — Catalog structure tests.
- **New: `test/features/ratings/ui/rating_input_widgets_test.dart`** — Extracted widget tests.
- **`test/database/database_test.dart`** — Update if needed for subtype backfill.

## Step-by-Step Execution Order

### Phase 1: Data Model (backward-compatible foundation)
1. Extend `RatingDimension` with optional fields (`question`, `inputType`, `optionLabels`)
2. Add `catalogId` field to `RatingData` with `@Default('session')`
3. Run `build_runner` to regenerate freezed/json
4. Update `conversions.dart` — map RatingEntry subtype to `data.catalogId`
5. Update `database.drift` — add `catalogId` filter to `ratingForTimeEntry`, add `allRatingsForTarget` query
6. Update `database.dart` — adjust method signatures
7. Add data-only migration: `UPDATE journal SET subtype = 'session' WHERE type = 'RatingEntry' AND (subtype IS NULL OR subtype = '')`
8. Update `rating_data_test.dart` — verify backward compat (old JSON without new fields deserializes correctly)
9. Analyze + format + test

### Phase 2: Question Catalog
10. Create `lib/classes/rating_question.dart` — `RatingQuestion`, `RatingQuestionOption`
11. Run `build_runner`
12. Create `lib/features/ratings/data/rating_catalogs.dart` — catalog registry + session catalog
13. Write catalog tests
14. Analyze + format + test

### Phase 3: Dynamic UI (rewire session rating)
15. Extract `_TapBar` and `_ChallengeSkillRow` to `rating_input_widgets.dart` as public widgets
16. Refactor `SessionRatingModal` → `RatingModal` — render from catalog, store question metadata in dimensions
17. Update `RatingPromptController` state to carry `(targetId, catalogId)` tuple
18. Update `RatingController` to accept `catalogId`
19. Update `RatingRepository` to pass `catalogId` into `RatingData` and embed question metadata in dimensions
20. Update `RatingSummary` to render dynamically from stored dimension metadata
21. Update all call sites (`ModernRateSessionItem`, `InitialModalPageContent`, `RatingPromptListener`)
22. Update all tests for the refactored components
23. Analyze + format + test — verify session rating flow works identically

### Phase 4: Polish
24. Update CHANGELOG
25. Update `flatpak/com.matthiasn.lotti.metainfo.xml`
26. Update feature README
27. Full project analyze + format
28. Run related test suites

## Backward Compatibility

- **Old ratings (no `catalogId`)**: Deserialize with `@Default('session')` → treated as session ratings
- **Old ratings in DB (subtype = '')**: Data migration sets subtype to 'session' for existing RatingEntry rows
- **Old ratings (no question metadata in dimensions)**: `question`, `inputType`, `optionLabels` are all nullable → deserialize as null. `RatingSummary` falls back to localized labels from catalog when stored metadata is null
- **No schema migration**: `subtype` column already exists. Only a data UPDATE is needed
- **Sync**: Existing sync works unchanged — RatingEntry and RatingLink serialization is backward compatible. New optional fields are ignored by older clients

## Multi-Rating-Per-Entity Architecture

The `(targetId, catalogId)` pair is the unique key:

| Target Entity | catalogId | When triggered |
|---|---|---|
| Time Entry | `session` | When stopping a recording |
| DayPlanEntry | `day_morning` | Morning planning (future PR) |
| DayPlanEntry | `day_midday` | Midday check-in (future PR) |
| DayPlanEntry | `day_evening` | Evening reflection (future PR) |
| Task | `task_started` | Moving to in-progress (future PR) |
| Task | `task_completed` | Moving to done (future PR) |

Each row is a separate `RatingEntry` entity linked via its own `RatingLink` to the target. The `subtype` column enables efficient per-catalog lookups. The `allRatingsForTarget` query enables summary views showing all ratings for an entity.

## Alignment with Daily OS

The Daily OS plan (`2026-01-14_daily_os_implementation_plan.md`) is already implemented through Phase 3:

1. **DayPlanEntry exists** — `JournalEntity.dayPlan` with deterministic ID `dayplan-YYYY-MM-DD`. Day ratings (future PR) will link to these via `RatingLink`.

2. **Daily OS already handles session ratings** — `unified_daily_os_data_controller.dart` bulk-fetches `ratingIds` for time entries and skips `RatingEntry` when resolving parent links. No interference from our changes.

3. **`ratingsForTimeEntries` bulk query** — Currently returns one rating per time entry (last-write-wins map). For this PR (session-only), no change needed. In the future Day Ratings PR, this query may need a `subtype` filter to return catalog-specific results, and `getRatingIdsForTimeEntries` may need to return `Map<(String, String), String>` keyed by `(timeEntryId, catalogId)`.

4. **`subtype` column** — No conflict. DayPlanEntry maps to `subtype = ''`. RatingEntry also currently maps to `''`. Our change to populate it with `catalogId` is isolated to RatingEntry.

## Verification

1. Run `dart-mcp.analyze_files` — zero warnings
2. Run `dart-mcp.dart_format` — clean
3. Run targeted tests: `test/classes/rating_data_test.dart`, `test/features/ratings/`
4. Manual: Stop a time entry → session rating modal appears with same 4 questions → save → verify stored data includes question metadata and catalogId
5. Manual: Create old-format rating in test → verify summary renders correctly (fallback to catalog labels)
