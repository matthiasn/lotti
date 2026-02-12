# Remove Sync-Affected Drift watch() Streams

**Date**: 2026-02-12
**Prerequisite for**: [Actor-Based Sync Isolate Plan](2026-02-12_actor_based_sync_isolate_plan.md)
**Status**: In Progress — Steps 1–9 complete, Steps 10–14 remaining

## Context

The actor-based sync isolate plan requires DB writes from a separate isolate. Drift
`watch()` streams are per-connection: writes on one DB connection do NOT trigger `watch()`
streams on another connection. Rather than working around this with
`markTablesAsUpdated()`, we remove all sync-affected Drift `watch()` usage entirely
before starting the actor implementation.

The codebase already has the building blocks:

- **`UpdateNotifications`** (`lib/services/db_notification.dart`): broadcast stream with
  dual debounce (100ms local, 1s sync). Already used by 29+ files for journal entries.
- **`EntitiesCacheService`** (`lib/services/entities_cache_service.dart`): in-memory cache
  for categories, habits, dashboards, measurables, labels. Currently populated via Drift
  `watch()` — will be migrated to notification-driven fetching.
- **`persistence_logic.dart:763`**: already calls
  `_updateNotifications.notify({entityDefinition.id})` on upsert.
- **`sync_event_processor.dart:708,896,974`**: already calls
  `_updateNotifications.notify(affectedIds, fromSync: true)` for journal entries.

**Scope**: Sync-affected watch methods only. Local-only watches (`watchConfigFlag`,
`watchActiveConfigFlagNames`, `watchOutboxCount`) are kept as-is — they are
single-connection and unaffected by the actor.

---

## Inventory of Sync-Affected watch() Methods

| Method | DB | Consumers |
|--------|-----|-----------|
| `watchCategories()` | JournalDb | EntitiesCacheService, CategoriesRepository, categoriesStreamProvider, CategoriesListController, dashboardCategoriesProvider, dashboard_category.dart StreamBuilder, sync_maintenance_repository `.first` |
| `watchCategoryById(id)` | JournalDb | CategoriesRepository pass-through |
| `watchHabitDefinitions()` | JournalDb | EntitiesCacheService, HabitsRepository, HabitsController, habits_page.dart StreamBuilder, dashboard_definition_page.dart StreamBuilder, sync_maintenance_repository `.first` |
| `watchHabitById(id)` | JournalDb | HabitsRepository, habitByIdProvider, dashboard_item_card.dart StreamBuilder, habit_summary.dart StreamBuilder |
| `watchDashboards()` | JournalDb | EntitiesCacheService, HabitsRepository, dashboardsProvider, habitDashboardsProvider, dashboards_page.dart StreamBuilder, sync_maintenance_repository `.first` |
| `watchDashboardById(id)` | JournalDb | dashboard_definition_page.dart StreamBuilder |
| `watchLabelDefinitions()` | JournalDb | EntitiesCacheService, LabelsRepository, sync_maintenance_repository `.first` |
| `watchLabelDefinitionById(id)` | JournalDb | LabelsRepository pass-through |
| `watchMeasurableDataTypes()` | JournalDb | EntitiesCacheService, measurables_page.dart StreamBuilder, dashboard_item_card.dart StreamBuilder, dashboard_definition_page.dart StreamBuilder, sync_maintenance_repository `.first` |
| `watchMeasurableDataTypeById(id)` | JournalDb | measurable_details_page.dart StreamBuilder |
| `watchTags()` | JournalDb | TagsService (cache + public stream), tags_page.dart, tags_list_widget.dart, tags_view_widget.dart, storyTagsStreamProvider, sync_maintenance_repository `.first` |
| `watchLabelUsageCounts()` | JournalDb | labelUsageStatsProvider |
| `watchSettingsItemByKey()` | SettingsDb | ThemingController, SettingsDb.removeSettingsItem(), SettingsDb.itemByKey(), VectorClockService |

**NOT in scope** (local-only):
- `watchConfigFlag()` — local toggle, not synced
- `watchActiveConfigFlagNames()` — derived from local flags
- `watchOutboxCount()` — from SyncDatabase, separate connection

---

## Write-Path Notification Coverage Matrix

All write paths for sync-affected data must emit the correct type notification key.
This table is a required verification artifact — every row must be confirmed during
implementation.

| Entity Type | Local Write Path | Currently Notifies? | Sync Write Path | Currently Notifies? |
|-------------|-----------------|---------------------|-----------------|---------------------|
| CategoryDefinition | `persistence_logic.upsertEntityDefinition()` :763 | YES — `{entityDefinition.id}` (needs type key added) | `sync_event_processor.dart:1056-1058` — `journalDb.upsertEntityDefinition()` | **NO** — no notification at all |
| HabitDefinition | `persistence_logic.upsertEntityDefinition()` :763 | YES — needs type key | `sync_event_processor.dart:1056-1058` | **NO** |
| DashboardDefinition | `persistence_logic.upsertEntityDefinition()` :763 AND `upsertDashboardDefinition()` :773 | YES (entity) / **NO** (dashboard-specific) | `sync_event_processor.dart:1056-1058` | **NO** |
| MeasurableDataType | `persistence_logic.upsertEntityDefinition()` :763 | YES — needs type key | `sync_event_processor.dart:1056-1058` | **NO** |
| LabelDefinition | `persistence_logic.upsertEntityDefinition()` :763 | YES — needs type key | `sync_event_processor.dart:1056-1058` | **NO** |
| TagEntity | `tags_repository.dart:129` — `upsertTagEntity()` | **NO** — no notification | `sync_event_processor.dart:1059-1061` — `journalDb.upsertTagEntity()` | **NO** |
| Settings (theming) | `theming_controller.dart` — `SettingsDb.saveSettingsItem()` | **NO** | `sync_event_processor.dart:1074+` — `SyncThemingSelection` | **NO** |
| **Private flag** | `flags_page.dart:166` calls `journalDb.upsertConfigFlag()` | **NO** | N/A (local-only) | N/A |
| **Labeled table** | `persistence_logic.updateDbEntity()` :720 AND `createDbEntity()` :467 — both fire `journalEntity.affectedIds` | **NO** (entity IDs only, not `labelUsageNotification`) | `sync_event_processor.dart:896` fires `journalEntity.affectedIds, fromSync: true` | **NO** (same — only entity IDs) |

