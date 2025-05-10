import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:flutter/foundation.dart';

/// Repository that provides access to journal entries and tasks
class JournalRepository {
  JournalRepository({
    required JournalDb db,
    required Fts5Db fts5Db,
    required UpdateNotifications updateNotifications,
    required EntitiesCacheService entitiesCacheService,
  })  : _db = db,
        _fts5Db = fts5Db,
        _updateNotifications = updateNotifications,
        _entitiesCacheService = entitiesCacheService;

  final JournalDb _db;
  final Fts5Db _fts5Db;
  final UpdateNotifications _updateNotifications;
  final EntitiesCacheService _entitiesCacheService;

  static const int pageSize = 50;

  /// Get journal entries with pagination
  Future<List<JournalEntity>> getJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    List<String>? ids,
    List<String>? categoryIds,
    required int offset,
  }) async {
    debugPrint('Repository: getJournalEntities with offset $offset');
    final start = DateTime.now();

    final result = await _db.getJournalEntities(
      types: types,
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      flaggedStatuses: flaggedStatuses,
      ids: ids,
      categoryIds: categoryIds != null ? categoryIds.toSet() : null,
      limit: pageSize,
      offset: offset,
    );

    final duration = DateTime.now().difference(start).inMilliseconds;
    debugPrint(
        'Repository: got ${result.length} journal entries in $duration ms');

    return result;
  }

  /// Get tasks with pagination
  Future<List<JournalEntity>> getTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? ids,
    required int offset,
  }) async {
    debugPrint('Repository: getTasks with offset $offset');
    final start = DateTime.now();

    final result = await _db.getTasks(
      starredStatuses: starredStatuses,
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
      ids: ids,
      limit: pageSize,
      offset: offset,
    );

    final duration = DateTime.now().difference(start).inMilliseconds;
    debugPrint('Repository: got ${result.length} tasks in $duration ms');

    return result;
  }

  /// Search for journal entries using full-text search
  Future<Set<String>> fullTextSearch(String query) async {
    if (query.isEmpty) {
      return {};
    }
    final res = await _fts5Db.watchFullTextMatches(query).first;
    return res.toSet();
  }

  /// Get a journal entity by ID
  Future<JournalEntity?> getJournalEntityById(String id) async {
    return _db.journalEntityById(id);
  }

  /// Watch for changes to a config flag
  Stream<bool> watchConfigFlag(String flag) {
    return _db.watchConfigFlag(flag);
  }

  /// Stream of update notifications for journal entries
  Stream<Set<String>> get updateStream => _updateNotifications.updateStream;

  /// Get all category IDs
  Set<String> getAllCategoryIds() {
    return _entitiesCacheService.sortedCategories.map((e) => e.id).toSet();
  }

  /// Get journal entry count
  Future<int> getJournalCount() async {
    return _db.getJournalCount();
  }

  /// Get task count
  Future<int> getTasksCount() async {
    return _db.getTasksCount();
  }
}
