import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/features/events/state/events_overview_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

JournalEvent _event(String id, {String? categoryId = 'cat-1'}) {
  final now = DateTime(2026, 5, 12);
  return JournalEvent(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      categoryId: categoryId,
    ),
    data: const EventData(
      title: 'Event',
      stars: 0,
      status: EventStatus.completed,
    ),
  );
}

void main() {
  late MockJournalDb db;
  late MockEntitiesCacheService cache;
  late MockUpdateNotifications updateNotifications;
  late StreamController<Set<String>> updates;

  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<bool>[]);
    registerFallbackValue(<int>[]);
  });

  setUp(() async {
    await getIt.reset();
    db = MockJournalDb();
    cache = MockEntitiesCacheService();
    updateNotifications = MockUpdateNotifications();
    updates = StreamController<Set<String>>.broadcast();

    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => updates.stream);
    when(
      () => db.linksFromIds(any()),
    ).thenReturn(MockSelectable<LinkedDbEntry>([]));
    when(() => cache.showPrivateEntries).thenReturn(true);
    when(() => cache.getCategoryById(any())).thenReturn(null);

    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<EntitiesCacheService>(cache)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<Directory>(Directory.systemTemp);
  });

  tearDown(() async {
    await updates.close();
    await getIt.reset();
  });

  /// Stubs `getJournalEntities` to page over [all] honoring limit/offset and an
  /// optional category filter, mirroring the real DB contract.
  void stubPaged(List<JournalEvent> all) {
    when(
      () => db.getJournalEntities(
        types: any(named: 'types'),
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int;
      final offset = invocation.namedArguments[#offset] as int;
      final categoryIds =
          invocation.namedArguments[#categoryIds] as Set<String>?;
      final filtered = categoryIds == null
          ? all
          : all.where((e) => categoryIds.contains(e.meta.categoryId)).toList();
      if (offset >= filtered.length) return <JournalEntity>[];
      final end = (offset + limit).clamp(0, filtered.length);
      return filtered.sublist(offset, end);
    });
  }

  test('build loads the first page and reports more when it is full', () async {
    stubPaged([for (var i = 0; i < eventsPageSize + 10; i++) _event('e$i')]);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(eventsOverviewControllerProvider.future);

    expect(state.events, hasLength(eventsPageSize));
    expect(state.hasMore, isTrue);
    expect(state.categoryId, isNull);
  });

  test('hasMore is false when the first page is not full', () async {
    stubPaged([_event('e1'), _event('e2')]);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(eventsOverviewControllerProvider.future);

    expect(state.events, hasLength(2));
    expect(state.hasMore, isFalse);
  });

  test('loadMore appends the next page and updates hasMore', () async {
    stubPaged([for (var i = 0; i < eventsPageSize + 5; i++) _event('e$i')]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);

    await container.read(eventsOverviewControllerProvider.notifier).loadMore();

    final state = container.read(eventsOverviewControllerProvider).value!;
    expect(state.events, hasLength(eventsPageSize + 5));
    expect(state.hasMore, isFalse);
  });

  test('setCategory reloads filtered from the first page', () async {
    stubPaged([
      _event('a1', categoryId: 'cat-a'),
      _event('b1', categoryId: 'cat-b'),
      _event('a2', categoryId: 'cat-a'),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);

    await container
        .read(eventsOverviewControllerProvider.notifier)
        .setCategory('cat-a');

    final state = container.read(eventsOverviewControllerProvider).value!;
    expect(state.categoryId, 'cat-a');
    expect(state.events.map((e) => e.event.meta.id), ['a1', 'a2']);
  });

  test('an event notification refreshes the loaded window', () async {
    final master = [for (var i = 0; i < 3; i++) _event('e$i')];
    stubPaged(master);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);

    // A newer event arrives at the head, then the db signals a change.
    master.insert(0, _event('new'));
    updates.add({eventNotification});
    await pumpEventQueue();

    final state = container.read(eventsOverviewControllerProvider).value!;
    expect(state.events.first.event.meta.id, 'new');
    expect(state.events, hasLength(4));
  });

  test(
    'loadMore clears the loading flag and keeps paging open on error',
    () async {
      // First page (build) succeeds and is full; the next page (loadMore) throws.
      var calls = 0;
      when(
        () => db.getJournalEntities(
          types: any(named: 'types'),
          ids: any(named: 'ids'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          return [for (var i = 0; i < eventsPageSize; i++) _event('e$i')];
        }
        throw Exception('boom');
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = await container.read(
        eventsOverviewControllerProvider.future,
      );
      expect(first.hasMore, isTrue);

      await container
          .read(eventsOverviewControllerProvider.notifier)
          .loadMore();

      final state = container.read(eventsOverviewControllerProvider).value!;
      // Not stuck, still retryable, and the loaded page is preserved.
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.events, hasLength(eventsPageSize));
    },
  );
}