**Critical findings**:
1. Entity definition and tag sync writes (`sync_event_processor.dart` lines 1056–1061)
   currently perform raw DB upserts with ZERO notifications. Removing Drift watch()
   without fixing these paths would cause the UI to never update after receiving synced
   entity definitions or tags.
2. All drift definition queries (`allTagEntities`, `allDashboards`, `allHabitDefinitions`,
   `allCategoryDefinitions`, `allLabelDefinitions`, `activeMeasurableTypes`, and their
   by-id variants) include `WHERE private IN (0, (SELECT status FROM config_flags WHERE
   name = 'private'))`. With Drift watch(), toggling the private flag auto-triggers
   re-queries. With notification-driven streams, a `privateToggleNotification` must be
   fired to achieve the same reactivity.
3. `watchLabelUsageCounts()` reads from the `labeled` table, NOT from label definitions.
   The `labeled` table changes when `addLabeled()` runs (from journal entity saves/syncs),
   not when `labelsNotification` fires. A separate `labelUsageNotification` is needed.

---

## Step 1: Add Entity-Type Notification Constants [DONE]

**File**: `lib/services/db_notification.dart`

Add constants alongside existing ones (`habitCompletionNotification`, etc.):

```dart
const categoriesNotification = 'CATEGORIES_CHANGED';
const habitsNotification = 'HABITS_CHANGED';
const dashboardsNotification = 'DASHBOARDS_CHANGED';
const measurablesNotification = 'MEASURABLES_CHANGED';
const labelsNotification = 'LABELS_CHANGED';
const tagsNotification = 'TAGS_CHANGED';
const settingsNotification = 'SETTINGS_CHANGED';
const privateToggleNotification = 'PRIVATE_FLAG_TOGGLED';
const labelUsageNotification = 'LABEL_USAGE_CHANGED';
```

**Tests**: None needed — constants only.

---

## Step 2: Fire Type-Specific Notifications on ALL Write Paths [DONE]

This step must cover every row in the notification coverage matrix above.

### 2a. persistence_logic — entity definitions (local writes)

**File**: `lib/logic/persistence_logic.dart`

`upsertEntityDefinition()` (line 760) currently calls
`_updateNotifications.notify({entityDefinition.id})`. Extend to include the type constant:

```dart
final typeNotification = switch (entityDefinition) {
  CategoryDefinition() => categoriesNotification,
  HabitDefinition() => habitsNotification,
  DashboardDefinition() => dashboardsNotification,
  MeasurableDataType() => measurablesNotification,
  LabelDefinition() => labelsNotification,
};
_updateNotifications.notify({entityDefinition.id, typeNotification});
```

`upsertDashboardDefinition()` (line 773): add `dashboardsNotification` to the notify
call.

### 2b. tags_repository — tag upserts (local writes)

**File**: `lib/features/tags/repository/tags_repository.dart`

`upsertTagEntity()` (line 129) calls `_journalDb.upsertTagEntity()` then enqueues a sync
message but does NOT fire `UpdateNotifications`. Fix:

```dart
static Future<int> upsertTagEntity(TagEntity tagEntity) async {
  final linesAffected = await _journalDb.upsertTagEntity(tagEntity);
  getIt<UpdateNotifications>().notify({tagEntity.id, tagsNotification});
  await outboxService.enqueueMessage(...);
  return linesAffected;
}
```

Note: `createStoryTag()` does NOT exist in `tags_repository.dart`. The only tag creation
path is `upsertTagEntity()`, which covers all local tag writes.

### 2c. sync_event_processor — entity definitions from sync

**File**: `lib/features/sync/matrix/sync_event_processor.dart`

Lines 1056–1058: `SyncEntityDefinition` case just calls
`journalDb.upsertEntityDefinition(entityDefinition)` with NO notification.

Fix: add type-specific notification + `fromSync: true`:

```dart
case SyncEntityDefinition(entityDefinition: final entityDefinition):
  await journalDb.upsertEntityDefinition(entityDefinition);
  final typeNotification = switch (entityDefinition) {
    CategoryDefinition() => categoriesNotification,
    HabitDefinition() => habitsNotification,
    DashboardDefinition() => dashboardsNotification,
    MeasurableDataType() => measurablesNotification,
    LabelDefinition() => labelsNotification,
  };
  _updateNotifications.notify(
    {entityDefinition.id, typeNotification},
    fromSync: true,
  );
  return null;
```

### 2d. sync_event_processor — tags from sync

Lines 1059–1061: `SyncTagEntity` case calls `journalDb.upsertTagEntity()` with NO
notification. Fix:

```dart
case SyncTagEntity(tagEntity: final tagEntity):
  await journalDb.upsertTagEntity(tagEntity);
  _updateNotifications.notify(
    {tagEntity.id, tagsNotification},
    fromSync: true,
  );
  return null;
```

### 2e. sync_event_processor — theming settings from sync

Lines 1074+: `SyncThemingSelection` case saves settings but does not fire
`settingsNotification`. After the settings save, add:

```dart
_updateNotifications.notify({settingsNotification}, fromSync: true);
```

### 2f. flags_page — private flag toggle

**Principle**: DB methods (`toggleConfigFlag`, `upsertConfigFlag`) remain pure — no
`getIt`, no `UpdateNotifications` dependency. Notifications are fired by the caller who
knows the context (local vs sync). This preserves isolate-boundary compatibility for the
actor plan.

**File**: `lib/logic/persistence_logic.dart`

Add a new method that wraps the DB call and fires the notification:

```dart
Future<void> setConfigFlag(ConfigFlag configFlag) async {
  await _journalDb.upsertConfigFlag(configFlag);
  if (configFlag.name == 'private') {
    _updateNotifications.notify({privateToggleNotification});
  }
}
```

**File**: `lib/features/settings/ui/pages/flags_page.dart`

