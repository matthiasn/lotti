# Database & Logic Layer Modularity Refactor

**Date**: 2026-01-21

## Overview

Refactor `lib/database` and `lib/logic` to improve modularity, reduce coupling, and enhance testability. The current architecture has monolithic classes (JournalDb at 1,396 lines, PersistenceLogic at 874 lines) with hidden dependencies via service locator pattern.

## Problem

### Database Layer (`lib/database`)
- **JournalDb** is 1,396 lines with 100+ methods mixing CRUD, conflicts, tags, tasks, calendars, and config
- Hidden `getIt<>` calls throughout make dependencies unclear and testing difficult
- No interfaces/contracts - tight coupling to concrete implementations
- Complex queries with 9+ parameters (e.g., `getTasks`)

### Logic Layer (`lib/logic`)
- **PersistenceLogic** is 874 lines mixing metadata generation, persistence, sync queuing, notifications, and geolocation
- **image_import.dart** is 820 lines mixing EXIF parsing, file I/O, and entity creation
- **HealthImport** is 427 lines mixing queuing, permissions, device detection, fetching, and persistence
- 23+ `getIt<>` calls creating hidden dependencies
- Race condition handling in geolocation needs isolation

## Solution

Split monolithic classes into focused, single-responsibility components with explicit dependencies. Introduce interfaces where beneficial for testing. Extract reusable utilities into dedicated modules.

## Design Decisions

- **Incremental refactoring**: Each phase is self-contained and leaves codebase working
- **Interface-first for high-mock components**: Interfaces only where testing benefit is clear
- **Constructor injection**: Replace `getIt<>` calls inside methods with constructor parameters
- **Preserve existing tests**: Refactoring should not break existing test coverage
- **No behavioral changes**: Pure refactoring - functionality remains identical

---

## Phase 1: Extract Metadata Service from PersistenceLogic ✅ COMPLETED

**Status**: Completed on 2026-01-21

**Goal**: Extract pure metadata generation into a focused, easily testable service.

**Scope**: ~80 lines, pure functions, no side effects

### Files to Create

**`/lib/logic/services/metadata_service.dart`**
```dart
class MetadataService {
  MetadataService({
    required VectorClockService vectorClockService,
  });

  final VectorClockService _vectorClockService;

  /// Generate metadata for a new journal entry
  Future<Metadata> createMetadata({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    List<String>? tagIds,
    bool? starred,
    bool? private,
    int? flag,
    String? uuidV5Input,
  });

  /// Generate a new UUID (v4 or v5 if input provided)
  String generateId({String? uuidV5Input});

  /// Increment vector clock and return updated metadata
  Future<Metadata> updateMetadata(Metadata existing);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/logic/persistence_logic.dart` | Replace inline metadata creation with `_metadataService.createMetadata()` calls |
| `/lib/get_it.dart` | Register `MetadataService` singleton |

### Tests to Create

**`/test/logic/services/metadata_service_test.dart`**
- UUID v4 generation is unique
- UUID v5 generation is deterministic for same input
- Vector clock increments correctly
- Default values applied (starred=false, private=false, etc.)
- DateTo defaults to DateFrom when not specified

### Success Criteria
- [x] All existing tests pass
- [x] MetadataService has comprehensive test coverage (38 tests)
- [x] PersistenceLogic delegates metadata operations to MetadataService

---

## Phase 2: Extract Geolocation Service from PersistenceLogic

**Goal**: Isolate geolocation capture with its race condition handling into a dedicated service.

**Scope**: ~60 lines, async operations with concurrency control

### Files to Create

**`/lib/logic/services/geolocation_service.dart`**
```dart
class GeolocationService {
  GeolocationService({
    required JournalDb journalDb,
    required LoggingService loggingService,
  });

  final Set<String> _pendingAdds = {};

  /// Add geolocation to entry (fire-and-forget, handles concurrency)
  void addGeolocation(String journalEntityId);

  /// Async implementation with race condition prevention
  Future<void> addGeolocationAsync(String journalEntityId);

  /// Check if geolocation add is pending for entry
  bool isPending(String journalEntityId);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/logic/persistence_logic.dart` | Delegate to `_geolocationService.addGeolocation()` |
