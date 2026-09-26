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

  group('cached writes own their transaction', () {
    test('another database retains its own commit boundary', () async {
      final other = SettingsDb(inMemoryDatabase: true);
      addTearDown(other.close);
      await db.transaction(
        () => other.saveSettingsItem('independent', 'saved'),
      );
      expect(await other.itemByKey('independent'), 'saved');
      expect(
        (await other.loadSettingsItems(['independent'])).single.value,
        'saved',
      );
      expect(await db.loadSettingsItems(['independent']), isEmpty);
    });

    for (final kind in ['single', 'group', 'remove']) {
      test(
        '$kind rejects an outer transaction without changing data',
        () async {
          await db.saveSettingsItem('guarded', 'before');
          await db.transaction(() async {
            final Future<Object?> write = switch (kind) {
              'single' => db.saveSettingsItem('guarded', 'after'),
              'group' => db.saveSettingsItems({'guarded': 'after'}),
              _ => db.removeSettingsItem('guarded'),
            };
            await expectLater(
              write,
              throwsA(
                isA<StateError>().having(
                  (e) => e.message,
                  'reason',
                  contains('outer transaction'),
                ),
              ),
            );
          });
          expect(await db.itemByKey('guarded'), 'before');
          expect(
            (await db.loadSettingsItems(['guarded'])).single.value,
            'before',
          );
          await db.saveSettingsItem('guarded', 'after');
          expect(await db.itemByKey('guarded'), 'after');
        },
      );
    }

    test(
      'rejects before waiting on an outside writer blocked by the transaction',
      () async {
        await db.saveSettingsItem('guarded', 'before');
        final entered = Completer<void>();
        final outsideQueued = Completer<void>();
        final outer = db.transaction(() async {
          entered.complete();
          await outsideQueued.future;
          await expectLater(
            db.saveSettingsItem('guarded', 'inside'),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'reason',
                contains('outer transaction'),
              ),
            ),
          );
        });
        await entered.future;
        final outside = db.saveSettingsItem('guarded', 'outside');
        outsideQueued.complete();
        await Future.wait<Object?>([outer, outside]);
        expect(await db.itemByKey('guarded'), 'outside');
        expect(
          (await db.loadSettingsItems(['guarded'])).single.value,
          'outside',
        );
      },
    );
  });

  test(
    'close drains pending settings writes before closing the executor',
    () async {
      final first = db.saveSettingsItem('first', 'one');
      final second = db.saveSettingsItems({'second': 'two', 'third': 'three'});
      final closing = db.close();
      await Future.wait<void>([first.then((_) {}), second, closing]);
      expect(await db.itemsByKeys(['first', 'second', 'third']), {
        'first': 'one',
        'second': 'two',
        'third': 'three',
      });
    },
  );

  test('close rejects new writes while draining accepted work', () async {
    final accepted = db.saveSettingsItem('first', 'one');
    final closing = db.close();
    await expectLater(
      db.saveSettingsItem('late', 'lost'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'reason',
          'SettingsDb is closing',
        ),
      ),
    );
    await accepted;
    await closing;
    expect(await db.itemByKey('first'), 'one');
    await expectLater(
      db.saveSettingsItem('after', 'closed'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'reason',
          'SettingsDb is closing',
        ),
      ),
    );
  });

  test('close drains writes after a failed queued write', () async {
    await db.saveSettingsItem('first', 'before');
    await db.customStatement(
      'CREATE TRIGGER reject_first BEFORE INSERT ON settings '
      "WHEN NEW.config_key = 'first' BEGIN "
      "SELECT RAISE(ABORT, 'injected close failure'); END",
    );
    final failed = expectLater(
      db.saveSettingsItem('first', 'after'),
      throwsA(isA<Exception>()),
    );
    final accepted = db.saveSettingsItem('second', 'two');
    final closing = db.close();
    await Future.wait<void>([failed, accepted.then((_) {}), closing]);
    expect(await db.itemsByKeys(['first', 'second']), {
      'first': 'before',
      'second': 'two',
    });
  });

  group('local versioned settings groups', () {
    const before = {'stamp': '300', 'mode': 'light', 'scheme': 'custom'};
    Future<Map<String, String>> stored() async => {
      for (final row in await db.loadSettingsItems(before.keys))
        row.configKey: row.value,
    };
    Future<SavedSettingsGroup> edit(String mode) => db.saveLocalSettingsGroup(
      {'mode': mode},
      stampKey: 'stamp',
      timestamp: 200,
      retainedDefaults: {'scheme': 'default'},
    );

    test(
      'local edits advance a future stamp and retain companion values',
      () async {
        await db.saveSettingsItems(before);
        final first = edit('dark');
        final second = edit('system');
        final a = await first;
        final b = await second;
        expect(a.updatedAt, 301);
        expect(a.values, {'mode': 'dark', 'scheme': 'custom'});
        expect(b.updatedAt, 302);
        expect(b.values, {'mode': 'system', 'scheme': 'custom'});
        expect(
          await db.saveSettingsItemsIfNewer(
            before,
            stampKey: 'stamp',
            payloadKeys: ['mode', 'scheme'],
          ),
          isFalse,
        );
        final expected = {'stamp': '302', ...b.values};
        expect(await stored(), expected);
        expect(await db.itemsByKeys(before.keys), expected);
      },
    );

    test(
      'local stamp failure rolls back values and leaves the next stamp usable',
      () async {
        await db.saveSettingsItems(before);
        await db.customStatement(
          'CREATE TRIGGER reject_local_stamp BEFORE INSERT ON settings '
          "WHEN NEW.config_key = 'stamp' BEGIN "
          "SELECT RAISE(ABORT, 'injected local stamp failure'); END",
        );
        await expectLater(edit('dark'), throwsA(isA<Exception>()));
        expect(await stored(), before);
        expect(await db.itemsByKeys(before.keys), before);
        await db.customStatement('DROP TRIGGER reject_local_stamp');
        final saved = await edit('dark');
        expect(saved.updatedAt, 301);
        expect(await stored(), {
          'stamp': '301',
          'mode': 'dark',
          'scheme': 'custom',
        });
      },
    );

    test(
      'local snapshot owns inputs and supplies missing companion defaults',
      () async {
        final values = {'mode': 'dark'};
        final defaults = {'scheme': 'default'};
        final pending = db.saveLocalSettingsGroup(
          values,
          stampKey: 'stamp',
          timestamp: 200,
          retainedDefaults: defaults,
        );
        values['mode'] = 'mutated';
        defaults['scheme'] = 'mutated';
        final saved = await pending;
        expect(saved.updatedAt, 200);
        expect(saved.values, {'mode': 'dark', 'scheme': 'default'});
        expect(() => saved.values['mode'] = 'changed', throwsUnsupportedError);
        expect(await stored(), {
          'stamp': '200',
          'mode': 'dark',
          'scheme': 'default',
        });
      },
    );
  });

  group('versioned settings groups', () {
    const before = {'stamp': '100', 'first': 'A', 'second': 'Z', 'marker': '9'};
    const after = {'stamp': '200', 'first': 'B', 'second': 'A', 'marker': '0'};
    Future<bool> apply(Map<String, String> values) =>
        db.saveSettingsItemsIfNewer(
          values,
          stampKey: 'stamp',
          payloadKeys: ['second', 'first'],
        );
    Future<Map<String, String>> stored() async => {
      for (final row in await db.loadSettingsItems(before.keys))
        row.configKey: row.value,
    };

    test(
      'stamp precedes canonical payload tuple and excludes metadata',
      () async {
        await db.saveSettingsItems(before);
        expect(await apply({...after, 'stamp': '99'}), isFalse);
        expect(await stored(), before);
        // Keys are canonicalized: first wins despite second and marker being
        // lexicographically lower. An equal payload may update its marker.
        final tied = {...after, 'stamp': '100'};
        expect(await apply(tied), isTrue);
        expect(await apply(before), isFalse);
        expect(await stored(), tied);
        final marked = {...tied, 'marker': '1'};
        expect(await apply(marked), isTrue);
        expect(await stored(), marked);
        expect(await db.itemsByKeys(marked.keys), marked);
      },
    );

    test(
      'queued newer group wins before an older conditional write checks',
      () async {
        await db.saveSettingsItems(before);
        final entered = Completer<void>();
        final release = Completer<void>();
        final holding = db.transaction(() async {
          await db.customSelect('SELECT 1').get();
          entered.complete();
          await release.future;
        });
        await entered.future;
        final newer = {...after, 'stamp': '300'};
        final first = db.saveSettingsItems(newer);
        final second = apply(after);
        release.complete();
        await holding;
        await first;
        expect(await second, isFalse);
        expect(await stored(), newer);
        expect(await db.itemsByKeys(newer.keys), newer);
      },
    );

    test('failure rolls back guard metadata and values before retry', () async {
      await db.saveSettingsItems(before);
      await db.customStatement(
        'CREATE TRIGGER reject_group BEFORE INSERT ON settings '
        "WHEN NEW.config_key = 'second' BEGIN "
        "SELECT RAISE(ABORT, 'injected group failure'); END",
      );
      await expectLater(apply(after), throwsA(isA<Exception>()));
      expect(await stored(), before);
      expect(await db.itemsByKeys(before.keys), before);
      await db.customStatement('DROP TRIGGER reject_group');
      expect(await apply(after), isTrue);
      expect(await stored(), after);
    });

    test('queued conditional write snapshots caller values', () async {
      final input = {...after};
      final result = apply(input);
      input['first'] = 'mutated';
      input['stamp'] = '999';
      expect(await result, isTrue);
      expect(await stored(), after);
    });

    test('invalid payload key sets cannot change a group', () async {
      for (final keys in <List<String>>[
        [],
        ['stamp'],
        ['missing'],
      ]) {
        expect(
          () => db.saveSettingsItemsIfNewer(
            after,
            stampKey: 'stamp',
            payloadKeys: keys,
          ),
          throwsArgumentError,
        );
      }
      expect(await stored(), isEmpty);
    });
  });

  group('atomic settings groups', () {
    const before = {'first': 'old-first', 'second': 'old-second'};
    const after = {'first': 'new-first', 'second': 'new-second'};

    Future<Map<String, String>> stored() async => {
      for (final row in await db.loadSettingsItems(before.keys))
        row.configKey: row.value,
    };

    test('publishes all values only after the transaction succeeds', () async {
      await db.saveSettingsItems(before);
      await db.saveSettingsItems(after);
      expect(await stored(), after);
      expect(await db.itemsByKeys(before.keys), after);
    });

    test(
      'rolls back an earlier field and its cache when a later write fails',
      () async {
        await db.saveSettingsItems(before);
        await db.customStatement(
          'CREATE TRIGGER reject_second BEFORE INSERT ON settings '
          "WHEN NEW.config_key = 'second' BEGIN "
          "SELECT RAISE(ABORT, 'injected settings failure'); END",
        );
        await expectLater(
          db.saveSettingsItems(after),
          throwsA(isA<Exception>()),
        );
        expect(await stored(), before);
        expect(await db.itemsByKeys(before.keys), before);
        await db.customStatement('DROP TRIGGER reject_second');
        await db.saveSettingsItems(after);
        expect(await stored(), after);
        expect(await db.itemsByKeys(before.keys), after);
      },
    );

    test(
      'serializes a same-as-old single write behind a pending group',
      () async {
        await db.saveSettingsItems(before);
        final entered = Completer<void>();
        final release = Completer<void>();
        final blocker = db.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final group = db.saveSettingsItems(after);
        final single = db.saveSettingsItem('first', 'old-first');
        expect(await db.itemByKey('first'), 'old-first');
        release.complete();
        await blocker;
        await group;
        await single;
        expect(await stored(), {'first': 'old-first', 'second': 'new-second'});
        expect(await db.itemsByKeys(before.keys), await stored());
      },
    );

    test('snapshots input and allows a queued removal after a group', () async {
      final input = Map<String, String>.of(before);
      final write = db.saveSettingsItems(input);
      input['first'] = 'mutated';
      final remove = db.removeSettingsItem('second');
      await write;
      await remove;
      expect(await stored(), {'first': 'old-first'});
      expect(await db.itemsByKeys(before.keys), {
        'first': 'old-first',
        'second': null,
      });
      await db.saveSettingsItems({});
      expect(await stored(), {'first': 'old-first'});
    });
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

  test('cold read returns the old value while a group awaits commit', () async {
    final snapshot = Completer<SettingsItem?>();
    final readStarted = Completer<void>();
    await db.close();
    db = _TestSettingsDb(
      loader: (_) {
        readStarted.complete();
        return snapshot.future;
      },
    );
    await db.customStatement(
      'INSERT INTO settings (config_key, value, updated_at) VALUES (?, ?, ?)',
      ['first', 'before', timestamp.millisecondsSinceEpoch ~/ 1000],
    );
    final read = db.itemByKey('first');
    await readStarted.future;
    final entered = Completer<void>();
    final release = Completer<void>();
    final blocker = db.transaction(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final write = db.saveSettingsItems({'first': 'after'});
    await Future<void>.microtask(() {});
    snapshot.complete(
      SettingsItem(
        configKey: 'first',
        value: 'before',
        updatedAt: timestamp,
      ),
    );
    try {
      expect(await read, 'before');
    } finally {
      release.complete();
      await blocker;
      await write;
    }
    expect(await db.itemByKey('first'), 'after');
  });

  for (final operation in ['single', 'group', 'remove']) {
    test('failed $operation write preserves an in-flight cold read', () async {
      final snapshot = Completer<SettingsItem?>();
      final started = Completer<void>();
      await db.close();
      db = _TestSettingsDb(
        loader: (_) {
          started.complete();
          return snapshot.future;
        },
      );
      await db.customStatement(
        'INSERT INTO settings (config_key, value, updated_at) VALUES (?, ?, ?)',
        ['first', 'before', timestamp.millisecondsSinceEpoch ~/ 1000],
      );
      final read = db.itemByKey('first');
      await started.future;
      final deleting = operation == 'remove';
      final failingKey = operation == 'group' ? 'second' : 'first';
      await db.customStatement(
        'CREATE TRIGGER reject_write BEFORE ${deleting ? 'DELETE' : 'INSERT'} '
        'ON settings WHEN ${deleting ? 'OLD' : 'NEW'}.config_key = '
        "'$failingKey' BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      final write = switch (operation) {
        'single' => db.saveSettingsItem('first', 'after'),
        'group' => db.saveSettingsItems({'first': 'after', 'second': 'after'}),
        _ => db.removeSettingsItem('first'),
      };
      await expectLater(write, throwsA(isA<Exception>()));
      snapshot.complete(
        SettingsItem(
          configKey: 'first',
          value: 'before',
          updatedAt: timestamp,
        ),
      );
      expect(await read, 'before');
      expect(await db.itemByKey('first'), 'before');
      final persisted = await db
          .customSelect(
            "SELECT value FROM settings WHERE config_key = 'first'",
          )
          .getSingle();
      expect(persisted.read<String>('value'), 'before');
    });
  }

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

  group('itemsWithKeyPrefix', () {
    test('returns every row whose key starts with the prefix, and no other '
        'row', () async {
      await db.saveSettingsItem('intent:a', 'first');
      await db.saveSettingsItem('intent:b', 'second');
      await db.saveSettingsItem('intentional', 'no colon');
      await db.saveSettingsItem('other:intent:c', 'prefix inside the key');

      expect(await db.itemsWithKeyPrefix('intent:'), {
        'intent:a': 'first',
        'intent:b': 'second',
      });
    });

    test('reads the table, so a removed row is gone', () async {
      await db.saveSettingsItem('intent:a', 'first');
      await db.saveSettingsItem('intent:b', 'second');
      await db.removeSettingsItem('intent:a');

      expect(await db.itemsWithKeyPrefix('intent:'), {'intent:b': 'second'});
    });

    test('treats % and _ in the prefix as literal characters', () async {
      await db.saveSettingsItem('a%b:1', 'percent');
      await db.saveSettingsItem('aXYZb:2', 'matches an unescaped %');
      await db.saveSettingsItem('c_d:1', 'underscore');
      await db.saveSettingsItem('cXd:2', 'matches an unescaped _');

      expect(await db.itemsWithKeyPrefix('a%b:'), {'a%b:1': 'percent'});
      expect(await db.itemsWithKeyPrefix('c_d:'), {'c_d:1': 'underscore'});
    });

    test('treats a backslash in the prefix as a literal character', () async {
      await db.saveSettingsItem(r'e\%f:1', 'backslash then percent');
      await db.saveSettingsItem('e%f:2', 'percent alone');

      expect(await db.itemsWithKeyPrefix(r'e\%f:'), {
        r'e\%f:1': 'backslash then percent',
      });
    });

    test('compares case exactly, so a differently cased key is not '
        'matched', () async {
      await db.saveSettingsItem('intent:a', 'lower');
      await db.saveSettingsItem('Intent:b', 'capitalised');
      await db.saveSettingsItem('INTENT:c', 'upper');

      expect(await db.itemsWithKeyPrefix('intent:'), {'intent:a': 'lower'});
      expect(await db.itemsWithKeyPrefix('Intent:'), {
        'Intent:b': 'capitalised',
      });
    });

    test('returns an empty map when no key has the prefix', () async {
      await db.saveSettingsItem('intent:a', 'first');

      expect(await db.itemsWithKeyPrefix('missing:'), isEmpty);
    });
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