Update `flags_page.dart:166` — replace direct `journalDb.upsertConfigFlag()` call with
`getIt<PersistenceLogic>().setConfigFlag(flag.copyWith(status: status))`.

**Why only `'private'`**: Other config flags (feature flags) don't affect definition
queries. Only the `'private'` flag is embedded in drift WHERE clauses. The private flag
is local-only (never synced), so `fromSync: false` (default) is always correct.

**Note**: `toggleConfigFlag()` in `database.dart` is never called from outside the DB
class itself — no callers need migration.

### 2g. Labeled table changes — notify from caller layers

**Principle**: `addLabeled()` (database.dart:318) is a DB-layer method and must remain
pure — no `getIt`, no notification side effects. Instead, add `labelUsageNotification`
to the existing notification calls in the caller layers, which already fire
`UpdateNotifications` with the correct `fromSync` context.

All three call sites that write journal entities and fire `UpdateNotifications` must
include `labelUsageNotification`. The DB's `updateJournalEntity()` internally calls
`addLabeled()` which reconciles the `labeled` table — the data source for
`watchLabelUsageCounts()`.

**File**: `lib/logic/persistence_logic.dart`

`updateDbEntity()` (line 720) already fires `_updateNotifications.notify(...)`. Add
`labelUsageNotification` to the existing set:

```dart
_updateNotifications.notify({
  ...journalEntity.affectedIds,
  if (linkedId != null) linkedId,
  labelUsageNotification,
});
```

`createDbEntity()` (line 467) also fires `_updateNotifications.notify(affectedIds)` and
calls `_journalDb.updateJournalEntity()` (line 431) which internally calls `addLabeled()`.
Add `labelUsageNotification` here too:

```dart
_updateNotifications.notify({...affectedIds, labelUsageNotification});
```

This is important because `createDbEntity()` is called widely: checklist items
(`checklist_repository.dart:99`), ratings (`rating_repository.dart:108`), journal entries
(`journal_repository.dart:221`), tasks, AI responses, etc. Any of these can carry labels.

This slightly over-fires (not every entity write changes labels), but:
- `UpdateNotifications` debounces (100ms), so bursty updates coalesce
- Only triggers a re-query if someone is actually listening to `labelUsageStatsProvider`
- Correctness is guaranteed — no missed label changes

**File**: `lib/features/sync/matrix/sync_event_processor.dart`

Line 896 already fires `_updateNotifications.notify(journalEntity.affectedIds, fromSync: true)`.
Add `labelUsageNotification`:

```dart
_updateNotifications.notify(
  {...journalEntity.affectedIds, labelUsageNotification},
  fromSync: true,
);
```

This preserves `fromSync: true` semantics (1s debounce for sync-originated writes).

**Tests**: Update `persistence_logic_test.dart`, `sync_event_processor_test.dart`,
`tags_repository_test.dart`, and `database_test.dart` to verify type-specific
notifications are fired for every write path.

---

## Step 3: Create Notification-Driven Stream Helper [DONE]

**New file**: `lib/services/notification_stream.dart`

### Design decisions

1. **Broadcast semantics**: `UpdateNotifications.updateStream` is already a broadcast
   stream. The helper wraps it in `StreamController<T>.broadcast()` so multiple listeners
   can subscribe (required by `TagsService` which both listens internally and exposes a
   public stream).

2. **Multi-key filtering**: Each stream accepts `Set<String> notificationKeys` (not a
   single key). This allows definition streams to listen for both their type key AND
   `privateToggleNotification`, so toggling the private flag triggers a re-fetch.

3. **Fetch serialization**: If a notification arrives while a previous fetch is in
   progress, skip the in-flight notification rather than queuing — the next notification
   will refresh anyway.

4. **Error strategy**: Catch errors from the fetcher. On error, emit the error to the
   stream (so StreamBuilder shows error state) but do NOT close the stream — continue
   listening for the next notification.

