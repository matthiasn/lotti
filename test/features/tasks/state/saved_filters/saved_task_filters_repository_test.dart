import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_persistence.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _filterA = TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'});
const _filterB = TasksFilter(
  agentAssignmentFilter: AgentAssignmentFilter.noAgent,
);
final _t0 = DateTime.utc(2024, 3, 15, 12);

SavedTaskFilter _filter({
  required String id,
  String name = 'A',
  TasksFilter filter = _filterA,
  DateTime? updatedAt,
}) => SavedTaskFilter(
  id: id,
  name: name,
  filter: filter,
  createdAt: _t0,
  updatedAt: updatedAt ?? _t0,
);

/// One device: a settings store backed by a map (so reads see writes, and
/// every future completes in the same microtask turn, which `fakeAsync`
/// needs), and the repository over it. A fresh [SavedTaskFiltersRepository]
/// on the same [settings] models a restart.
class _Device {
  _Device(this.name, this._bench) {
    when(() => settingsDb.itemByKey(any())).thenAnswer(
      (invocation) async => settings[invocation.positionalArguments[0]],
    );
    when(() => settingsDb.saveSettingsItem(any(), any())).thenAnswer((
      invocation,
    ) async {
      settings[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
      return 1;
    });
    restart();
  }

  final String name;
  final _Bench _bench;
  final settings = <String, String>{};
  final settingsDb = MockSettingsDb();
  late SavedTaskFiltersRepository repository;

  /// Every row this device's outbox accepted, in order.
  final sent = <SyncMessage>[];

  /// Makes the next [failures] enqueues on this device throw.
  int failures = 0;

  void restart() {
    repository = SavedTaskFiltersRepository(
      SavedTaskFiltersPersistence(settingsDb),
      _bench.notifications,
    );
  }

  /// Runs [action] as this device, so the shared outbox records its rows.
  Future<T> run<T>(Future<T> Function(SavedTaskFiltersRepository r) action) {
    _bench.current = this;
    return action(repository);
  }

  /// Applies [message] the way `SyncEventProcessor` does, after the wire
  /// round trip.
  Future<void> receive(SyncMessage message) {
    final decoded = SyncMessage.fromJson(
      jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
    );
    return run(
      (r) => switch (decoded) {
        SyncSavedTaskFilter(:final filter) => r.upsert(filter, fromSync: true),
        SyncSavedTaskFilterDelete(:final id, :final deletedAt) => r.delete(
          id,
          fromSync: true,
          deletedAt: deletedAt,
        ),
        _ => throw StateError('unexpected $decoded'),
      },
    );
  }

  Future<List<SavedTaskFilter>> stored() => repository.load();

  void storeRaw(List<SavedTaskFilter> filters) {
    settings[SavedTaskFiltersPersistence.storageKey] = jsonEncode(
      filters.map((f) => f.toJson()).toList(),
    );
  }

  Set<String> get owed {
    final raw = settings[SavedTaskFiltersPersistence.ledgerKey];
    if (raw == null) return const {};
    return SavedTaskFilterSyncLedger.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    ).pending;
  }
}

class _Bench {
  _Bench(this.outbox, this.notifications) {
    when(() => outbox.enqueueMessageOrThrow(any())).thenAnswer((
      invocation,
    ) async {
      final device = current!;
      if (device.failures > 0) {
        device.failures--;
        throw StateError('outbox unavailable');
      }
      device.sent.add(invocation.positionalArguments[0] as SyncMessage);
    });
  }

  final MockOutboxService outbox;
  final MockUpdateNotifications notifications;
  _Device? current;

  _Device device(String name) => _Device(name, this);

  /// Delivers every row [from] has sent to [to], in order.
  Future<void> deliver(_Device from, _Device to) async {
    for (final message in [...from.sent]) {
      await to.receive(message);
    }
  }
}

/// Every ordering of [items].
Iterable<List<T>> _permutations<T>(List<T> items) sync* {
  if (items.length <= 1) {
    yield items;
    return;
  }
  for (var i = 0; i < items.length; i++) {
    final rest = [...items]..removeAt(i);
    for (final tail in _permutations(rest)) {
      yield [items[i], ...tail];
    }
  }
}

