import 'dart:convert';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/services/dev_logger.dart';

/// Handles encoding, decoding, loading, and saving of journal/task filter
/// state to the settings database.
///
/// Owns the dedup optimisation: tracks the last-persisted value per key and
/// skips writes when nothing has changed.
class JournalFilterPersistence {
  JournalFilterPersistence(this._settingsDb);

  final SettingsDb _settingsDb;

  /// Key used for entry-type persistence.
  static const selectedEntryTypesKey = 'SELECTED_ENTRY_TYPES';

  // Dedup state — avoids redundant DB writes.
  String? _persistedPerTabTasksFilterValue;
  String? _persistedEntryTypesValue;
  bool _hasLoadedPerTabTasksFilterValue = false;
  bool _hasLoadedEntryTypesValue = false;

  // ---------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------

  /// Loads and decodes persisted [TasksFilter] from [key].
  /// Returns `null` when nothing was stored.
  Future<TasksFilter?> loadFilters(String key) async {
    final raw = await _settingsDb.itemByKey(key);
    _persistedPerTabTasksFilterValue = _normalizeTasksFilterValue(raw);
    _hasLoadedPerTabTasksFilterValue = true;

    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TasksFilter.fromJson(json);
    } catch (e) {
      DevLogger.warning(
        name: 'JournalFilterPersistence',
        message: 'Error loading persisted filters: $e',
      );
      return null;
    }
  }

  /// Loads persisted entry-type selection.
  /// Returns `null` when nothing was stored.
  Future<Set<String>?> loadEntryTypes() async {
    final raw = await _settingsDb.itemByKey(selectedEntryTypesKey);
    _persistedEntryTypesValue = _normalizeEntryTypesValue(raw);
    _hasLoadedEntryTypesValue = true;

    if (raw == null) return null;

    final json = jsonDecode(raw) as List<dynamic>;
    return List<String>.from(json).toSet();
  }

  // ---------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------

  /// Persists [filter] under [key], skipping the write when unchanged.
  Future<void> saveFilters(TasksFilter filter, String key) async {
    final encoded = _encodeTasksFilter(filter);

    if (!_hasLoadedPerTabTasksFilterValue) {
      _persistedPerTabTasksFilterValue = _normalizeTasksFilterValue(
        await _settingsDb.itemByKey(key),
      );
      _hasLoadedPerTabTasksFilterValue = true;
    }

    if (_persistedPerTabTasksFilterValue != encoded) {
      await _settingsDb.saveSettingsItem(key, encoded);
      _persistedPerTabTasksFilterValue = encoded;
    }
  }

  /// Persists [entryTypes], skipping the write when unchanged.
  Future<void> saveEntryTypes(Set<String> entryTypes) async {
    if (!_hasLoadedEntryTypesValue) {
      _persistedEntryTypesValue = _normalizeEntryTypesValue(
        await _settingsDb.itemByKey(selectedEntryTypesKey),
      );
      _hasLoadedEntryTypesValue = true;
    }

    final encoded = _encodeEntryTypes(entryTypes);
    if (_persistedEntryTypesValue == encoded) return;

    await _settingsDb.saveSettingsItem(selectedEntryTypesKey, encoded);
    _persistedEntryTypesValue = encoded;
  }

  // ---------------------------------------------------------------
  // Encoding / decoding helpers
  // ---------------------------------------------------------------

  String _encodeTasksFilter(TasksFilter filter) {
    return jsonEncode(<String, dynamic>{
      'selectedCategoryIds': _sortedStrings(filter.selectedCategoryIds),
      'selectedProjectIds': _sortedStrings(filter.selectedProjectIds),
      'selectedTaskStatuses': _sortedStrings(filter.selectedTaskStatuses),
      'selectedLabelIds': _sortedStrings(filter.selectedLabelIds),
      'selectedPriorities': _sortedStrings(filter.selectedPriorities),
      'sortOption': filter.sortOption.name,
      'showCreationDate': filter.showCreationDate,
      'showDueDate': filter.showDueDate,
      'showCoverArt': filter.showCoverArt,
      'showDistances': filter.showDistances,
      'agentAssignmentFilter': filter.agentAssignmentFilter.name,
    });
  }

  String _encodeEntryTypes(Set<String> entryTypes) {
    return jsonEncode(_sortedStrings(entryTypes));
  }

  String? _normalizeTasksFilterValue(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return _encodeTasksFilter(TasksFilter.fromJson(json));
    } catch (_) {
      return value;
    }
  }

  String? _normalizeEntryTypesValue(String? value) {
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as List<dynamic>;
      return _encodeEntryTypes(List<String>.from(json).toSet());
    } catch (_) {
      return value;
    }
  }

  List<String> _sortedStrings(Iterable<String> values) {
    final sorted = values.toList()..sort();
    return sorted;
  }
}
