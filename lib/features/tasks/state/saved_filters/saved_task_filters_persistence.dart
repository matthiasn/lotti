import 'dart:convert';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/services/dev_logger.dart';

/// Persists the ordered list of [SavedTaskFilter]s as a single JSON blob in
/// [SettingsDb], next to the [SavedTaskFilterSyncLedger] that records what
/// this device still owes its peers.
///
/// The list is small (typical user has a handful of saved filters) so a
/// single-blob approach mirrors `JournalFilterPersistence` and keeps reorder
/// trivial: position in the list is the sort order.
class SavedTaskFiltersPersistence {
  SavedTaskFiltersPersistence(this._settingsDb);

  /// Storage key under which the JSON list of saved filters is persisted.
  static const storageKey = 'SAVED_TASK_FILTERS';

  /// Storage key of the [SavedTaskFilterSyncLedger].
  static const ledgerKey = 'SAVED_TASK_FILTERS_SYNC_LEDGER';

  final SettingsDb _settingsDb;

  // Dedup state — avoids redundant DB writes when the encoded value is
  // unchanged. Mirrors the pattern in JournalFilterPersistence.
  String? _persistedValue;
  bool _hasLoaded = false;

  /// Loads the persisted list. Returns an empty list when nothing is stored
  /// or the stored payload is not a JSON list.
  ///
  /// Decodes item by item: an entry that cannot be decoded is logged and
  /// left out rather than discarding the whole list, which the next save
  /// would otherwise persist as empty.
  Future<List<SavedTaskFilter>> load() async {
    final raw = await _settingsDb.itemByKey(storageKey);
    _hasLoaded = true;
    if (raw == null) {
      _persistedValue = null;
      return const <SavedTaskFilter>[];
    }

    final List<dynamic> items;
    try {
      items = jsonDecode(raw) as List<dynamic>;
    } catch (e) {
      _persistedValue = raw;
      _warn('Error decoding saved task filters: $e');
      return const <SavedTaskFilter>[];
    }

    final list = <SavedTaskFilter>[];
    for (final item in items) {
      try {
        list.add(SavedTaskFilter.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        _warn('Skipping undecodable saved task filter: $e');
      }
    }
    _persistedValue = _encode(list);
    return List.unmodifiable(list);
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

  /// Loads the sync ledger, or null when this device has never written one —
  /// a device that ran a build from before the ledger existed.
  Future<SavedTaskFilterSyncLedger?> loadLedger() async {
    final raw = await _settingsDb.itemByKey(ledgerKey);
    if (raw == null) return null;
    try {
      return SavedTaskFilterSyncLedger.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // An unreadable ledger is treated like a missing one: the caller then
      // owes every stored filter again, which only costs redundant sends.
      _warn('Error decoding saved task filter sync ledger: $e');
      return null;
    }
  }

  /// Persists [ledger].
  Future<void> saveLedger(SavedTaskFilterSyncLedger ledger) async {
    await _settingsDb.saveSettingsItem(ledgerKey, jsonEncode(ledger.toJson()));
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

  void _warn(String message) =>
      DevLogger.warning(name: 'SavedTaskFiltersPersistence', message: message);
}

/// What this device still owes its peers for its saved filters, and what it
/// knows was deleted.
///
/// [pending] holds the ids whose current state — the stored revision, or the
/// tombstone — has not reached the outbox yet. An id is added before its
/// write and removed only after the outbox accepted its row, so neither a
/// failed enqueue nor a crash between the write and the enqueue can leave a
/// change that is never sent.
///
/// [tombstones] maps a deleted id to its deletion stamp. A received revision
/// at or before that stamp is stale, whatever order the two arrive in.
class SavedTaskFilterSyncLedger {
  const SavedTaskFilterSyncLedger({
    this.pending = const <String>{},
    this.tombstones = const <String, DateTime>{},
  });

  factory SavedTaskFilterSyncLedger.fromJson(Map<String, dynamic> json) {
    final pending = json['pending'] as List<dynamic>? ?? const <dynamic>[];
    final tombstones =
        json['tombstones'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return SavedTaskFilterSyncLedger(
      pending: {for (final id in pending) id as String},
      tombstones: {
        for (final entry in tombstones.entries)
          entry.key: DateTime.parse(entry.value as String),
      },
    );
  }

  final Set<String> pending;
  final Map<String, DateTime> tombstones;

  SavedTaskFilterSyncLedger copyWith({
    Set<String>? pending,
    Map<String, DateTime>? tombstones,
  }) => SavedTaskFilterSyncLedger(
    pending: pending ?? this.pending,
    tombstones: tombstones ?? this.tombstones,
  );

  Map<String, dynamic> toJson() => {
    'pending': pending.toList()..sort(),
    'tombstones': {
      for (final entry in tombstones.entries)
        entry.key: entry.value.toUtc().toIso8601String(),
    },
  };
}