| `/lib/get_it.dart` | Register `GeolocationService` singleton |

### Tests to Create

**`/test/logic/services/geolocation_service_test.dart`**
- Concurrent calls for same entry don't duplicate work
- Geolocation added to entry correctly
- Errors logged but don't throw
- Pending set cleared after completion

### Success Criteria
- [ ] All existing tests pass
- [ ] GeolocationService has 90%+ test coverage
- [ ] Race condition handling verified with concurrent test

---

## Phase 3: Extract EXIF Data Extractor from image_import

**Goal**: Extract GPS parsing and timestamp extraction utilities into a reusable module.

**Scope**: ~100 lines, pure functions, no side effects

### Files to Create

**`/lib/logic/media/exif_data_extractor.dart`**
```dart
class ExifDataExtractor {
  /// Extract GPS coordinates from EXIF data
  static Geolocation? extractGpsCoordinates(Map<String, IfdTag> exifData);

  /// Parse GPS coordinate from EXIF tag value
  static double? parseGpsCoordinate(dynamic value);

  /// Parse rational number from EXIF
  static double? parseRational(dynamic value);

  /// Extract timestamp from EXIF data
  static DateTime? extractTimestamp(Map<String, IfdTag> exifData);

  /// Parse EXIF date string (YYYY:MM:DD HH:MM:SS)
  static DateTime? parseExifDateString(String? dateString);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/logic/image_import.dart` | Replace inline functions with `ExifDataExtractor.method()` calls |

### Tests to Create

**`/test/logic/media/exif_data_extractor_test.dart`**
- Valid GPS coordinates parsed correctly
- Malformed GPS data returns null (no crash)
- Missing GPS fields handled gracefully
- Valid timestamps parsed correctly
- Invalid date formats return null
- Edge cases: zero coordinates, negative values, rational edge cases

### Success Criteria
- [ ] All existing tests pass
- [ ] ExifDataExtractor has 100% test coverage
- [ ] image_import.dart reduced by ~100 lines

---

## Phase 4: Extract Audio Metadata Extractor from image_import

**Goal**: Extract audio duration and timestamp extraction into a dedicated module.

**Scope**: ~80 lines, async operations with timeout handling

### Files to Create

**`/lib/logic/media/audio_metadata_extractor.dart`**
```dart
class AudioMetadataExtractor {
  /// Extract duration from audio file using MediaKit
  static Future<Duration> extractDuration(String filePath, {
    Duration timeout = const Duration(seconds: 5),
  });

  /// Parse timestamp from audio filename patterns
  static DateTime? parseFilenameTimestamp(String filename);

  /// Supported audio file extensions
  static const List<String> supportedExtensions = ['m4a', 'aac', 'mp3', 'wav', 'ogg'];

  /// Check if file is a supported audio format
  static bool isSupported(String filePath);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/logic/image_import.dart` | Replace inline functions with `AudioMetadataExtractor.method()` calls |

### Tests to Create

**`/test/logic/media/audio_metadata_extractor_test.dart`**
- Filename timestamp patterns parsed correctly
- Unknown filename formats return null
- Extension checking works for all supported formats
- Duration extraction timeout handled (returns Duration.zero)

### Success Criteria
- [ ] All existing tests pass
- [ ] AudioMetadataExtractor has 90%+ test coverage
- [ ] image_import.dart reduced by ~80 lines

---

## Phase 5: Split JournalDb - Extract ConflictRepository

**Goal**: Extract conflict detection and resolution into a focused repository.

**Scope**: ~150 lines, database operations

### Files to Create

