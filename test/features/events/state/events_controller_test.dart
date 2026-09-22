import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

JournalEvent _event({
  required String id,
  String? categoryId = 'cat-1',
  String? coverArtId,
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
      title: 'Event $id',
      stars: 4,
      status: EventStatus.completed,
      coverArtId: coverArtId,
    ),
  );
}

JournalImage _image(String id, {DateTime? dateFrom}) {
  final now = DateTime(2026, 5, 12);
  final from = dateFrom ?? now;
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: from,
      dateTo: from,
    ),
    data: ImageData(
      capturedAt: now,
      imageId: id,
      imageFile: '$id.jpg',
      imageDirectory: '/images/2026/',
    ),
  );
}

LinkedDbEntry _link(String id, {required String from, required String to}) {
  final now = DateTime(2026, 5, 12);
  return LinkedDbEntry(
    id: id,
    fromId: from,
    toId: to,
    type: 'BasicLink',
    serialized: '{}',
    hidden: false,
    createdAt: now,
    updatedAt: now,
  );
}

Future<List<ResolvedEvent>> _loadAllResolvedEvents() =>
    loadResolvedEventsPage(limit: 1000, offset: 0);

void main() {
  late MockJournalDb db;
  late MockEntitiesCacheService cache;
  late MockUpdateNotifications updateNotifications;
  late Directory docDir;

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
    docDir = Directory.systemTemp;

    when(
      () => updateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());

    // No linked photos by default; individual tests override for the fallback.
    when(
      () => db.linksFromIds(any()),
    ).thenReturn(MockSelectable<LinkedDbEntry>([]));

    when(() => cache.showPrivateEntries).thenReturn(true);
    when(() => cache.getCategoryById(any())).thenReturn(
      CategoryDefinition(
        id: 'cat-1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        name: 'Friends',
        vectorClock: null,
        private: false,
        active: true,
        color: '#E91E63',
      ),
    );

    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<EntitiesCacheService>(cache)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<Directory>(docDir);
  });

  tearDown(() async => getIt.reset());

  void stubEvents(List<JournalEntity> events) {
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
    ).thenAnswer((_) async => events);
  }

  test('queries JournalEvent entities and resolves category styling', () async {
    stubEvents([_event(id: 'e1')]);
    when(() => db.getJournalEntitiesForIds(any())).thenAnswer((_) async => []);

    final resolved = await _loadAllResolvedEvents();

    expect(resolved, hasLength(1));
    expect(resolved.single.event.meta.id, 'e1');
    expect(resolved.single.categoryName, 'Friends');
    expect(resolved.single.categoryColor, const Color(0xFFE91E63));
    expect(resolved.single.coverImage, isNull);

    final captured = verify(
      () => db.getJournalEntities(
        types: captureAny(named: 'types'),
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).captured.single;
    expect(captured, const ['JournalEvent']);
  });

  test('resolves a cover image from coverArtId', () async {
    stubEvents([_event(id: 'e1', coverArtId: 'img-1')]);
    when(
      () => db.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => [_image('img-1')]);

    final resolved = await _loadAllResolvedEvents();

    final cover = resolved.single.coverImage;
    expect(cover, isA<FileImage>());
    expect(
      (cover! as FileImage).file.path,
      getFullImagePath(_image('img-1'), documentsDirectory: docDir.path),
    );
  });

  test(
    'resolves no cover when the event has neither cover art nor photos',
    () async {
      stubEvents([_event(id: 'e1')]);

      final resolved = await _loadAllResolvedEvents();

      expect(resolved.single.coverImage, isNull);
      // No cover-art ids → the by-id fetch is skipped; the fallback queries
      // links, finds none, and resolves no image.
      verify(() => db.linksFromIds(any())).called(1);
      verifyNever(() => db.getJournalEntitiesForIds(any()));
    },
  );

  test('falls back to a linked photo when no cover art is set', () async {
    stubEvents([_event(id: 'e1')]);
    when(
      () => db.linksFromIds(any()),
    ).thenReturn(
      MockSelectable<LinkedDbEntry>([_link('l1', from: 'e1', to: 'img-1')]),
    );
    when(
      () => db.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => [_image('img-1')]);

    final resolved = await _loadAllResolvedEvents();

    final cover = resolved.single.coverImage;
    expect(cover, isA<FileImage>());
    expect(
      (cover! as FileImage).file.path,
      getFullImagePath(_image('img-1'), documentsDirectory: docDir.path),
    );
  });

  test('fallback picks the newest linked photo', () async {
    final older = _image('img-old', dateFrom: DateTime(2026, 5, 10));
    final newer = _image('img-new', dateFrom: DateTime(2026, 5, 20));
    stubEvents([_event(id: 'e1')]);
    when(() => db.linksFromIds(any())).thenReturn(
      MockSelectable<LinkedDbEntry>([
        _link('l1', from: 'e1', to: 'img-old'),
        _link('l2', from: 'e1', to: 'img-new'),
      ]),
    );
    when(
      () => db.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => [older, newer]);

    final resolved = await _loadAllResolvedEvents();

    expect(
      (resolved.single.coverImage! as FileImage).file.path,
      getFullImagePath(newer, documentsDirectory: docDir.path),
    );
  });

  test(
    'passes private filter through when private entries are hidden',
    () async {
      when(() => cache.showPrivateEntries).thenReturn(false);
      stubEvents([]);

      await _loadAllResolvedEvents();

      final captured = verify(
        () => db.getJournalEntities(
          types: any(named: 'types'),
          ids: any(named: 'ids'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: captureAny(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).captured.single;
      expect(captured, const [false]);
    },
  );

  group('search', () {
    ({int limit, int offset, Set<String>? categoryIds}) capturedQuery() {
      final call = verify(
        () => db.getJournalEntities(
          types: any(named: 'types'),
          ids: any(named: 'ids'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          categoryIds: captureAny(named: 'categoryIds'),
          limit: captureAny(named: 'limit'),
          offset: captureAny(named: 'offset'),
        ),
      ).captured;
      // mocktail records captures in argument-name order, so pick by type:
      // the one set is the category scope, the ints are limit then offset.
      final ints = call.whereType<int>().toList();
      return (
        categoryIds: call.whereType<Set<String>>().firstOrNull,
        limit: ints[0],
        offset: ints[1],
      );
    }

    test('without a query, pages in the database', () async {
      stubEvents([_event(id: 'e1')]);

      await loadResolvedEventsPage(limit: 60, offset: 120);

      final query = capturedQuery();
      expect(query.limit, 60);
      expect(query.offset, 120);
      // No selection means every category, not an empty IN list.
      expect(query.categoryIds, isNull);
    });

    test(
      'with a query, scans the whole category scope and pages the matches',
      () async {
        stubEvents([
          _event(id: 'gala-1'),
          _event(id: 'other'),
          _event(id: 'gala-2'),
          _event(id: 'gala-3'),
        ]);

        final resolved = await loadResolvedEventsPage(
          limit: 1,
          offset: 1,
          categoryIds: {'cat-1', ''},
          query: 'GALA',
        );

        // Titles are "Event <id>": three match, and the page after the first
        // is the second match — paging applies to matches, not raw rows.
        expect(resolved.map((r) => r.event.meta.id), ['gala-2']);
        final query = capturedQuery();
        expect(query.offset, 0);
        expect(query.limit, greaterThan(1000));
        expect(query.categoryIds, {'cat-1', ''});
      },
    );

    test('a blank query does not switch to scanning', () async {
      stubEvents([_event(id: 'e1')]);

      await loadResolvedEventsPage(limit: 60, offset: 0, query: '   ');

      expect(capturedQuery().limit, 60);
    });
  });

  group('eventMatchesQuery', () {
    final event = _event(id: 'launch').copyWith(
      entryText: const EntryText(plainText: 'Ceremonial Sardines served'),
    );

    test('matches a title substring regardless of case', () {
      expect(eventMatchesQuery(event, 'LAUN'), isTrue);
    });

    test('matches the note text', () {
      expect(eventMatchesQuery(event, 'sardines'), isTrue);
    });

    test('ignores surrounding whitespace', () {
      expect(eventMatchesQuery(event, '  launch '), isTrue);
    });

    test('a blank query matches everything', () {
      expect(eventMatchesQuery(event, '  '), isTrue);
    });

    test('rejects text found in neither title nor note', () {
      expect(eventMatchesQuery(event, 'wedding'), isFalse);
      expect(eventMatchesQuery(_event(id: 'plain'), 'sardines'), isFalse);
    });
  });
}
