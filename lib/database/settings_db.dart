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

  @override
  int get schemaVersion => 1;

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

  Future<int> saveSettingsItem(String configKey, String value) async {
    if (_cache.containsKey(configKey) && _cache[configKey] == value) {
      unawaited(_inFlightReads.remove(configKey));
      _resolveQueuedRead(configKey, value);
      return 0;
    }

    _bumpGeneration(configKey);
    final settingsItem = SettingsItem(
      configKey: configKey,
      value: value,
      updatedAt: clock.now(),
    );

    final result = await into(settings).insertOnConflictUpdate(settingsItem);
    _cache[configKey] = value;
    unawaited(_inFlightReads.remove(configKey));
    _resolveQueuedRead(configKey, value);
    return result;
  }

  Future<void> removeSettingsItem(String configKey) async {
    _bumpGeneration(configKey);
    await (delete(settings)..where((t) => t.configKey.equals(configKey))).go();
    _cache.remove(configKey);
    unawaited(_inFlightReads.remove(configKey));
    _resolveQueuedRead(configKey, null);
  }

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