**`/lib/database/repositories/conflict_repository.dart`**
```dart
class ConflictRepository {
  ConflictRepository({required JournalDb db});

  final JournalDb _db;

  /// Detect if incoming entity conflicts with existing
  Future<bool> detectConflict({
    required String id,
    required VectorClock incoming,
    required VectorClock existing,
  });

  /// Add conflict record
  Future<void> addConflict(Conflict conflict);

  /// Get all unresolved conflicts
  Future<List<Conflict>> getUnresolvedConflicts();

  /// Watch unresolved conflict count
  Stream<int> watchConflictCount();

  /// Resolve conflict with chosen version
  Future<void> resolveConflict({
    required String conflictId,
    required String chosenId,
  });

  /// Delete conflict record
  Future<void> deleteConflict(String id);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/database/database.dart` | Mark conflict methods as `@Deprecated`, delegate to repository |
| `/lib/get_it.dart` | Register `ConflictRepository` |
| Callers of conflict methods | Update to use `ConflictRepository` |

### Tests to Create

**`/test/database/repositories/conflict_repository_test.dart`**
- Conflict detected for concurrent edits
- No conflict for sequential edits
- Conflict resolution updates correct records
- Watch stream emits on changes

### Success Criteria
- [ ] All existing tests pass
- [ ] ConflictRepository has 90%+ test coverage
- [ ] Conflict logic isolated from main JournalDb

---

## Phase 6: Split JournalDb - Extract EntityDefinitionRepository

**Goal**: Extract tag, label, category, and habit definition operations.

**Scope**: ~200 lines, database operations

### Files to Create

**`/lib/database/repositories/entity_definition_repository.dart`**
```dart
class EntityDefinitionRepository {
  EntityDefinitionRepository({required JournalDb db});

  // Tag operations
  Future<void> upsertTagDefinition(TagEntity tag);
  Future<List<TagEntity>> getAllTags();
  Future<TagEntity?> getTagById(String id);
  Stream<List<TagEntity>> watchTags();

  // Label operations
  Future<void> upsertLabelDefinition(LabelDefinition label);
  Future<List<LabelDefinition>> getLabelsForCategory(String categoryId);
  Stream<List<LabelDefinition>> watchLabels();

  // Category operations
  Future<void> upsertCategoryDefinition(CategoryDefinition category);
  Future<List<CategoryDefinition>> getAllCategories();
  Stream<List<CategoryDefinition>> watchCategories();

  // Habit operations
  Future<void> upsertHabitDefinition(HabitDefinition habit);
  Future<List<HabitDefinition>> getActiveHabits();
  Stream<List<HabitDefinition>> watchHabits();

  // Dashboard operations
  Future<void> upsertDashboardDefinition(DashboardDefinition dashboard);
  Future<List<DashboardDefinition>> getAllDashboards();
  Stream<List<DashboardDefinition>> watchDashboards();
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/database/database.dart` | Mark definition methods as `@Deprecated`, delegate |
| `/lib/get_it.dart` | Register `EntityDefinitionRepository` |
| Callers | Update to use repository |

### Tests to Create

**`/test/database/repositories/entity_definition_repository_test.dart`**
- CRUD operations for each entity type
- Watch streams emit on changes
- Category-filtered label queries work correctly

### Success Criteria
- [ ] All existing tests pass
- [ ] EntityDefinitionRepository has 90%+ test coverage
- [ ] Definition logic isolated from main JournalDb

---

## Phase 7: Split JournalDb - Extract TaskRepository

**Goal**: Extract task-specific queries and filtering into a focused repository.

**Scope**: ~150 lines, complex query logic

### Files to Create

**`/lib/database/repositories/task_repository.dart`**
```dart
class TaskRepository {
  TaskRepository({required JournalDb db});

  /// Get tasks with filters
  Future<List<JournalEntity>> getTasks({
    List<bool>? starredStatuses,
    List<String>? taskStatuses,
    List<String>? categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    bool sortByDate = false,
    int limit = 500,
    int offset = 0,
  });

  /// Get tasks due on or before date
  Future<List<JournalEntity>> getTasksDueBefore(DateTime date);

  /// Get tasks by status
  Future<List<JournalEntity>> getTasksByStatus(String status);

  /// Update task status
  Future<void> updateTaskStatus(String id, String status);

  /// Update task priority
  Future<void> updateTaskPriority(String id, String priority);
}
```