5. **Per-call-site stream instances**: Each call to `notificationDrivenStream()` returns a
   fresh `StreamController.broadcast()` instance with its own `onListen`/`onCancel`
   lifecycle. In practice, each stream has exactly one subscriber (either a Riverpod
   `StreamProvider` or a widget's `StreamBuilder`). The `onListen` callback fires for the
   first subscriber, triggering the initial fetch. This provides parity with Drift
   `watch()` — every subscriber gets data on first listen.

   **Invariant**: If future code needs to share a single stream instance across multiple
   concurrent subscribers, a `BehaviorSubject`-like cached replay wrapper should be
   introduced at that point. The current design does not require it.

```dart
import 'dart:async';
import 'package:lotti/services/db_notification.dart';

/// Creates a broadcast stream that emits an initial fetch result then re-emits
/// whenever any key in [notificationKeys] appears in the
/// [UpdateNotifications] stream.
///
/// The stream is broadcast-safe: multiple listeners can subscribe.
/// Fetches are serialized: overlapping notifications are coalesced.
Stream<List<T>> notificationDrivenStream<T>({
  required UpdateNotifications notifications,
  required Set<String> notificationKeys,
  required Future<List<T>> Function() fetcher,
}) {
  late StreamController<List<T>> controller;
  StreamSubscription<Set<String>>? sub;
  var fetching = false;
  var pendingRefetch = false;

  Future<void> doFetch() async {
    if (fetching) {
      pendingRefetch = true;
      return;
    }
    fetching = true;
    try {
      final result = await fetcher();
      if (!controller.isClosed) controller.add(result);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      fetching = false;
      if (pendingRefetch && !controller.isClosed) {
        pendingRefetch = false;
        await doFetch();
      }
    }
  }

  controller = StreamController<List<T>>.broadcast(
    onListen: () {
      doFetch(); // initial fetch
      sub = notifications.updateStream.listen((ids) {
        if (ids.any(notificationKeys.contains)) doFetch();
      });
    },
    onCancel: () {
      sub?.cancel();
      sub = null;
    },
  );

  return controller.stream;
}

/// Single-item variant. Same broadcast/serialization semantics.
Stream<T?> notificationDrivenItemStream<T>({
  required UpdateNotifications notifications,
  required Set<String> notificationKeys,
  required Future<T?> Function() fetcher,
}) {
  late StreamController<T?> controller;
  StreamSubscription<Set<String>>? sub;
  var fetching = false;
  var pendingRefetch = false;

  Future<void> doFetch() async {
    if (fetching) {
      pendingRefetch = true;
      return;
    }
    fetching = true;
    try {
      final result = await fetcher();
      if (!controller.isClosed) controller.add(result);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      fetching = false;
      if (pendingRefetch && !controller.isClosed) {
        pendingRefetch = false;
        await doFetch();
      }
    }
  }

  controller = StreamController<T?>.broadcast(
    onListen: () {
      doFetch();
      sub = notifications.updateStream.listen((ids) {
        if (ids.any(notificationKeys.contains)) doFetch();
      });
    },
    onCancel: () {
      sub?.cancel();
      sub = null;
    },
  );

  return controller.stream;
}

/// Map variant for non-list data (e.g., label usage counts).
Stream<Map<K, V>> notificationDrivenMapStream<K, V>({
  required UpdateNotifications notifications,
  required Set<String> notificationKeys,
  required Future<Map<K, V>> Function() fetcher,
}) {
  late StreamController<Map<K, V>> controller;
  StreamSubscription<Set<String>>? sub;
  var fetching = false;
  var pendingRefetch = false;

  Future<void> doFetch() async {
    if (fetching) {
      pendingRefetch = true;
      return;
    }
    fetching = true;
    try {
      final result = await fetcher();
      if (!controller.isClosed) controller.add(result);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    } finally {
      fetching = false;
      if (pendingRefetch && !controller.isClosed) {
        pendingRefetch = false;
        await doFetch();
      }
    }
  }

  controller = StreamController<Map<K, V>>.broadcast(
    onListen: () {
      doFetch();
      sub = notifications.updateStream.listen((ids) {
        if (ids.any(notificationKeys.contains)) doFetch();
      });
    },
    onCancel: () {
      sub?.cancel();
      sub = null;
    },
  );

  return controller.stream;
}
```

**Tests**: `test/services/notification_stream_test.dart`:
- Verify initial emission on first listen
- Verify re-emission on matching notification (any key in set)
- Verify no emission on non-matching notification
- Verify broadcast (multiple listeners on same stream)
- Verify fetch serialization (concurrent notifications coalesce)
- Verify error handling (error emitted, stream stays alive)
- Verify multi-key: stream reacts to either of two keys
- Verify `onCancel` cleans up subscription

---

## Step 4: API Normalization — Add Missing One-Shot Query Methods [DONE]

**File**: `lib/database/database.dart`

### Existing drift named queries (raw, return DB entity rows)

| Named query (`.drift`) | Used by watch method | Line in .drift |
|------------------------|---------------------|----------------|
| `allCategoryDefinitions()` | `watchCategories()` | 669 |
| `allHabitDefinitions()` | `watchHabitDefinitions()` | 658 |
| `allDashboards()` | `watchDashboards()` | **646 — NOT `allDashboardDefinitions()`** |
| `activeMeasurableTypes()` | `watchMeasurableDataTypes()` | **NOT `allMeasurableDataTypes()`** |
| `allLabelDefinitions()` | `watchLabelDefinitions()` | 681 |
| `allTagEntities()` | `watchTags()` | **640 — NOT `getAllTags()`** |
| `categoryById(id)` | `watchCategoryById()` | 675 |
| `habitById(id)` | `watchHabitById()` | 663 |
| `dashboardById(id)` | `watchDashboardById()` | 652 |
| `measurableTypeById(id)` | `watchMeasurableDataTypeById()` | 552 |
| `labelDefinitionById(id)` | `watchLabelDefinitionById()` | 687 |

### Already-existing mapped one-shot methods

| Method | Returns | Line |
|--------|---------|------|
| `getAllLabelDefinitions()` | `Future<List<LabelDefinition>>` | 1261 |
| `getLabelDefinitionById(id)` | `Future<LabelDefinition?>` | 1266 |
| `getMeasurableDataTypeById(id)` | `Future<MeasurableDataType?>` | 1019 |
| `getLabelUsageCounts()` | `Future<Map<String, int>>` | 1228 |

### Must add (mapped one-shot wrappers)

Each wraps `namedQuery().get()` + the same mapper used by the corresponding watch method:

```dart
// --- List fetchers ---

Future<List<CategoryDefinition>> getAllCategories() async {
  return categoryDefinitionsStreamMapper(
    await allCategoryDefinitions().get(),
  );
}

Future<List<HabitDefinition>> getAllHabitDefinitions() async {
  return habitDefinitionsStreamMapper(
    await allHabitDefinitions().get(),
  );
}

Future<List<DashboardDefinition>> getAllDashboards() async {
  return dashboardStreamMapper(await allDashboards().get());
}

Future<List<MeasurableDataType>> getAllMeasurableDataTypes() async {
  return measurableDataTypeStreamMapper(
    await activeMeasurableTypes().get(),
  );
}

Future<List<TagEntity>> getAllTags() async {
  return tagStreamMapper(await allTagEntities().get());
}

// --- Single-item fetchers ---

Future<CategoryDefinition?> getCategoryById(String id) async {
  final rows = await categoryById(id).get();
  return categoryDefinitionsStreamMapper(rows).firstOrNull;
}

Future<HabitDefinition?> getHabitById(String id) async {
  final rows = await habitById(id).get();
  return habitDefinitionsStreamMapper(rows).firstOrNull;
}

Future<DashboardDefinition?> getDashboardById(String id) async {
  final rows = await dashboardById(id).get();
  return dashboardStreamMapper(rows).firstOrNull;
}
```

**Important**: All subsequent steps in this plan use these exact method names.

---

## Step 5: Migrate SettingsDb Internal Dependencies [DONE]

**File**: `lib/database/settings_db.dart`

Before `watchSettingsItemByKey()` can be removed (Step 14), its non-theming consumers
must be migrated:

### 5a. SettingsDb.itemByKey() (line 44)

Currently: `await watchSettingsItemByKey(configKey).first`.
Replace with direct query:

```dart
Future<String?> itemByKey(String configKey) async {
  final existing = await settingsItemByKey(configKey).get();
  if (existing.isNotEmpty) {
    return existing.first.value;
  }
  return null;
}
```

### 5b. SettingsDb.removeSettingsItem() (line 33)

Currently: `await watchSettingsItemByKey(configKey).first`.
Replace with same direct query:

```dart
Future<void> removeSettingsItem(String configKey) async {
  final existing = await settingsItemByKey(configKey).get();
  if (existing.isNotEmpty) {
    await delete(settings).delete(existing.first);
  }
}
```

### 5c. VectorClockService._getNextAvailableCounter() (line 64)

**File**: `lib/services/vector_clock_service.dart`

Currently: `await getIt<SettingsDb>().watchSettingsItemByKey(key).first`.
Replace with: `await getIt<SettingsDb>().itemByKey(key)` (which now uses direct query).

```dart
Future<void> _getNextAvailableCounter() async {
  final value = await getIt<SettingsDb>().itemByKey(nextAvailableCounterKey);
  if (value != null) {
    _nextAvailableCounter = int.parse(value);
  } else {
    await setNextAvailableCounter(0);
  }
}
```

**Tests**: Update `test/mocks/mocks.dart` — `MockSettingsDb` stubs for
`watchSettingsItemByKey` may be used in tests that call `itemByKey()` or
`removeSettingsItem()`. After migration, those test stubs should stub the new direct
query path instead.

---

## Step 6: Migrate Sync Maintenance Repository `.first` Calls [DONE]

**File**: `lib/features/sync/repository/sync_maintenance_repository.dart`

Replace `watchX().first` with the mapped one-shot methods from Step 4:

| Before | After |
|--------|-------|
| `_journalDb.watchTags().first` (line 61) | `_journalDb.getAllTags()` |
| `_journalDb.watchMeasurableDataTypes().first` (line 74) | `_journalDb.getAllMeasurableDataTypes()` |
| `_journalDb.watchCategories().first` (line 87) | `_journalDb.getAllCategories()` |
| `_journalDb.watchLabelDefinitions().first` (line 101) | `_journalDb.getAllLabelDefinitions()` |
| `_journalDb.watchDashboards().first` (line 114) | `_journalDb.getAllDashboards()` |
| `_journalDb.watchHabitDefinitions().first` (line 127) | `_journalDb.getAllHabitDefinitions()` |

**Tests**: Update `sync_maintenance_repository_test.dart` — stub new query methods
instead of watch stubs.

---

## Step 7: Migrate EntitiesCacheService [DONE]

**File**: `lib/services/entities_cache_service.dart`

Currently subscribes to 6 Drift watch() streams in constructor (lines 9-89).

### Changes

1. Accept `JournalDb` and `UpdateNotifications` as constructor parameters (remove `getIt`
   calls from constructor body).

2. **Synchronous initialization guarantee**: Perform initial DB fetches in a synchronous-
   compatible way. Since `EntitiesCacheService` is used for synchronous lookups during
   writes (e.g., `labels_repository.dart:148` calls `getCategoryById()`), the cache MUST
   be populated before the service is made available in the DI container.

   **Strategy**: Add `Future<void> init()` method. In `lib/get_it.dart`, call and `await`
   this method during startup, BEFORE registering the service as ready. Use
   `registerSingletonAsync` or explicitly await before downstream registrations:

   ```dart
   // In get_it.dart
   final entitiesCacheService = EntitiesCacheService(
     journalDb: getIt<JournalDb>(),
     updateNotifications: getIt<UpdateNotifications>(),
   );
   await entitiesCacheService.init();
   getIt.registerSingleton<EntitiesCacheService>(entitiesCacheService);
   ```

3. Replace each watch subscription with:
   - Initial fetch in `init()` (called during startup, awaited)
   - `UpdateNotifications` listener for subsequent refreshes

4. Add tags to the cache (currently only in `TagsService`).

5. **`LABELS_UPDATED` transition**: The old `LABELS_UPDATED` key
   (`entities_cache_service.dart:83`) is asserted by tests
   (`entities_cache_service_test.dart:1218,1259`). Transition strategy:
   - In this step, dual-emit both `LABELS_UPDATED` and `labelsNotification` temporarily
   - After all consumers are migrated to `labelsNotification`, remove the dual-emit
   - Update tests atomically when removing the old key

6. **Private flag reactivity**: The existing code subscribes to
   `watchConfigFlag('private')` (line 87) which is kept as-is (local-only). Additionally,
   listen for `privateToggleNotification` in the `UpdateNotifications` stream to re-fetch
   ALL definition caches, since all drift named queries filter by the private flag. This
   ensures the cache reflects the correct private-filtered set after a toggle.

### Example init() implementation

Two correctness requirements:

1. **Subscribe before fetch**: Attach the notification listener BEFORE the initial fetch
   completes. This closes the window where a write between fetch-complete and
   listener-attach would be missed. With serialization (below), a notification during the
   initial fetch will queue a refetch.

2. **Per-type fetch serialization**: Each `_loadX()` method uses the same
   fetching/pendingRefetch pattern as the stream helper. This prevents overlapping async
   fetches from bursty notifications (e.g., a `categoriesNotification` and
   `privateToggleNotification` in the same event) from applying out-of-order cache states.

```dart
Future<void> init() async {
  // Subscribe FIRST — closes the missed-event window
  _updateNotifications.updateStream.listen(_onNotification);

  // Then initial fetch (listener already active, catches concurrent writes)
  await Future.wait([
    _loadCategories(),
    _loadHabits(),
    _loadDashboards(),
    _loadMeasurables(),
    _loadLabels(),
    _loadTags(),
    _loadPrivateFlag(),
  ]);
}

void _onNotification(Set<String> ids) {
  final needCategories = ids.contains(categoriesNotification) ||
      ids.contains(privateToggleNotification);
  final needHabits = ids.contains(habitsNotification) ||
      ids.contains(privateToggleNotification);
  final needDashboards = ids.contains(dashboardsNotification) ||
      ids.contains(privateToggleNotification);
  final needMeasurables = ids.contains(measurablesNotification) ||
      ids.contains(privateToggleNotification);
  final needLabels = ids.contains(labelsNotification) ||
      ids.contains(privateToggleNotification);
  final needTags = ids.contains(tagsNotification) ||
      ids.contains(privateToggleNotification);

  if (needCategories) _loadCategories();
  if (needHabits) _loadHabits();
  if (needDashboards) _loadDashboards();
  if (needMeasurables) _loadMeasurables();
  if (needLabels) _loadLabels();
  if (needTags) _loadTags();
}
```

Each `_loadX()` method guards against concurrent execution:

```dart
bool _categoriesLoading = false;
bool _categoriesPending = false;

Future<void> _loadCategories() async {
  if (_categoriesLoading) {
    _categoriesPending = true;
    return;
  }
  _categoriesLoading = true;
  try {
    final cats = await _journalDb.getAllCategories();
    categoriesById.clear();
    for (final cat in cats) {
      categoriesById[cat.id] = cat;
    }
  } finally {
    _categoriesLoading = false;
    if (_categoriesPending) {
      _categoriesPending = false;
      await _loadCategories();
    }
  }
}
// Same pattern for _loadHabits, _loadDashboards, etc.
```

**Tests**: Update `test/services/entities_cache_service_test.dart` — mock
`UpdateNotifications`, verify cache refreshes on notification instead of stream emission.
Add test for private toggle triggering full cache refresh. Add test that bursty
notifications coalesce correctly. Temporarily keep `LABELS_UPDATED` assertion.

---

## Step 8: Migrate Repositories [DONE]

All repository notification streams include `privateToggleNotification` alongside their
type key, because the underlying drift queries filter by the private config flag.

### 8a. CategoriesRepository

**File**: `lib/features/categories/repository/categories_repository.dart`

- Add `UpdateNotifications` as constructor dependency.
- Replace `watchCategories()` (line 31): return `notificationDrivenStream(...)` using
  `notificationKeys: {categoriesNotification, privateToggleNotification}`,
  `fetcher: () => _journalDb.getAllCategories()`.
- Replace `watchCategory(id)` (line 35): return `notificationDrivenItemStream(...)` using
  `notificationKeys: {categoriesNotification, privateToggleNotification}`,
  `fetcher: () => _journalDb.getCategoryById(id)`.
- Update provider to pass `UpdateNotifications`.

### 8b. LabelsRepository

**File**: `lib/features/labels/repository/labels_repository.dart`

- Add `UpdateNotifications` as constructor dependency.
- Replace `watchLabels()` (line 36): return `notificationDrivenStream(...)` using
  `notificationKeys: {labelsNotification, privateToggleNotification}`,
  `fetcher: () => _journalDb.getAllLabelDefinitions()`.
- Replace `watchLabel(id)` (line 41): return `notificationDrivenItemStream(...)` using
  `notificationKeys: {labelsNotification, privateToggleNotification}`,
  `fetcher: () => _journalDb.getLabelDefinitionById(id)`.
- Update provider.

### 8c. HabitsRepository

**File**: `lib/features/habits/repository/habits_repository.dart`

- Replace `watchHabitDefinitions()` (line 77): `notificationDrivenStream(...)` using
  `notificationKeys: {habitsNotification, privateToggleNotification}`,
  `fetcher: () => _journalDb.getAllHabitDefinitions()`.
- Replace `watchHabitById(id)` (line 82): `notificationDrivenItemStream(...)` using
  `notificationKeys: {habitsNotification, privateToggleNotification}`,
  `fetcher: () => _journalDb.getHabitById(id)`.
- Replace `watchDashboards()` (line 112): `notificationDrivenStream(...)` using
  `notificationKeys: {dashboardsNotification, privateToggleNotification}`,
  `fetcher: () => _journalDb.getAllDashboards()`.
- Update interface and implementation.

**Tests**: Update repository test files — mock `UpdateNotifications`, use
`StreamController<Set<String>>.broadcast()` to simulate notifications.

---

## Step 9: Migrate State Controllers [DONE]

Most controllers consume repository streams, so after Step 8 they automatically get
notification-driven streams. Verify each one works:

### 9a. CategoriesListController

**File**: `lib/features/categories/state/categories_list_controller.dart`

- `categoriesStreamProvider` (line 12): transparent — repository now returns notification
  stream.
- `CategoriesListController.build()`: transparent.
- No code changes needed.

### 9b. LabelsListController

**File**: `lib/features/labels/state/labels_list_controller.dart`

- `labelsStreamProvider` (line 28): transparent via repository.
- `showPrivateEntriesProvider` (line 11): **KEEP** — uses `watchConfigFlag` (local-only).
- `labelUsageStatsProvider` (line 14): replace `db.watchLabelUsageCounts()` with
  `notificationDrivenMapStream(notificationKeys: {labelUsageNotification, labelsNotification}, fetcher: () => db.getLabelUsageCounts())`.

**Why both keys**: `labelUsageNotification` fires when the `labeled` table changes
(journal entry label edits — Step 2g adds it to `persistence_logic.updateDbEntity()` and
`sync_event_processor`). `labelsNotification` fires when a label definition is
created/deleted, which also affects usage count display (a deleted label's count should
disappear). Both keys are needed for full correctness.

### 9c. DashboardsPageController

**File**: `lib/features/dashboards/state/dashboards_page_controller.dart`

- `dashboardsProvider` (line 11): replace `db.watchDashboards()` with
  `notificationDrivenStream(notificationKeys: {dashboardsNotification, privateToggleNotification}, fetcher: () async => (await db.getAllDashboards()).where((d) => d.active).toList())`.
- `dashboardCategoriesProvider` (line 43): replace `db.watchCategories()` with
  `notificationDrivenStream(notificationKeys: {categoriesNotification, privateToggleNotification}, fetcher: () => db.getAllCategories())`.

### 9d. HabitsController

**File**: `lib/features/habits/state/habits_controller.dart`

- `_definitionsSubscription` (line 49): transparent — repository migration handles it.
- No code changes needed.

### 9e. HabitSettingsController

**File**: `lib/features/habits/state/habit_settings_controller.dart`

- `habitByIdProvider` (line 43): transparent via repository.
- `habitDashboardsProvider` (line 53): transparent via repository.
- `storyTagsStreamProvider` (line 82): depends on TagsService migration (Step 11).

**Tests**: Run existing controller tests. Most should pass without changes since the
stream interface is preserved.

---

## Step 10: Migrate Widgets (StreamBuilder → Notification-Driven) [IN PROGRESS]

All these widgets use `StreamBuilder` with Drift watch() streams. Replace the stream
source with `notificationDrivenStream()` or `notificationDrivenItemStream()`.

All definition streams include `privateToggleNotification` in addition to their type key.

| Widget File | Current watch() | Notification Keys | Fetcher |
|-------------|----------------|-------------------|---------|
| `measurables_page.dart:16` | `watchMeasurableDataTypes()` | `{measurablesNotification, privateToggleNotification}` | `db.getAllMeasurableDataTypes()` |
| `dashboards_page.dart` | `watchDashboards()` | `{dashboardsNotification, privateToggleNotification}` | `db.getAllDashboards()` |
| `habits_page.dart` | `watchHabitDefinitions()` | `{habitsNotification, privateToggleNotification}` | `db.getAllHabitDefinitions()` |
| `dashboard_definition_page.dart:150` | `watchHabitDefinitions()` | `{habitsNotification, privateToggleNotification}` | `db.getAllHabitDefinitions()` |
| `dashboard_definition_page.dart:166` | `watchMeasurableDataTypes()` | `{measurablesNotification, privateToggleNotification}` | `db.getAllMeasurableDataTypes()` |
| `dashboard_definition_page.dart:549` | `watchDashboardById()` | `{dashboardsNotification, privateToggleNotification}` | `db.getDashboardById(id)` |
| `dashboard_item_card.dart:89` | `watchMeasurableDataTypes()` | `{measurablesNotification, privateToggleNotification}` | `db.getAllMeasurableDataTypes()` |
| `dashboard_item_card.dart:139` | `watchHabitById()` | `{habitsNotification, privateToggleNotification}` | `db.getHabitById(id)` |
| `dashboard_category.dart:28` | `watchCategories()` | `{categoriesNotification, privateToggleNotification}` | `db.getAllCategories()` |
| `tags_page.dart` | `watchTags()` | `{tagsNotification, privateToggleNotification}` | `db.getAllTags()` |
| `tags_list_widget.dart:30` | `watchTags()` | `{tagsNotification, privateToggleNotification}` | `db.getAllTags()` |
| `tags_view_widget.dart:27` | `watchTags()` | `{tagsNotification, privateToggleNotification}` | `db.getAllTags()` |
| `habit_summary.dart:33` | `watchHabitById()` | `{habitsNotification, privateToggleNotification}` | `db.getHabitById(id)` |
| `measurable_details_page.dart:233` | `watchMeasurableDataTypeById()` | `{measurablesNotification, privateToggleNotification}` | `db.getMeasurableDataTypeById(id)` |

All paths in `lib/features/settings/ui/pages/` and `lib/features/journal/ui/widgets/`.

**Tests**: Update widget tests to provide `UpdateNotifications` mock.

---

## Step 11: Migrate TagsService [TODO]

**File**: `lib/services/tags_service.dart`

Currently calls `_db.watchTags()` in constructor (line 8) and maintains `tagsById` cache.
The stream is both used internally (`listen()`) AND exposed publicly via `watchTags()`
(line 67) — hence the broadcast requirement in Step 3.

### Changes

1. Accept `UpdateNotifications` as constructor dependency.
2. Replace constructor watch with subscribe-before-fetch + serialized loader:
   ```dart
   bool _tagsLoading = false;
   bool _tagsPending = false;

   Future<void> init() async {
     // Subscribe FIRST — closes the missed-event window
     _updateNotifications.updateStream.listen((ids) {
       if (ids.contains(tagsNotification) ||
           ids.contains(privateToggleNotification)) {
         _loadTags();
       }
     });
     // Then initial fetch
     await _loadTags();
   }

   Future<void> _loadTags() async {
     if (_tagsLoading) {
       _tagsPending = true;
       return;
     }
     _tagsLoading = true;
     try {
       final tags = await _db.getAllTags();
       tagsById.clear();
       for (final tag in tags) {
         tagsById[tag.id] = tag;
       }
     } finally {
       _tagsLoading = false;
       if (_tagsPending) {
         _tagsPending = false;
         await _loadTags();
       }
     }
   }
   ```
3. `watchTags()` method (line 67): return `notificationDrivenStream(notificationKeys:
   {tagsNotification, privateToggleNotification}, fetcher: () => _db.getAllTags())`.

**File**: `lib/get_it.dart` — pass `UpdateNotifications` to TagsService constructor and
await `init()`.

**Tests**: Update `tags_service_test.dart`.

---

## Step 12: Migrate ThemingController Settings Watch [TODO]

**File**: `lib/features/theming/state/theming_controller.dart`

`_watchThemePrefsUpdates()` (line 137) subscribes to
`getIt<SettingsDb>().watchSettingsItemByKey(themePrefsUpdatedAtKey)`.

**Replace** with `UpdateNotifications` listener for `settingsNotification`, preserving
the existing subscription lifecycle (variable storage + dispose cancel):

```dart
StreamSubscription<Set<String>>? _settingsNotificationSub;

@override
ThemingState build() {
  ref.onDispose(() {
    _settingsNotificationSub?.cancel();
    EasyDebounce.cancel(_debounceKey);
  });
  _init();
  return ThemingState(...);
}

void _watchThemePrefsUpdates() {
  _settingsNotificationSub =
      getIt<UpdateNotifications>().updateStream.listen((ids) async {
    if (ids.contains(settingsNotification) && !_isApplyingSyncedChanges) {
      _isApplyingSyncedChanges = true;
      try {
        await _loadSelectedSchemes();
      } catch (e, st) {
        getIt<LoggingService>().captureException(
          e,
          domain: 'THEMING_CONTROLLER',
          subDomain: 'theme_prefs_reload',
          stackTrace: st,
        );
        // Keep current theme if reload fails
      }
      _isApplyingSyncedChanges = false;
    }
  });
}
```

**Key**: The subscription is stored in `_settingsNotificationSub` and cancelled in
`ref.onDispose()`, matching the existing lifecycle pattern from the current
`_themePrefsSubscription`.

Step 2e ensures that the sync event processor fires `settingsNotification` when theming
settings arrive from sync.

**Tests**: Update `theming_controller_test.dart`.

---

## Step 13: Remove `LABELS_UPDATED` Dual-Emit [TODO]

After all consumers have been migrated from `LABELS_UPDATED` to `labelsNotification`:

1. Remove the dual-emit from `EntitiesCacheService`
2. Update `entities_cache_service_test.dart:1218,1259` to assert `labelsNotification`
3. Search codebase for any remaining `LABELS_UPDATED` references and migrate them

---

## Step 14: Remove Drift watch() Methods [TODO]

### JournalDb

**File**: `lib/database/database.dart`

Remove (after all consumers migrated):
- `watchCategories()`, `watchCategoryById()`
- `watchHabitDefinitions()`, `watchHabitById()`
- `watchDashboards()`, `watchDashboardById()`
- `watchLabelDefinitions()`, `watchLabelDefinitionById()`
- `watchMeasurableDataTypes()`, `watchMeasurableDataTypeById()`
- `watchTags()`
- `watchLabelUsageCounts()`

### SettingsDb

**File**: `lib/database/settings_db.dart`

Remove `watchSettingsItemByKey()` (line 40). After Step 5, no consumers remain:
- `itemByKey()` → migrated to direct query (Step 5a)
- `removeSettingsItem()` → migrated to direct query (Step 5b)
- `VectorClockService` → migrated to use `itemByKey()` (Step 5c)
- `ThemingController` → migrated to UpdateNotifications (Step 12)

### Keep

- `watchConfigFlag()` — local-only, used by many UI features
- `watchActiveConfigFlagNames()` — local-only
- `watchOutboxCount()` — from SyncDatabase, separate DB

### Mocks

**File**: `test/mocks/mocks.dart`

Remove stubs for deleted watch methods. Fix resulting compilation errors in tests.

---

## Step 15: Update Tests [ONGOING]

For each migrated file, update the corresponding test file:

1. Remove Drift watch stream stubs from test setup
2. Add `UpdateNotifications` mock with `StreamController<Set<String>>.broadcast()`
3. Simulate notifications by adding to the stream controller
4. Verify cache refresh / provider rebuild on notification

Key test files:
- `test/services/entities_cache_service_test.dart`
- `test/services/notification_stream_test.dart` (new)
- `test/features/categories/` tests
- `test/features/labels/` tests
- `test/features/habits/` tests
- `test/features/dashboards/` tests
- `test/features/theming/` tests
- `test/features/settings/ui/pages/flags_page_test.dart` — Step 2f changes
  `flags_page.dart` from direct `journalDb.upsertConfigFlag()` to
  `persistenceLogic.setConfigFlag()`. Existing assertions at lines 153, 171 that verify
  the direct DB call must be migrated to verify the PersistenceLogic call path instead.
- `test/logic/persistence_logic_test.dart` — new `setConfigFlag()` method needs tests
- `test/services/tags_service_test.dart`
- `test/features/sync/repository/sync_maintenance_repository_test.dart`
- `test/mocks/mocks.dart`

---

## Execution Order

Steps have dependencies. Recommended order:

| Order | Step | Depends on | Risk |
|-------|------|------------|------|
| 1 | Step 1 (notification constants) | — | None |
| 2 | Step 3 (stream helper) | — | None |
| 3 | Step 4 (API normalization) | — | Low |
| 4 | Step 5 (SettingsDb internals) | — | Low |
| 5 | Step 2 (fire notifications — ALL write paths, incl. private & labeled) | Step 1 | Medium |
| 6 | Step 6 (sync maint .first) | Step 4 | Low |
| 7 | Step 7 (EntitiesCacheService) | Steps 1-4 | Medium |
| 8 | Step 8 (repositories) | Steps 3, 4 | Medium |
| 9 | Step 9 (controllers) | Step 8 | Low (mostly transparent) |
| 10 | Step 10 (widgets) | Step 3 | Medium (many files) |
| 11 | Step 11 (TagsService) | Steps 1, 3 | Low |
| 12 | Step 12 (ThemingController) | Step 2e | Low |
| 13 | Step 13 (remove LABELS_UPDATED dual-emit) | Steps 7-10 | Low |
| 14 | Step 14 (remove watch methods) | ALL above | High |
| 15 | Step 15 (test cleanup) | Incremental | Medium |

**Rule**: Within each step, write/update tests, verify analyzer green, verify tests pass
before moving to next step.

---

## Verification

After each step:
1. `dart-mcp.analyze_files` — zero warnings
2. `dart-mcp.dart_format` — all formatted
3. `dart-mcp.run_tests` for affected test files

After all steps:
1. Full test suite passes
2. No sync-affected `watch()` calls remain in `lib/`:
   ```
   rg 'watchCategories|watchCategoryById|watchHabitDefinitions|watchHabitById|watchDashboards|watchDashboardById|watchLabelDefinitions|watchLabelDefinitionById|watchMeasurableDataTypes|watchMeasurableDataTypeById|watchTags\(\)|watchLabelUsageCounts|watchSettingsItemByKey' lib/
   ```
   Returns zero results.
3. Verify notification coverage matrix: for each entity type, perform a local write and a
   simulated sync write, confirm UI updates via UpdateNotifications path.
4. Verify private flag toggle: navigate to labels/categories/habits/dashboards/measurables
   pages, toggle private flag, confirm lists refresh immediately.
5. Verify label usage counts: add/remove a label from a journal entry, confirm usage
   counts update on the labels page.
6. App runs: navigate categories/habits/dashboards/labels/measurables/tags pages — data
   loads correctly.
7. Create/edit/delete entities from the app — lists refresh correctly.
8. Simulate sync event — UI refreshes via UpdateNotifications path.