void main() {
  late TestGetItMocks mocks;
  late _Bench bench;
  late _Device desktop;
  late _Device mobile;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(<String>{});
  });

  setUp(() async {
    final outbox = MockOutboxService();
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<OutboxService>(outbox);
      },
    );
    bench = _Bench(outbox, mocks.updateNotifications);
    desktop = bench.device('desktop');
    mobile = bench.device('mobile');
  });

  tearDown(tearDownTestGetIt);

  List<String> ids(List<SavedTaskFilter> filters) => [
    for (final f in filters) f.id,
  ];

  group('savedTaskFiltersRepositoryProvider', () {
    test('resolves the getIt-registered repository instance', () {
      getIt.registerSingleton<SavedTaskFiltersRepository>(desktop.repository);
      addTearDown(() => getIt.unregister<SavedTaskFiltersRepository>());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(savedTaskFiltersRepositoryProvider),
        same(desktop.repository),
      );
    });
  });

  group('upsert', () {
    test(
      'appends, persists, sends, notifies, and owes nothing after',
      () async {
        await desktop.run((r) => r.upsert(_filter(id: 'sv-1')));

        expect(ids(await desktop.stored()), ['sv-1']);
        expect(desktop.sent, [
          SyncMessage.savedTaskFilter(
            filter: _filter(id: 'sv-1'),
            status: SyncEntryStatus.update,
          ),
        ]);
        expect(desktop.owed, isEmpty);
        verify(
          () => mocks.updateNotifications.notify(
            {'sv-1', savedTaskFiltersNotification},
          ),
        ).called(1);
      },
    );

    test('replaces an existing filter by id', () async {
      await desktop.run((r) => r.upsert(_filter(id: 'sv-1', name: 'Old')));
      await desktop.run(
        (r) => r.upsert(
          _filter(
            id: 'sv-1',
            name: 'New',
            filter: _filterB,
            updatedAt: _t0.add(const Duration(minutes: 1)),
          ),
        ),
      );

      final stored = await desktop.stored();
      expect(ids(stored), ['sv-1']);
      expect(stored.single.name, 'New');
      expect(desktop.sent, hasLength(2));
    });

    test('stamps a local edit past the revision it replaces', () async {
      // The editing device's clock is an hour behind the stored revision's.
      await desktop.run((r) => r.upsert(_filter(id: 'sv-1')));
      await desktop.run(
        (r) => r.upsert(
          _filter(
            id: 'sv-1',
            name: 'Renamed',
            updatedAt: _t0.subtract(const Duration(hours: 1)),
          ),
        ),
      );

      final stored = (await desktop.stored()).single;
      expect(stored.name, 'Renamed');
      expect(stored.updatedAt, _t0.add(const Duration(milliseconds: 1)));

      // So a peer holding the replaced revision takes the edit.
      await bench.deliver(desktop, mobile);
      expect((await mobile.stored()).single.name, 'Renamed');
    });

    test('from sync persists and notifies without sending', () async {
      await mobile.run(
        (r) => r.upsert(_filter(id: 'sv-1'), fromSync: true),
      );

      expect(ids(await mobile.stored()), ['sv-1']);
      expect(mobile.sent, isEmpty);
      expect(mobile.owed, isEmpty);
      verify(
        () => mocks.updateNotifications.notify(
          {'sv-1', savedTaskFiltersNotification},
          fromSync: true,
        ),
      ).called(1);
    });

    test('is an idempotent no-op for an identical re-delivery', () async {
      await mobile.run(
        (r) => r.upsert(_filter(id: 'sv-1'), fromSync: true),
      );
      clearInteractions(mobile.settingsDb);
      clearInteractions(mocks.updateNotifications);

      await mobile.run(
        (r) => r.upsert(_filter(id: 'sv-1'), fromSync: true),
      );

      verifyNever(() => mobile.settingsDb.saveSettingsItem(any(), any()));
      verifyNever(
        () => mocks.updateNotifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });

    test('from sync drops a strictly older revision', () async {
      await mobile.run(
        (r) => r.upsert(_filter(id: 'sv-1', name: 'current'), fromSync: true),
      );

      await mobile.run(
        (r) => r.upsert(
          _filter(
            id: 'sv-1',
            name: 'stale',
            updatedAt: _t0.subtract(const Duration(hours: 1)),
          ),
          fromSync: true,
        ),
      );

      expect((await mobile.stored()).single.name, 'current');
    });

    test('from sync ranks an unstamped revision below a stamped one', () async {
      await mobile.run(
        (r) => r.upsert(_filter(id: 'sv-1', name: 'stamped'), fromSync: true),
      );

      await mobile.run(
        (r) => r.upsert(
          const SavedTaskFilter(id: 'sv-1', name: 'legacy', filter: _filterA),
          fromSync: true,
        ),
      );

      expect((await mobile.stored()).single.name, 'stamped');
    });
  });

  group('delete', () {
    test('removes, tombstones, sends the stamped delete, notifies', () async {
      await desktop.run((r) => r.upsert(_filter(id: 'sv-1')));
      await desktop.run((r) => r.upsert(_filter(id: 'sv-2', name: 'B')));
      final deletedAt = _t0.add(const Duration(days: 1));
      clearInteractions(mocks.updateNotifications);

      await withClock(Clock.fixed(deletedAt), () async {
        await desktop.run((r) => r.delete('sv-1'));
      });

      expect(ids(await desktop.stored()), ['sv-2']);
      expect(
        desktop.sent.last,
        SyncMessage.savedTaskFilterDelete(id: 'sv-1', deletedAt: deletedAt),
      );
      expect(desktop.owed, isEmpty);
      verify(
        () => mocks.updateNotifications.notify(
          {'sv-1', savedTaskFiltersNotification},
        ),
      ).called(1);
    });

    test('stamps a delete no earlier than the revision it removes', () async {
      final revision = _t0.add(const Duration(days: 1));
      await desktop.run(
        (r) => r.upsert(_filter(id: 'sv-1', updatedAt: revision)),
      );

      // The deleting device's clock is behind the revision.
      await withClock(Clock.fixed(_t0), () async {
        await desktop.run((r) => r.delete('sv-1'));
      });

      expect(
        desktop.sent.last,
        SyncMessage.savedTaskFilterDelete(id: 'sv-1', deletedAt: revision),
      );
    });

    test('is a no-op when the id is absent', () async {
      await desktop.run((r) => r.delete('missing'));

      verifyNever(() => desktop.settingsDb.saveSettingsItem(any(), any()));
      expect(desktop.sent, isEmpty);
    });

    test('from sync removes without sending', () async {
      await mobile.run((r) => r.upsert(_filter(id: 'sv-1'), fromSync: true));

      await mobile.run(
        (r) => r.delete(
          'sv-1',
          fromSync: true,
          deletedAt: _t0.add(const Duration(hours: 1)),
        ),
      );

      expect(await mobile.stored(), isEmpty);
      expect(mobile.sent, isEmpty);
    });

    test('from sync keeps a revision edited after the delete', () async {
      final edited = _t0.add(const Duration(hours: 2));
      await mobile.run(
        (r) => r.upsert(_filter(id: 'sv-1', updatedAt: edited), fromSync: true),
      );

      await mobile.run(
        (r) => r.delete(
          'sv-1',
          fromSync: true,
          deletedAt: _t0.add(const Duration(hours: 1)),
        ),
      );

      expect(ids(await mobile.stored()), ['sv-1']);
    });

    test('from sync without a stamp (an older build) removes it', () async {
      final edited = _t0.add(const Duration(hours: 2));
      await mobile.run(
        (r) => r.upsert(_filter(id: 'sv-1', updatedAt: edited), fromSync: true),
      );

      await mobile.receive(const SyncMessage.savedTaskFilterDelete(id: 'sv-1'));

      expect(await mobile.stored(), isEmpty);
    });

    test('a tombstone rejects a revision that arrives after it', () async {
      // The delete reaches the phone before the filter it deletes.
      await mobile.receive(
        SyncMessage.savedTaskFilterDelete(
          id: 'sv-1',
          deletedAt: _t0.add(const Duration(hours: 1)),
        ),
      );
      await mobile.receive(
        SyncMessage.savedTaskFilter(
          filter: _filter(id: 'sv-1'),
          status: SyncEntryStatus.update,
        ),
      );
      expect(await mobile.stored(), isEmpty);

      // A revision after the delete is an edit that wins over it.
      await mobile.receive(
        SyncMessage.savedTaskFilter(
          filter: _filter(
            id: 'sv-1',
            updatedAt: _t0.add(const Duration(hours: 2)),
          ),
          status: SyncEntryStatus.update,
        ),
      );
      expect(ids(await mobile.stored()), ['sv-1']);
    });
  });

  group('durable sync intent', () {
    test('filters saved before they synced are sent on flush', () async {
      // A desktop that ran a build without sync: filters, no ledger.
      desktop.storeRaw([
        const SavedTaskFilter(id: 'old-1', name: 'Legacy', filter: _filterA),
        _filter(id: 'old-2', name: 'Stamped'),
      ]);

      await desktop.run((r) => r.flushPending());
      await bench.deliver(desktop, mobile);

      expect(ids(await mobile.stored()), ['old-1', 'old-2']);
      expect(desktop.owed, isEmpty);

      // The migration runs once: a later flush owes nothing.
      await desktop.run((r) => r.flushPending());
      expect(desktop.sent, hasLength(2));
    });

    test('filters received from a peer are not owed back', () async {
      await mobile.receive(
        SyncMessage.savedTaskFilter(
          filter: _filter(id: 'sv-1'),
          status: SyncEntryStatus.update,
        ),
      );

      await mobile.run((r) => r.flushPending());

      expect(mobile.sent, isEmpty);
    });

    test('a failed enqueue stays owed and is retried by the timer', () {
      fakeAsync((async) {
        desktop.failures = 1;
        unawaited(desktop.run((r) => r.upsert(_filter(id: 'sv-1'))));
        async.flushMicrotasks();

        expect(ids(desktop.storedNow), ['sv-1']);
        expect(desktop.sent, isEmpty);
        expect(desktop.owed, {'sv-1'});

        async
          ..elapse(desktop.repository.retryDelay)
          ..flushMicrotasks();

        expect(desktop.sent, [
          SyncMessage.savedTaskFilter(
            filter: _filter(id: 'sv-1'),
            status: SyncEntryStatus.update,
          ),
        ]);
        expect(desktop.owed, isEmpty);
      });
    });

    test('a failed delete stays owed and is sent after a restart', () async {
      await desktop.run((r) => r.upsert(_filter(id: 'sv-1')));
      desktop.failures = 1;
      await withClock(Clock.fixed(_t0.add(const Duration(hours: 1))), () async {
        await desktop.run((r) => r.delete('sv-1'));
      });
      expect(desktop.owed, {'sv-1'});

      // The process dies before the retry; the next start flushes.
      desktop.repository.dispose();
      desktop.restart();
      await desktop.run((r) => r.flushPending());

      expect(
        desktop.sent.last,
        SyncMessage.savedTaskFilterDelete(
          id: 'sv-1',
          deletedAt: _t0.add(const Duration(hours: 1)),
        ),
      );
      expect(desktop.owed, isEmpty);
    });

    test('dispose cancels a scheduled retry', () {
      fakeAsync((async) {
        desktop.failures = 1;
        unawaited(desktop.run((r) => r.upsert(_filter(id: 'sv-1'))));
        async.flushMicrotasks();

        desktop.repository.dispose();
        async.elapse(desktop.repository.retryDelay * 2);

        expect(desktop.sent, isEmpty);
        expect(desktop.owed, {'sv-1'});
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('saveOrder', () {
    test('reorders without sending and keeps what sync added since', () async {
      await mobile.run((r) => r.upsert(_filter(id: 'sv-1')));
      await mobile.run((r) => r.upsert(_filter(id: 'sv-2', name: 'B')));
      final sentBefore = mobile.sent.length;
      // The controller loaded sv-1 and sv-2; then sv-3 arrived by sync.
      await mobile.receive(
        SyncMessage.savedTaskFilter(
          filter: _filter(id: 'sv-3', name: 'C'),
          status: SyncEntryStatus.update,
        ),
      );

      await mobile.run((r) => r.saveOrder(['sv-2', 'sv-1', 'gone']));

      expect(ids(await mobile.stored()), ['sv-2', 'sv-1', 'sv-3']);
      expect(mobile.sent, hasLength(sentBefore));
      verify(
        () => mocks.updateNotifications.notify({savedTaskFiltersNotification}),
      ).called(1);
    });
  });

  group('convergence', () {
    test('equal stamps settle on the same revision on both devices', () async {
      await desktop.run((r) => r.upsert(_filter(id: 'sv-1', name: 'Desk')));
      await mobile.run((r) => r.upsert(_filter(id: 'sv-1', name: 'Phone')));

      await bench.deliver(desktop, mobile);
      await bench.deliver(mobile, desktop);

      final onDesktop = (await desktop.stored()).single;
      expect((await mobile.stored()).single, onDesktop);
      // The tie goes to the greater canonical content, on either device.
      expect(onDesktop.name, 'Phone');
    });

    test('canonical content ignores the iteration order of sets', () {
      final a = _filter(
        id: 'sv-1',
        filter: const TasksFilter(selectedTaskStatuses: {'OPEN', 'DONE'}),
      );
      final b = _filter(
        id: 'sv-1',
        filter: const TasksFilter(selectedTaskStatuses: {'DONE', 'OPEN'}),
      );
      final c = _filter(id: 'sv-1', name: 'B');

      expect(compareRevisions(a, b), 0);
      expect(compareRevisions(a, c).sign, -compareRevisions(c, a).sign);
      expect(compareRevisions(a, c), isNot(0));
    });

    test('every delivery order of an edit and a delete agrees', () async {
      // Desktop creates the filter; mobile edits it later while desktop,
      // without having seen the edit, deletes it at a stamp in between.
      final rows = [
        SyncMessage.savedTaskFilter(
          filter: _filter(id: 'sv-1'),
          status: SyncEntryStatus.update,
        ),
        SyncMessage.savedTaskFilter(
          filter: _filter(
            id: 'sv-1',
            name: 'Edited',
            updatedAt: _t0.add(const Duration(hours: 2)),
          ),
          status: SyncEntryStatus.update,
        ),
        SyncMessage.savedTaskFilterDelete(
          id: 'sv-1',
          deletedAt: _t0.add(const Duration(hours: 1)),
        ),
        SyncMessage.savedTaskFilterDelete(
          id: 'sv-1',
          deletedAt: _t0.add(const Duration(hours: 3)),
        ),
      ];

      for (final withLateDelete in [false, true]) {
        final sent = withLateDelete ? rows : rows.sublist(0, 3);
        final outcomes = <String>{};
        for (final order in _permutations(sent)) {
          final receiver = bench.device('receiver');
          for (final row in order) {
            await receiver.receive(row);
          }
          outcomes.add(jsonEncode(await receiver.stored()));
        }
        // One outcome for every order: the edit survives the earlier delete
        // and loses to the later one.
        expect(outcomes, hasLength(1), reason: 'late delete: $withLateDelete');
        final settled = (jsonDecode(outcomes.single) as List<dynamic>)
            .cast<Object?>();
        expect(settled, withLateDelete ? isEmpty : hasLength(1));
      }
    });
  });
}

extension on _Device {
  /// The stored filters, read synchronously from the backing map.
  List<SavedTaskFilter> get storedNow {
    final raw = settings[SavedTaskFiltersPersistence.storageKey];
    if (raw == null) return const [];
    return [
      for (final item in jsonDecode(raw) as List<dynamic>)
        SavedTaskFilter.fromJson(item as Map<String, dynamic>),
    ];
  }
}