**`/lib/database/repositories/task_query_builder.dart`** (optional, for complex queries)
```dart
class TaskQueryBuilder {
  TaskQueryBuilder(this._db);

  TaskQueryBuilder withStatuses(List<String> statuses);
  TaskQueryBuilder withPriorities(List<String> priorities);
  TaskQueryBuilder withLabels(List<String> labelIds);
  TaskQueryBuilder withCategories(List<String> categoryIds);
  TaskQueryBuilder starred(bool starred);
  TaskQueryBuilder limit(int limit);
  TaskQueryBuilder offset(int offset);
  TaskQueryBuilder sortByDate();
  TaskQueryBuilder sortByPriority();

  Future<List<JournalEntity>> execute();
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/database/database.dart` | Mark task methods as `@Deprecated`, delegate |
| `/lib/get_it.dart` | Register `TaskRepository` |
| Task-related UI/logic | Update to use repository |

### Tests to Create

**`/test/database/repositories/task_repository_test.dart`**
- Filter combinations work correctly
- Empty filter lists handled (no crash)
- Pagination works
- Sort orders applied correctly

### Success Criteria
- [ ] All existing tests pass
- [ ] TaskRepository has 90%+ test coverage
- [ ] Complex query logic isolated and testable

---

## Phase 8: Introduce Repository Interfaces

**Goal**: Define interfaces for key repositories to enable test doubles.

**Scope**: Interface definitions only, no implementation changes

### Files to Create

**`/lib/database/interfaces/i_entry_repository.dart`**
```dart
abstract class IEntryRepository {
  Future<JournalEntity?> getById(String id);
  Future<int> upsert(JournalEntity entity);
  Future<void> delete(String id);
  Stream<JournalEntity?> watchById(String id);
}
```

**`/lib/database/interfaces/i_conflict_repository.dart`**
```dart
abstract class IConflictRepository {
  Future<bool> detectConflict({...});
  Future<void> addConflict(Conflict conflict);
  Future<List<Conflict>> getUnresolvedConflicts();
  Future<void> resolveConflict({...});
}
```

**`/lib/database/interfaces/i_task_repository.dart`**
```dart
abstract class ITaskRepository {
  Future<List<JournalEntity>> getTasks({...});
  Future<void> updateTaskStatus(String id, String status);
  Future<void> updateTaskPriority(String id, String priority);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| Concrete repositories | Implement corresponding interfaces |
| `/lib/get_it.dart` | Register with interface type |

### Tests to Create

**`/test/database/mocks/mock_repositories.dart`**
- Mock implementations for each interface
- Can be used in unit tests without database

### Success Criteria
- [ ] Interfaces defined for top 3 repositories
- [ ] Existing tests continue to pass
- [ ] New tests can use mock implementations

---

## Phase 9: Extract SyncQueueService from PersistenceLogic

**Goal**: Isolate sync message queuing into a dedicated service.

**Scope**: ~50 lines, async operations

### Files to Create

**`/lib/logic/services/sync_queue_service.dart`**
```dart
class SyncQueueService {
  SyncQueueService({
    required OutboxService outboxService,
    required LoggingService loggingService,
  });

  /// Queue entity for sync
  Future<void> queueEntitySync(JournalEntity entity);

  /// Queue definition for sync
  Future<void> queueDefinitionSync(dynamic definition);

  /// Queue deletion for sync
  Future<void> queueDeletion(String entityId);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/logic/persistence_logic.dart` | Delegate sync queuing to `SyncQueueService` |
| `/lib/get_it.dart` | Register `SyncQueueService` |

### Tests to Create

**`/test/logic/services/sync_queue_service_test.dart`**
- Entity queued with correct message type
- Definition queued with correct message type
- Deletion queued correctly

### Success Criteria
- [ ] All existing tests pass
- [ ] SyncQueueService has 90%+ test coverage
- [ ] Sync logic isolated from persistence logic

---

## Phase 10: Migrate getIt Calls to Constructor Injection

**Goal**: Replace hidden `getIt<>` calls inside methods with constructor parameters.

**Scope**: Systematic update across multiple files

### High-Priority Files

| File | Current getIt calls | Target |
|------|---------------------|--------|
| `/lib/logic/persistence_logic.dart` | 5 | 0 (all via constructor) |
| `/lib/logic/image_import.dart` | 8 | 0 (parameters or constructor) |
| `/lib/database/fts5_db.dart` | 2 | 0 (constructor injection) |
| `/lib/database/maintenance.dart` | 6 | 0 (constructor injection) |

### Pattern to Apply

**Before:**
```dart
class SomeService {
  void doWork() {
    final db = getIt<JournalDb>();  // Hidden dependency
    db.save(entity);
  }
}
```

**After:**
```dart
class SomeService {
  SomeService({required JournalDb journalDb}) : _journalDb = journalDb;

