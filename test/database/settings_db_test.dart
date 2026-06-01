import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';

class _TestSettingsDb extends SettingsDb {
  _TestSettingsDb({
    required this.loader,
    this.batchLoader,
  }) : super(inMemoryDatabase: true);

  final Future<SettingsItem?> Function(String configKey) loader;
  final Future<List<SettingsItem>> Function(Iterable<String> configKeys)?
  batchLoader;

  @override
  Future<List<SettingsItem>> loadSettingsItems(Iterable<String> configKeys) {
    if (batchLoader != null) {
      return batchLoader!(configKeys);
    }

    return Future.wait(configKeys.map(loader)).then(
      (rows) => rows.whereType<SettingsItem>().toList(growable: false),
    );
  }
}

/// Forces the batch loader to throw so the `_flushPendingReads` error branch
/// can be exercised.
class _ThrowingSettingsDb extends SettingsDb {
  _ThrowingSettingsDb({required this.error}) : super(inMemoryDatabase: true);

  final Object error;

  @override
  Future<List<SettingsItem>> loadSettingsItems(Iterable<String> configKeys) {
    return Future<List<SettingsItem>>.error(error);
  }
}

void main() {
  final timestamp = DateTime(2024, 3, 15, 12);
  late SettingsDb db;

  setUp(() {
    // Avoid drift warning when optimizer reuses isolates
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = SettingsDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  test('removeSettingsItem removes existing entries', () async {
    await db.saveSettingsItem('test_key', 'test_value');
    expect(await db.itemByKey('test_key'), 'test_value');

    await db.removeSettingsItem('test_key');

    expect(await db.itemByKey('test_key'), isNull);
  });

  test('removeSettingsItem handles non-existent key gracefully', () async {
    await expectLater(db.removeSettingsItem('missing_key'), completes);
  });

  test('itemByKey returns null when no value stored', () async {
    final value = await db.itemByKey('absent_key');
    expect(value, isNull);
  });

  test('full lifecycle: save, read, remove, verify empty', () async {
    await db.saveSettingsItem('lifecycle', 'initial');
    expect(await db.itemByKey('lifecycle'), 'initial');

    await db.removeSettingsItem('lifecycle');
    expect(await db.itemByKey('lifecycle'), isNull);
  });

  test('itemByKey reuses cached values for repeated lookups', () async {
    await db.saveSettingsItem('cached_key', 'cached_value');

    expect(await db.itemByKey('cached_key'), 'cached_value');

    await db.customStatement(
      "DELETE FROM settings WHERE config_key = 'cached_key'",
    );

    expect(await db.itemByKey('cached_key'), 'cached_value');
  });

  test('saveSettingsItem skips unchanged cached values', () async {
    final firstResult = await db.saveSettingsItem('same_key', 'same_value');
    final firstItems = await db.loadSettingsItems(['same_key']);

    final secondResult = await db.saveSettingsItem('same_key', 'same_value');
    final secondItems = await db.loadSettingsItems(['same_key']);

    expect(firstResult, isNot(0));
    expect(secondResult, 0);
    expect(secondItems, isNotEmpty);
    expect(secondItems.single.updatedAt, firstItems.single.updatedAt);
    expect(secondItems.single.value, 'same_value');
  });

  test(
    'itemsByKeys returns existing and missing values in one batch',
    () async {
      await db.saveSettingsItem('batch_key_a', 'value_a');
      await db.saveSettingsItem('batch_key_b', 'value_b');

      final values = await db.itemsByKeys({
        'batch_key_a',
        'batch_key_b',
        'missing_key',
      });

      expect(
        values,
        {
          'batch_key_a': 'value_a',
          'batch_key_b': 'value_b',
          'missing_key': null,
        },
      );
    },
  );

  test(
    'itemByKey coalesces concurrent cold lookups for the same key',
    () async {
      final completer = Completer<SettingsItem?>();
      var loadCount = 0;
      await db.close();
      db = _TestSettingsDb(
        loader: (configKey) {
          loadCount += 1;
          return completer.future;
        },
      );

      final firstRead = db.itemByKey('shared_key');
      final secondRead = db.itemByKey('shared_key');

      expect(identical(firstRead, secondRead), isTrue);
      expect(loadCount, 0);

      await Future<void>.microtask(() {});
      expect(loadCount, 1);

      completer.complete(
        SettingsItem(
          configKey: 'shared_key',
          value: 'shared_value',
          updatedAt: timestamp,
        ),
      );

      expect(await firstRead, 'shared_value');
      expect(await secondRead, 'shared_value');
    },
  );

  test(
    'itemByKey batches concurrent cold lookups for different keys',
    () async {
      final completer = Completer<List<SettingsItem>>();
      var batchLoadCount = 0;
      await db.close();
      db = _TestSettingsDb(
        loader: (_) => throw UnimplementedError('single loader not used'),
        batchLoader: (configKeys) {
          batchLoadCount += 1;
          expect(
            configKeys.toSet(),
            {'first_key', 'second_key'},
          );
          return completer.future;
        },
      );

      final firstRead = db.itemByKey('first_key');
      final secondRead = db.itemByKey('second_key');

      expect(batchLoadCount, 0);

      await Future<void>.microtask(() {});
      expect(batchLoadCount, 1);

      completer.complete([
        SettingsItem(
          configKey: 'first_key',
          value: 'first_value',
          updatedAt: timestamp,
        ),
        SettingsItem(
          configKey: 'second_key',
          value: 'second_value',
          updatedAt: timestamp,
        ),
      ]);

      expect(await firstRead, 'first_value');
      expect(await secondRead, 'second_value');
    },
  );

  test('saveSettingsItem wins over stale in-flight reads', () async {
    final completer = Completer<SettingsItem?>();
    await db.close();
    db = _TestSettingsDb(loader: (_) => completer.future);

    final readFuture = db.itemByKey('race_key');

    await db.saveSettingsItem('race_key', 'fresh_value');
    completer.complete(
      SettingsItem(
        configKey: 'race_key',
        value: 'stale_value',
        updatedAt: timestamp,
      ),
    );

    expect(await readFuture, 'fresh_value');
    expect(await db.itemByKey('race_key'), 'fresh_value');
  });

  test(
    'removeSettingsItem prevents stale in-flight reads from repopulating cache',
    () async {
      final completer = Completer<SettingsItem?>();
      var loadCount = 0;
      await db.close();
      db = _TestSettingsDb(
        loader: (_) {
          loadCount += 1;
          if (loadCount == 1) {
            return completer.future;
          }
          return Future<SettingsItem?>.value();
        },
      );

      final readFuture = db.itemByKey('removed_key');

      await db.removeSettingsItem('removed_key');
      completer.complete(
        SettingsItem(
          configKey: 'removed_key',
          value: 'stale_value',
          updatedAt: timestamp,
        ),
      );

      expect(await readFuture, isNull);
      expect(await db.itemByKey('removed_key'), isNull);
    },
  );

  test('loadSettingsItems returns empty list for empty key set', () async {
    final items = await db.loadSettingsItems(const <String>[]);
    expect(items, isEmpty);
  });

  test(
    'loadSettingsItems short-circuits before touching the database',
    () async {
      // Close the underlying database first; the empty-key fast path must not
      // attempt any query, so this still resolves to an empty list.
      await db.close();
      final closedDb = SettingsDb(inMemoryDatabase: true);
      await closedDb.close();

      expect(await closedDb.loadSettingsItems(const <String>[]), isEmpty);

      db = SettingsDb(inMemoryDatabase: true);
    },
  );

  test('itemsByKeys returns empty map for empty key set', () async {
    final values = await db.itemsByKeys(const <String>{});
    expect(values, isEmpty);
  });

  test(
    'flush propagates loader failures to every queued completer',
    () async {
      final failure = Exception('settings load failed');
      await db.close();
      db = _ThrowingSettingsDb(error: failure);

      final firstRead = db.itemByKey('error_key_a');
      final secondRead = db.itemByKey('error_key_b');

      await expectLater(firstRead, throwsA(same(failure)));
      await expectLater(secondRead, throwsA(same(failure)));
    },
  );
}
