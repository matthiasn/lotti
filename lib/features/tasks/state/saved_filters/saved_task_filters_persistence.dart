import 'dart:convert';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/services/dev_logger.dart';

/// Persists the ordered list of [SavedTaskFilter]s as a single JSON blob in
/// [SettingsDb].
///
/// The list is small (typical user has a handful of saved filters) so a
/// single-blob approach mirrors `JournalFilterPersistence` and keeps reorder
/// trivial: position in the list is the sort order.
class SavedTaskFiltersPersistence {
  SavedTaskFiltersPersistence(this._settingsDb);

  /// Storage key under which the JSON list of saved filters is persisted.
  static const storageKey = 'SAVED_TASK_FILTERS';

  final SettingsDb _settingsDb;

  // Dedup state — avoids redundant DB writes when the encoded value is
  // unchanged. Mirrors the pattern in JournalFilterPersistence.
  String? _persistedValue;
  bool _hasLoaded = false;

  /// Loads the persisted list. Returns an empty list when nothing is stored
  /// or the stored payload cannot be decoded.
  Future<List<SavedTaskFilter>> load() async {
    final raw = await _settingsDb.itemByKey(storageKey);
    if (raw == null) {
      _persistedValue = null;
      _hasLoaded = true;
      return const <SavedTaskFilter>[];
    }

    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => SavedTaskFilter.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      _persistedValue = _encode(list);
      _hasLoaded = true;
      return list;
    } catch (e) {
      _persistedValue = raw;
      _hasLoaded = true;
      DevLogger.warning(
        name: 'SavedTaskFiltersPersistence',
        message: 'Error decoding saved task filters: $e',
      );
      return const <SavedTaskFilter>[];
    }
  }

  /// Persists [filters] (preserving order). Skips the DB write when the
  /// encoded value matches the last-persisted value.
  Future<void> save(List<SavedTaskFilter> filters) async {
    final encoded = _encode(filters);

    if (!_hasLoaded) {
      _persistedValue = _normalize(await _settingsDb.itemByKey(storageKey));
      _hasLoaded = true;
    }

    if (_persistedValue == encoded) return;

    await _settingsDb.saveSettingsItem(storageKey, encoded);
    _persistedValue = encoded;
  }

  String _encode(List<SavedTaskFilter> filters) {
    return jsonEncode(filters.map((f) => f.toJson()).toList(growable: false));
  }

  String? _normalize(String? value) {
    if (value == null) return null;
    try {
      final list = (jsonDecode(value) as List<dynamic>)
          .map((e) => SavedTaskFilter.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      return _encode(list);
    } catch (_) {
      return value;
    }
  }
}