  final JournalDb _journalDb;

  void doWork() {
    _journalDb.save(entity);  // Explicit dependency
  }
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/logic/persistence_logic.dart` | Add constructor params, remove internal getIt calls |
| `/lib/logic/image_import.dart` | Convert free functions to class or add explicit params |
| `/lib/database/fts5_db.dart` | Add TagsService to constructor |
| `/lib/database/maintenance.dart` | Add all DB dependencies to constructor |
| `/lib/get_it.dart` | Update registrations to pass dependencies |

### Tests to Update

- Update test setup to pass mock dependencies
- Remove test-specific getIt overrides where possible

### Success Criteria
- [ ] All `getIt<>` calls moved to constructors or top-level registration
- [ ] No hidden dependencies in method bodies
- [ ] Tests updated to use constructor injection

---

## Phase 11: HealthImport Decomposition

**Goal**: Split HealthImport into focused components.

**Scope**: ~427 lines split into 3 components

### Files to Create

**`/lib/logic/health/health_import_queue.dart`**
```dart
class HealthImportQueue {
  final Queue<String> _queue = Queue();
  bool _isProcessing = false;

  void enqueue(String dataType);
  Future<void> processQueue(Future<void> Function(String) processor);
  bool get isEmpty;
  int get length;
}
```

**`/lib/logic/health/health_data_fetcher.dart`**
```dart
class HealthDataFetcher {
  HealthDataFetcher({
    required HealthService healthService,
    required LoggingService loggingService,
  });

  Future<List<HealthDataPoint>> fetchHealthData(
    HealthDataType type,
    DateTime from,
    DateTime to,
  );

  Future<List<WorkoutData>> fetchWorkouts(DateTime from, DateTime to);
}
```

**`/lib/logic/health/health_data_persister.dart`**
```dart
class HealthDataPersister {
  HealthDataPersister({
    required PersistenceLogic persistenceLogic,
    required JournalDb journalDb,
  });

