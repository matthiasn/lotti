import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/database/common.dart';

part 'settings_db.g.dart';

const settingsDbFileName = 'settings.sqlite';

@DriftDatabase(include: {'settings_db.drift'})
class SettingsDb extends _$SettingsDb {
  SettingsDb({
    this.inMemoryDatabase = false,
    // Settings reads and writes are tiny and latency-sensitive. Running them on
    // the main isolate avoids the extra message-hop overhead from
    // `createInBackground`, which dominated hot preference writes in practice.
    bool background = false,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           settingsDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  bool inMemoryDatabase = false;
  // Settings are read repeatedly on hot UI and sync paths. Cache per-process
  // lookups so repeated reads do not serialize through settings.sqlite.
  final Map<String, String?> _cache = <String, String?>{};
  final Map<String, Future<String?>> _inFlightReads =
      <String, Future<String?>>{};
  final Map<String, Completer<String?>> _pendingReadCompleters =
      <String, Completer<String?>>{};
  final Map<String, int> _pendingReadGenerations = <String, int>{};
  final Map<String, int> _cacheGenerations = <String, int>{};
  bool _isPendingReadFlushScheduled = false;
  Future<void> _writeTail = Future<void>.value();
  Future<void>? _closing;

  /// The schema this build writes. A restored backup may carry an
  /// older schema, which Drift migrates, but never a newer one.
  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  int _bumpGeneration(String configKey) => _cacheGenerations.update(
    configKey,
    (value) => value + 1,
    ifAbsent: () => 1,
  );

  /// Completes the read queued for [configKey], if any, with [value].
  ///
  /// A completer in [_pendingReadCompleters] is never already completed:
  /// every completion site removes it from the map first.
  void _resolveQueuedRead(String configKey, String? value) {
    _pendingReadGenerations.remove(configKey);
    _pendingReadCompleters.remove(configKey)?.complete(value);
  }

  @visibleForTesting
  Future<List<SettingsItem>> loadSettingsItems(Iterable<String> configKeys) {
    final keyList = configKeys.toSet().toList(growable: false);
    if (keyList.isEmpty) {
      return Future<List<SettingsItem>>.value(const <SettingsItem>[]);
    }

    return (select(
      settings,
    )..where((table) => table.configKey.isIn(keyList))).get();
  }

  // Serialize cache decisions with writes, including atomic groups. Otherwise a
  // single-key save can skip against an old cache while a group is committing.
  Future<T> _write<T>(Future<T> Function() action) {
    if (_closing != null) {
      return Future<T>.error(StateError('SettingsDb is closing'));
    }
    final previous = _writeTail;
    final completed = Completer<void>();
    _writeTail = completed.future;
    return (() async {
      await previous;
      try {
        return await action();
      } finally {
        completed.complete();
      }
    })();
  }

  /// Drains accepted writes before releasing the executor. New writes are
  /// rejected once shutdown begins, so a queued preference cannot outlive it.
  @override
  Future<void> close() => _closing ??= (() async {
    await _writeTail;
    await super.close();
  })();

  void _publishValue(String configKey, String? value) {
    // Reads may still return the prior value while a write is pending. Only a
    // committed write invalidates their generation; a rollback invalidates none.
    _bumpGeneration(configKey);
    _cache[configKey] = value;
    unawaited(_inFlightReads.remove(configKey));
    _resolveQueuedRead(configKey, value);
  }

  Future<int> saveSettingsItem(String configKey, String value) =>
      _write(() async {
        if (_cache.containsKey(configKey) && _cache[configKey] == value) {
          _publishValue(configKey, value);
          return 0;
        }
        final result = await into(settings).insertOnConflictUpdate(
          SettingsItem(
            configKey: configKey,
            value: value,
            updatedAt: clock.now(),
          ),
        );
        _publishValue(configKey, value);
        return result;
      });

  /// Persists a settings group atomically and publishes its cache after commit.
  ///
  /// A failed write leaves both durable values and cached values unchanged.
  /// This owns its transaction; callers must not wrap it in another SettingsDb
  /// transaction, whose later rollback would invalidate the published cache.
  Future<void> saveSettingsItems(Map<String, String> values) {
    final snapshot = Map<String, String>.of(values);
    return _write(() async {
      if (snapshot.isEmpty) return;
      final updatedAt = clock.now();
      await transaction(() async {
        for (final entry in snapshot.entries) {
          await into(settings).insertOnConflictUpdate(
            SettingsItem(
              configKey: entry.key,
              value: entry.value,
              updatedAt: updatedAt,
            ),
          );
        }
      });
      snapshot.forEach(_publishValue);
    });
  }

  Future<void> removeSettingsItem(String configKey) => _write(() async {
    await (delete(settings)..where((t) => t.configKey.equals(configKey))).go();
    _publishValue(configKey, null);
  });

  Future<Map<String, String?>> itemsByKeys(Iterable<String> configKeys) async {
    final keyList = configKeys.toSet().toList(growable: false);
    if (keyList.isEmpty) {
      return <String, String?>{};
    }

    final result = <String, String?>{};
    final pendingReads = <String, Future<String?>>{};
    for (final key in keyList) {
      if (_cache.containsKey(key)) {
        result[key] = _cache[key];
      } else {
        pendingReads[key] = itemByKey(key);
      }
    }

    if (pendingReads.isNotEmpty) {
      final resolvedEntries = await Future.wait(
        pendingReads.entries.map((entry) async {
          return MapEntry(entry.key, await entry.value);
        }),
      );
      result.addEntries(resolvedEntries);
    }

    return result;
  }

  Future<String?> itemByKey(String configKey) {
    if (_cache.containsKey(configKey)) {
      return Future<String?>.value(_cache[configKey]);
    }

    // A queued read is always registered in [_inFlightReads] alongside its
    // completer, and both are dropped together, so this also joins reads that
    // are still waiting for the batched flush.
    final inFlightRead = _inFlightReads[configKey];
    if (inFlightRead != null) {
      return inFlightRead;
    }

    final completer = Completer<String?>();
    _pendingReadCompleters[configKey] = completer;
    _pendingReadGenerations[configKey] = _cacheGenerations[configKey] ?? 0;

    late final Future<String?> future;
    future = completer.future.whenComplete(() {
      if (identical(_inFlightReads[configKey], future)) {
        _inFlightReads.remove(configKey);
      }
    });

    _inFlightReads[configKey] = future;
    _schedulePendingReadFlush();
    return future;
  }

  void _schedulePendingReadFlush() {
    if (_isPendingReadFlushScheduled) {
      return;
    }
    _isPendingReadFlushScheduled = true;
    Future<void>.microtask(_flushPendingReads);
  }

  /// Resolves every queued read with one batched query. When the queue was
  /// drained before the flush ran, [loadSettingsItems] answers the empty key
  /// list without touching the database.
  Future<void> _flushPendingReads() async {
    final pendingReads = Map<String, Completer<String?>>.from(
      _pendingReadCompleters,
    );
    final generationsAtStart = Map<String, int>.from(_pendingReadGenerations);
    _pendingReadCompleters.clear();
    _pendingReadGenerations.clear();
    _isPendingReadFlushScheduled = false;

    final keys = pendingReads.keys.toList(growable: false);

    try {
      final rows = await loadSettingsItems(keys);
      final valuesByKey = <String, String?>{
        for (final row in rows) row.configKey: row.value,
      };

      for (final key in keys) {
        final completer = pendingReads[key]!;
        final value = valuesByKey[key];
        if ((_cacheGenerations[key] ?? 0) == generationsAtStart[key]) {
          _cache[key] = value;
          completer.complete(value);
        } else {
          completer.complete(_cache[key]);
        }
      }
    } catch (error, stackTrace) {
      for (final completer in pendingReads.values) {
        completer.completeError(error, stackTrace);
      }
    }
  }
}
