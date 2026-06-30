import 'dart:convert';

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
final _t0 = DateTime(2024, 3, 15, 12);

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

void main() {
  late TestGetItMocks mocks;
  late MockOutboxService outbox;
  late SavedTaskFiltersRepository repository;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(<String>{});
  });

  setUp(() async {
    outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<OutboxService>(outbox);
      },
    );
    repository = SavedTaskFiltersRepository(
      SavedTaskFiltersPersistence(mocks.settingsDb),
      mocks.updateNotifications,
    );
  });

  tearDown(tearDownTestGetIt);

  void stubPersisted(List<SavedTaskFilter> items) {
    when(
      () => mocks.settingsDb.itemByKey(SavedTaskFiltersPersistence.storageKey),
    ).thenAnswer(
      (_) async =>
          jsonEncode(items.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  List<String> savedIds() {
    final captured = verify(
      () => mocks.settingsDb.saveSettingsItem(
        SavedTaskFiltersPersistence.storageKey,
        captureAny(),
      ),
    ).captured;
    final decoded = jsonDecode(captured.last as String) as List<dynamic>;
    return decoded
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toList();
  }

  group('upsert', () {
    test('appends a new filter, persists, enqueues, and notifies', () async {
      final f = _filter(id: 'sv-1');

      await repository.upsert(f);

      expect(savedIds(), ['sv-1']);
      final enqueued = verify(
        () => outbox.enqueueMessage(captureAny()),
      ).captured.single;
      expect(enqueued, isA<SyncSavedTaskFilter>());
      expect((enqueued as SyncSavedTaskFilter).filter.id, 'sv-1');
      verify(
        () => mocks.updateNotifications.notify(
          {'sv-1', savedTaskFiltersNotification},
        ),
      ).called(1);
    });

    test('replaces an existing filter by id', () async {
      stubPersisted([_filter(id: 'sv-1', name: 'Old')]);

      await repository.upsert(
        _filter(id: 'sv-1', name: 'New', filter: _filterB),
      );

      // Still a single entry (replaced, not appended).
      expect(savedIds(), ['sv-1']);
      verify(() => outbox.enqueueMessage(any())).called(1);
    });

    test(
      'with fromSync does not enqueue (no echo) but persists + notifies',
      () async {
        final f = _filter(id: 'sv-1');

        await repository.upsert(f, fromSync: true);

        expect(savedIds(), ['sv-1']);
        verifyNever(() => outbox.enqueueMessage(any()));
        verify(
          () => mocks.updateNotifications.notify(
            {'sv-1', savedTaskFiltersNotification},
            fromSync: true,
          ),
        ).called(1);
      },
    );

    test('is an idempotent no-op for an identical re-delivery', () async {
      final f = _filter(id: 'sv-1');
      stubPersisted([f]);

      await repository.upsert(f, fromSync: true);

      verifyNever(() => mocks.settingsDb.saveSettingsItem(any(), any()));
      verifyNever(() => outbox.enqueueMessage(any()));
      verifyNever(
        () => mocks.updateNotifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });

    test('drops a stale incoming revision under last-write-wins', () async {
      stubPersisted([
        _filter(id: 'sv-1', updatedAt: DateTime(2024, 3, 15, 12)),
      ]);

      // Incoming carries an OLDER updatedAt and arrives via sync.
      await repository.upsert(
        _filter(
          id: 'sv-1',
          name: 'stale',
          updatedAt: DateTime(2024, 3, 15, 11),
        ),
        fromSync: true,
      );

      verifyNever(() => mocks.settingsDb.saveSettingsItem(any(), any()));
      verifyNever(() => outbox.enqueueMessage(any()));
    });
  });

  group('delete', () {
    test('removes by id, persists, enqueues delete, and notifies', () async {
      stubPersisted([_filter(id: 'sv-1'), _filter(id: 'sv-2', name: 'B')]);

      await repository.delete('sv-1');

      expect(savedIds(), ['sv-2']);
      final enqueued = verify(
        () => outbox.enqueueMessage(captureAny()),
      ).captured.single;
      expect(enqueued, isA<SyncSavedTaskFilterDelete>());
      expect((enqueued as SyncSavedTaskFilterDelete).id, 'sv-1');
      verify(
        () => mocks.updateNotifications.notify(
          {'sv-1', savedTaskFiltersNotification},
        ),
      ).called(1);
    });

    test('is a no-op when the id is absent', () async {
      stubPersisted([_filter(id: 'sv-1')]);

      await repository.delete('missing');

      verifyNever(() => mocks.settingsDb.saveSettingsItem(any(), any()));
      verifyNever(() => outbox.enqueueMessage(any()));
    });

    test('with fromSync does not enqueue', () async {
      stubPersisted([_filter(id: 'sv-1')]);

      await repository.delete('sv-1', fromSync: true);

      expect(savedIds(), isEmpty);
      verifyNever(() => outbox.enqueueMessage(any()));
    });
  });

  group('saveOrder', () {
    test('persists the new order and notifies without enqueueing', () async {
      final reordered = [_filter(id: 'sv-2', name: 'B'), _filter(id: 'sv-1')];

      await repository.saveOrder(reordered);

      expect(savedIds(), ['sv-2', 'sv-1']);
      verifyNever(() => outbox.enqueueMessage(any()));
      verify(
        () => mocks.updateNotifications.notify({savedTaskFiltersNotification}),
      ).called(1);
    });
  });
}