  Future<void> persistHealthData(List<HealthDataPoint> data);
  Future<void> persistWorkout(WorkoutData workout);
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/logic/health_import.dart` | Compose from new components |
| `/lib/get_it.dart` | Register new components |

### Tests to Create

**`/test/logic/health/health_import_queue_test.dart`**
- Queue ordering maintained
- Concurrent processing prevented
- Empty queue handled

**`/test/logic/health/health_data_fetcher_test.dart`**
- Data types fetched correctly
- Errors handled gracefully

**`/test/logic/health/health_data_persister_test.dart`**
- Data persisted correctly
- Duplicates handled

### Success Criteria
- [ ] All existing tests pass
- [ ] Each component has 90%+ test coverage
- [ ] HealthImport now composes from focused components

---

## Phase 12: Final JournalDb Cleanup

**Goal**: Remove deprecated methods, finalize repository structure.

**Scope**: Cleanup and documentation

### Tasks

1. Remove `@Deprecated` annotations after all callers updated
2. Delete deprecated method implementations from JournalDb
3. Verify JournalDb is under 500 lines
4. Add documentation for repository structure
5. Update any remaining direct JournalDb usage to use repositories

### Files to Modify

| File | Changes |
|------|---------|
| `/lib/database/database.dart` | Remove deprecated methods |
| `/lib/database/README.md` | Create with architecture documentation |

### Final Structure

```
lib/database/
├── database.dart              (~500 lines, core entry CRUD only)
├── sync_db.dart
├── settings_db.dart
├── logging_db.dart
├── editor_db.dart
├── fts5_db.dart
├── interfaces/
│   ├── i_entry_repository.dart
│   ├── i_conflict_repository.dart
│   └── i_task_repository.dart
├── repositories/
│   ├── conflict_repository.dart
│   ├── entity_definition_repository.dart
│   └── task_repository.dart
└── README.md
```

### Success Criteria
- [ ] JournalDb under 500 lines
- [ ] All repositories have clear responsibilities
- [ ] README documents architecture
- [ ] All tests pass

---

## Testing Strategy Summary

| Phase | New Test Files | Coverage Target |
|-------|---------------|-----------------|
| 1 | metadata_service_test.dart | 100% |
| 2 | geolocation_service_test.dart | 90% |
| 3 | exif_data_extractor_test.dart | 100% |
| 4 | audio_metadata_extractor_test.dart | 90% |
| 5 | conflict_repository_test.dart | 90% |
| 6 | entity_definition_repository_test.dart | 90% |
| 7 | task_repository_test.dart | 90% |
| 8 | mock_repositories.dart | N/A (test helpers) |
| 9 | sync_queue_service_test.dart | 90% |
| 10 | (update existing tests) | Maintain |
| 11 | health_import_*.dart | 90% each |
| 12 | (integration verification) | Maintain |

---

## Dependency Graph (Post-Refactor)

```
UI Layer
    ↓
EntryCreationService
    ↓
┌─────────────────────────────────────────┐
│ Logic Services                          │
│ ├── MetadataService                     │
│ ├── GeolocationService                  │
│ ├── SyncQueueService                    │
│ └── PersistenceLogic (orchestrator)     │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Repositories                            │
│ ├── ConflictRepository                  │
│ ├── EntityDefinitionRepository          │
│ └── TaskRepository                      │
└─────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────┐
│ Database Layer                          │
│ ├── JournalDb (core CRUD only)          │
│ ├── SyncDb                              │
│ └── Other DBs                           │
└─────────────────────────────────────────┘
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking existing functionality | Run full test suite after each phase |
| Circular dependencies | Follow dependency graph strictly |
| Performance regression | Profile before/after Phase 12 |
| Incomplete migration | Track callers before deprecating methods |

---

## Files Summary

### New Files (18)

| Path | Phase |
|------|-------|
| `/lib/logic/services/metadata_service.dart` | 1 |
| `/lib/logic/services/geolocation_service.dart` | 2 |
| `/lib/logic/media/exif_data_extractor.dart` | 3 |
| `/lib/logic/media/audio_metadata_extractor.dart` | 4 |
| `/lib/database/repositories/conflict_repository.dart` | 5 |
| `/lib/database/repositories/entity_definition_repository.dart` | 6 |
| `/lib/database/repositories/task_repository.dart` | 7 |
| `/lib/database/repositories/task_query_builder.dart` | 7 |
| `/lib/database/interfaces/i_entry_repository.dart` | 8 |
| `/lib/database/interfaces/i_conflict_repository.dart` | 8 |
| `/lib/database/interfaces/i_task_repository.dart` | 8 |
| `/lib/logic/services/sync_queue_service.dart` | 9 |
| `/lib/logic/health/health_import_queue.dart` | 11 |
| `/lib/logic/health/health_data_fetcher.dart` | 11 |
| `/lib/logic/health/health_data_persister.dart` | 11 |
| `/lib/database/README.md` | 12 |
| `/test/database/mocks/mock_repositories.dart` | 8 |
| Various test files | All phases |

### Modified Files (Major)

| Path | Phases |
|------|--------|
| `/lib/database/database.dart` | 5, 6, 7, 12 |
| `/lib/logic/persistence_logic.dart` | 1, 2, 9, 10 |
| `/lib/logic/image_import.dart` | 3, 4, 10 |
| `/lib/logic/health_import.dart` | 11 |
| `/lib/get_it.dart` | All phases |
