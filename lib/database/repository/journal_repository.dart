import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';

/// Repository interface for journal operations
abstract class IJournalRepository {
  // Query operations
  Future<JournalEntity?> getById(String id);
  Stream<JournalEntity?> watchById(String id);
  Future<List<JournalEntity>> getByIds(Set<String> ids);
  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom);

  // Create/Update operations
  Future<int> upsert(JournalEntity entity, {bool overwrite = true});
  Future<int> updateWithConflictDetection(
    JournalEntity entity, {
    bool overrideComparison = false,
    bool overwrite = true,
  });

  // Query with filters
  Future<List<JournalEntity>> query({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    List<String>? ids,
    Set<String>? categoryIds,
    int limit = 500,
    int offset = 0,
  });

  // Task specific queries
  Future<List<JournalEntity>> getTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  });

  // Date range queries
  Future<List<JournalEntity>> getInDateRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? type,
    String? subtype,
  });

  // Count operations
  Future<int> count();
  Future<int> getTasksCount({List<String> statuses = const ['IN PROGRESS']});
  Future<int> getWipCount();
}

/// Concrete implementation of journal repository
class JournalRepository implements IJournalRepository {
  JournalRepository(this._db);

  final JournalDb _db;

  @override
  Future<JournalEntity?> getById(String id) => _db.journalEntityById(id);

  @override
  Stream<JournalEntity?> watchById(String id) => _db.watchJournalEntityById(id);

  @override
  Future<List<JournalEntity>> getByIds(Set<String> ids) =>
      _db.getJournalEntitiesForIds(ids);

  @override
  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) =>
      _db.getLinkedEntities(linkedFrom);

  @override
  Future<int> upsert(JournalEntity entity, {bool overwrite = true}) =>
      _db.updateJournalEntity(entity, overwrite: overwrite);

  @override
  Future<int> updateWithConflictDetection(
    JournalEntity entity, {
    bool overrideComparison = false,
    bool overwrite = true,
  }) =>
      _db.updateJournalEntity(
        entity,
        overrideComparison: overrideComparison,
        overwrite: overwrite,
      );

  @override
  Future<List<JournalEntity>> query({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    List<String>? ids,
    Set<String>? categoryIds,
    int limit = 500,
    int offset = 0,
  }) =>
      _db.getJournalEntities(
        types: types,
        starredStatuses: starredStatuses,
        privateStatuses: privateStatuses,
        flaggedStatuses: flaggedStatuses,
        ids: ids,
        categoryIds: categoryIds,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<JournalEntity>> getTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) =>
      _db.getTasks(
        starredStatuses: starredStatuses,
        taskStatuses: taskStatuses,
        categoryIds: categoryIds,
        ids: ids,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<JournalEntity>> getInDateRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? type,
    String? subtype,
  }) async {
    if (type == 'Measurement' && subtype != null) {
      return _db.getMeasurementsByType(
        type: subtype,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }
    if (type == 'HabitCompletion' && subtype != null) {
      return _db.getHabitCompletionsByHabitId(
        habitId: subtype,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }
    if (type == 'Survey' && subtype != null) {
      return _db.getSurveyCompletionsByType(
        type: subtype,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }
    if (type == 'Workout') {
      return _db.getWorkouts(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }
    if (type == 'Quantitative' && subtype != null) {
      return _db.getQuantitativeByType(
        type: subtype,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }
    return _db.sortedTextEntries(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Future<int> count() => _db.getJournalCount();

  @override
  Future<int> getTasksCount({List<String> statuses = const ['IN PROGRESS']}) =>
      _db.getTasksCount(statuses: statuses);

  @override
  Future<int> getWipCount() => _db.getWipCount();
}
