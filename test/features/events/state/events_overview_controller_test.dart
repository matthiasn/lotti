import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/features/events/state/events_overview_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

JournalEvent _event(
  String id, {
  String? categoryId = 'cat-1',
  String title = 'Event',
  String? note,
}) {
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
    data: EventData(
      title: title,
      stars: 0,
      status: EventStatus.completed,
    ),
    entryText: note == null ? null : EntryText(plainText: note),
  );
}

JournalImage _image(String id, DateTime capturedAt) => JournalImage(
  meta: Metadata(
    id: id,
    createdAt: capturedAt,
    updatedAt: capturedAt,
    dateFrom: capturedAt,
    dateTo: capturedAt,
  ),
  data: ImageData(
    capturedAt: capturedAt,
    imageId: id,
    imageFile: '$id.jpg',
    imageDirectory: '/images/2026/',
  ),
);

LinkedDbEntry _link(String eventId, String imageId) => LinkedDbEntry(
  id: 'link-$imageId',
  fromId: eventId,
  toId: imageId,
  type: 'BasicLink',
  serialized: '{}',
  hidden: false,
  createdAt: DateTime(2026, 5, 12),
  updatedAt: DateTime(2026, 5, 12),
);

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
    expect(state.categoryIds, isEmpty);
    expect(state.query, isEmpty);
    expect(state.isFiltered, isFalse);
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

  test('setCategoryIds reloads filtered to every selected category', () async {
    stubPaged([
      _event('a1', categoryId: 'cat-a'),
      _event('b1', categoryId: 'cat-b'),
      _event('c1', categoryId: 'cat-c'),
      _event('a2', categoryId: 'cat-a'),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);

    await container
        .read(eventsOverviewControllerProvider.notifier)
        .setCategoryIds({'cat-a', 'cat-c'});

    final state = container.read(eventsOverviewControllerProvider).value!;
    expect(state.categoryIds, {'cat-a', 'cat-c'});
    expect(state.isFiltered, isTrue);
    expect(state.events.map((e) => e.event.meta.id), ['a1', 'c1', 'a2']);
  });

  test('setQuery narrows to events whose title or note matches', () async {
    stubPaged([
      _event('gala', title: 'Launch Gala'),
      _event('summit', title: 'Sardine summit'),
      _event('noted', title: 'Roll call', note: 'An unexpected gala after'),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);

    await container
        .read(eventsOverviewControllerProvider.notifier)
        .setQuery('GALA ');

    final state = container.read(eventsOverviewControllerProvider).value!;
    // Kept verbatim for the field; matched trimmed and case-insensitively.
    expect(state.query, 'GALA ');
    expect(state.isFiltered, isTrue);
    expect(state.events.map((e) => e.event.meta.id), ['gala', 'noted']);
    expect(state.hasMore, isFalse);
  });

  test('query and categories narrow together', () async {
    stubPaged([
      _event('a-gala', categoryId: 'cat-a', title: 'Gala A'),
      _event('b-gala', categoryId: 'cat-b', title: 'Gala B'),
      _event('a-other', categoryId: 'cat-a', title: 'Other'),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);
    final controller = container.read(
      eventsOverviewControllerProvider.notifier,
    );

    await controller.setQuery('gala');
    await controller.setCategoryIds({'cat-a'});

    final state = container.read(eventsOverviewControllerProvider).value!;
    expect(state.query, 'gala');
    expect(state.events.map((e) => e.event.meta.id), ['a-gala']);
  });

  test('clearFilters restores the full archive', () async {
    stubPaged([
      _event('a1', categoryId: 'cat-a', title: 'Gala'),
      _event('b1', categoryId: 'cat-b'),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);
    final controller = container.read(
      eventsOverviewControllerProvider.notifier,
    );
    await controller.setQuery('gala');
    await controller.setCategoryIds({'cat-a'});

    await controller.clearFilters();

    final state = container.read(eventsOverviewControllerProvider).value!;
    expect(state.isFiltered, isFalse);
    expect(state.events.map((e) => e.event.meta.id), ['a1', 'b1']);
  });

  test('a superseded keystroke cannot overwrite a newer result', () async {
    final events = [
      _event('ga', title: 'Gala'),
      _event('gar', title: 'Garden'),
    ];
    final slowFirst = Completer<void>();
    var searchCalls = 0;
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
      // The first search call ("ga") is held until the second ("gar") has
      // already landed, as a slow keystroke would be.
      if (invocation.namedArguments[#limit] != eventsPageSize &&
          searchCalls++ == 0) {
        await slowFirst.future;
      }
      return events;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);
    final controller = container.read(
      eventsOverviewControllerProvider.notifier,
    );

    final stale = controller.setQuery('ga');
    await controller.setQuery('gar');
    slowFirst.complete();
    await stale;

    final state = container.read(eventsOverviewControllerProvider).value!;
    expect(state.query, 'gar');
    expect(state.events.map((e) => e.event.meta.id), ['gar']);
  });

  group('overlapping filter changes', () {
    /// Pages over [all] like [stubPaged], but holds every call for which
    /// [hold] returns a future until that future completes.
    void stubHeld(
      List<JournalEvent> all, {
      required Future<void>? Function(Invocation) hold,
    }) {
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
        final gate = hold(invocation);
        if (gate != null) await gate;
        final limit = invocation.namedArguments[#limit] as int;
        final offset = invocation.namedArguments[#offset] as int;
        final categoryIds =
            invocation.namedArguments[#categoryIds] as Set<String>?;
        final filtered = categoryIds == null
            ? all
            : all
                  .where((e) => categoryIds.contains(e.meta.categoryId))
                  .toList();
        if (offset >= filtered.length) return <JournalEntity>[];
        final end = (offset + limit).clamp(0, filtered.length);
        return filtered.sublist(offset, end);
      });
    }

    bool isSearch(Invocation invocation) =>
        invocation.namedArguments[#limit] != eventsPageSize;

    test('clearing before the typed query lands restores everything', () async {
      final typed = Completer<void>();
      var held = false;
      stubHeld(
        [
          _event('gala', title: 'Gala'),
          _event('summit', title: 'Summit'),
        ],
        hold: (invocation) {
          if (!isSearch(invocation) || held) return null;
          held = true;
          return typed.future;
        },
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(eventsOverviewControllerProvider.future);
      final controller = container.read(
        eventsOverviewControllerProvider.notifier,
      );

      final pending = controller.setQuery('g');
      // The committed query is still '' here; the clear must not be
      // mistaken for a no-op.
      await controller.setQuery('');
      typed.complete();
      await pending;

      final state = container.read(eventsOverviewControllerProvider).value!;
      expect(state.query, isEmpty);
      expect(state.events.map((e) => e.event.meta.id), ['gala', 'summit']);
    });

    test('a category picked while a query loads keeps the query', () async {
      final typed = Completer<void>();
      var held = false;
      stubHeld(
        [
          _event('a-gala', categoryId: 'cat-a', title: 'Gala A'),
          _event('b-gala', categoryId: 'cat-b', title: 'Gala B'),
          _event('a-other', categoryId: 'cat-a', title: 'Other'),
        ],
        hold: (invocation) {
          if (!isSearch(invocation) || held) return null;
          held = true;
          return typed.future;
        },
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(eventsOverviewControllerProvider.future);
      final controller = container.read(
        eventsOverviewControllerProvider.notifier,
      );

      final pending = controller.setQuery('gala');
      await controller.setCategoryIds({'cat-a'});
      typed.complete();
      await pending;

      final state = container.read(eventsOverviewControllerProvider).value!;
      expect(state.query, 'gala');
      expect(state.categoryIds, {'cat-a'});
      expect(state.events.map((e) => e.event.meta.id), ['a-gala']);
    });

    test('a page loaded during a filter change cannot revert it', () async {
      final nextPage = Completer<void>();
      final all = [
        for (var i = 0; i < eventsPageSize + 5; i++)
          _event('e$i', title: i == 0 ? 'Gala' : 'Event'),
      ];
      stubHeld(
        all,
        hold: (invocation) =>
            invocation.namedArguments[#offset] != 0 ? nextPage.future : null,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = await container.read(
        eventsOverviewControllerProvider.future,
      );
      expect(first.hasMore, isTrue);
      final controller = container.read(
        eventsOverviewControllerProvider.notifier,
      );

      // The filter reload starts, the user scrolls, the filter lands, and
      // only then does the unfiltered next page arrive.
      final filtering = controller.setQuery('gala');
      final paging = controller.loadMore();
      await filtering;
      nextPage.complete();
      await paging;

      final state = container.read(eventsOverviewControllerProvider).value!;
      expect(state.query, 'gala');
      expect(state.events.map((e) => e.event.meta.id), ['e0']);
    });

    test(
      'a sync refresh during a filter change carries the new filter',
      () async {
        final typed = Completer<void>();
        var held = false;
        final master = [
          _event('gala', title: 'Gala'),
          _event('summit', title: 'Summit'),
        ];
        stubHeld(
          master,
          hold: (invocation) {
            if (!isSearch(invocation) || held) return null;
            held = true;
            return typed.future;
          },
        );
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(eventsOverviewControllerProvider.future);
        final controller = container.read(
          eventsOverviewControllerProvider.notifier,
        );

        final pending = controller.setQuery('gala');
        updates.add({eventNotification});
        await pumpEventQueue();
        typed.complete();
        await pending;

        final state = container.read(eventsOverviewControllerProvider).value!;
        expect(state.query, 'gala');
        expect(state.events.map((e) => e.event.meta.id), ['gala']);
      },
    );
  });

  test('re-applying the current filter does not reload', () async {
    stubPaged([_event('e1')]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);
    clearInteractions(db);

    await container
        .read(eventsOverviewControllerProvider.notifier)
        .setCategoryIds(const {});

    verifyNever(
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
    );
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
    'link notifications refresh the fallback cover for local and synced photos',
    () async {
      final event = _event('e1');
      final firstPhoto = _image('photo-1', DateTime(2026, 5, 13));
      final syncedPhoto = _image('photo-2', DateTime(2026, 5, 14));
      final images = {
        firstPhoto.meta.id: firstPhoto,
        syncedPhoto.meta.id: syncedPhoto,
      };
      final links = <LinkedDbEntry>[];
      stubPaged([event]);
      when(() => db.linksFromIds(any())).thenAnswer(
        (_) => MockSelectable<LinkedDbEntry>([...links]),
      );
      when(() => db.getJournalEntitiesForIds(any())).thenAnswer((
        invocation,
      ) async {
        final ids = invocation.positionalArguments.first as Set<String>;
        return ids.map((id) => images[id]).whereType<JournalEntity>().toList();
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      var state = await container.read(eventsOverviewControllerProvider.future);
      expect(state.events.single.coverImage, isNull);

      // Local photo creation writes a link row rather than updating the event.
      links.add(_link(event.meta.id, firstPhoto.meta.id));
      updates.add({event.meta.id, firstPhoto.meta.id, linkNotification});
      await pumpEventQueue();
      state = container.read(eventsOverviewControllerProvider).value!;
      expect(
        (state.events.single.coverImage! as FileImage).file.path,
        endsWith('photo-1.jpg'),
      );

      // Sync uses the same merged UI stream and must replace the cover with
      // the newer linked photo without an EVENT token or app restart.
      links.add(_link(event.meta.id, syncedPhoto.meta.id));
      updates.add({event.meta.id, syncedPhoto.meta.id, linkNotification});
      await pumpEventQueue();
      state = container.read(eventsOverviewControllerProvider).value!;
      expect(
        (state.events.single.coverImage! as FileImage).file.path,
        endsWith('photo-2.jpg'),
      );
    },
  );

  test('unrelated link notifications do not reload event covers', () async {
    final event = _event('e1');
    final master = [event];
    stubPaged(master);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(eventsOverviewControllerProvider.future);

    master.insert(0, _event('new'));
    updates.add({'unrelated-from', 'unrelated-to', linkNotification});
    await pumpEventQueue();
    expect(
      container
          .read(eventsOverviewControllerProvider)
          .value!
          .events
          .first
          .event
          .meta
          .id,
      event.meta.id,
    );

    updates.add({event.meta.id, 'photo-1', linkNotification});
    await pumpEventQueue();
    expect(
      container
          .read(eventsOverviewControllerProvider)
          .value!
          .events
          .first
          .event
          .meta
          .id,
      'new',
    );
  });

  test(
    'refresh reloads the full window when the loaded page is full',
    () async {
      final master = [for (var i = 0; i < eventsPageSize; i++) _event('e$i')];
      stubPaged(master);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = await container.read(
        eventsOverviewControllerProvider.future,
      );
      expect(first.events, hasLength(eventsPageSize));

      // A newer event arrives; refresh reloads the full loaded window
      // (count == events.length — the >= eventsPageSize branch).
      master.insert(0, _event('newest'));
      updates.add({eventNotification});
      await pumpEventQueue();

      final state = container.read(eventsOverviewControllerProvider).value!;
      expect(state.events.first.event.meta.id, 'newest');
      expect(state.events, hasLength(eventsPageSize));
    },
  );

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

  test('copyWith preserves fields that are not overridden', () {
    const base = EventsOverviewState(
      events: [],
      hasMore: true,
      isLoadingMore: true,
      categoryIds: {'cat-x'},
      query: 'gala',
    );

    final copy = base.copyWith(hasMore: false);

    // Only hasMore changed; the rest (including isLoadingMore) fall back to the
    // original via `?? this.x`.
    expect(copy.hasMore, isFalse);
    expect(copy.isLoadingMore, isTrue);
    expect(copy.events, same(base.events));
    expect(copy.categoryIds, {'cat-x'});
    expect(copy.query, 'gala');
  });
}
