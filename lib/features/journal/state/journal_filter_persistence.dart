import 'dart:convert';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
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

  /// Key recording every entry type the persisted selection has been
  /// reconciled against — the types the filter offered when the selection
  /// was last loaded or saved.
  ///
  /// A type the filter gains later is one the user never had the chance to
  /// deselect, so it joins the selection once, on the next load; from then
  /// on it is part of this set, and deselecting it sticks.
  static const reconciledEntryTypesKey = 'ENTRY_TYPES_RECONCILED';

  /// What a selection saved before [reconciledEntryTypesKey] existed was
  /// reconciled against: the filter's types up to, not including, `CheckIn`.
  static const legacyReconciledEntryTypes = {
    'Task',
    'JournalEntry',
    'JournalEvent',
    'JournalAudio',
    'JournalImage',
    'MeasurementEntry',
    'SurveyEntry',
    'WorkoutEntry',
    'HabitCompletionEntry',
    'QuantitativeEntry',
    'Checklist',
    'ChecklistItem',
    'AiResponse',
  };

  // Dedup state — avoids redundant DB writes, keyed per persistence key.
  final Map<String, String?> _persistedFiltersByKey = {};
  final Set<String> _loadedFilterKeys = {};
  String? _persistedEntryTypesValue;
  bool _hasLoadedEntryTypesValue = false;
  bool _reconciledEntryTypesCurrent = false;

  // ---------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------

  /// Loads and decodes persisted [TasksFilter] from [key].
  /// Returns `null` when nothing was stored.
  Future<TasksFilter?> loadFilters(String key) async {
    final raw = await _settingsDb.itemByKey(key);
    if (raw == null) {
      _persistedFiltersByKey[key] = null;
      _loadedFilterKeys.add(key);
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final filter = TasksFilter.fromJson(json);
      _persistedFiltersByKey[key] = _encodeTasksFilter(filter);
      _loadedFilterKeys.add(key);
      return filter;
    } catch (e) {
      _persistedFiltersByKey[key] = raw;
      _loadedFilterKeys.add(key);
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
    if (raw == null) {
      _persistedEntryTypesValue = null;
      _hasLoadedEntryTypesValue = true;
      return null;
    }

    try {
      final json = jsonDecode(raw) as List<dynamic>;
      final stored = List<String>.from(json).toSet();
      _persistedEntryTypesValue = _encodeEntryTypes(stored);
      _hasLoadedEntryTypesValue = true;
      final added = entryTypes.toSet().difference(
        await _loadReconciledEntryTypes(),
      );
      final types = stored.union(added);
      if (added.isNotEmpty) await saveEntryTypes(types);
      await _markEntryTypesReconciled();
      return types;
    } catch (e) {
      _persistedEntryTypesValue = raw;
      _hasLoadedEntryTypesValue = true;
      DevLogger.warning(
        name: 'JournalFilterPersistence',
        message: 'Error loading persisted entry types: $e',
      );
      return null;
    }
  }

  // ---------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------

  /// Persists [filter] under [key], skipping the write when unchanged.
  Future<void> saveFilters(TasksFilter filter, String key) async {
    final encoded = _encodeTasksFilter(filter);

    if (!_loadedFilterKeys.contains(key)) {
      _persistedFiltersByKey[key] = _normalizeTasksFilterValue(
        await _settingsDb.itemByKey(key),
      );
      _loadedFilterKeys.add(key);
    }

    if (_persistedFiltersByKey[key] != encoded) {
      await _settingsDb.saveSettingsItem(key, encoded);
      _persistedFiltersByKey[key] = encoded;
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
    if (_persistedEntryTypesValue != encoded) {
      await _settingsDb.saveSettingsItem(selectedEntryTypesKey, encoded);
      _persistedEntryTypesValue = encoded;
    }
    // A selection saved now was made with every current type on offer.
    await _markEntryTypesReconciled();
  }

  Future<Set<String>> _loadReconciledEntryTypes() async {
    final raw = await _settingsDb.itemByKey(reconciledEntryTypesKey);
    Set<String> reconciled;
    try {
      reconciled = raw == null
          ? legacyReconciledEntryTypes
          : List<String>.from(jsonDecode(raw) as List<dynamic>).toSet();
    } catch (_) {
      reconciled = legacyReconciledEntryTypes;
    }
    // Already current: an unchanged launch writes nothing.
    _reconciledEntryTypesCurrent =
        raw != null && reconciled.containsAll(entryTypes);
    return reconciled;
  }

  Future<void> _markEntryTypesReconciled() async {
    if (_reconciledEntryTypesCurrent) return;
    await _settingsDb.saveSettingsItem(
      reconciledEntryTypesKey,
      _encodeEntryTypes(entryTypes.toSet()),
    );
    _reconciledEntryTypesCurrent = true;
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
      'showProjectsHeader': filter.showProjectsHeader,
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
