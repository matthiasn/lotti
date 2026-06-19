import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/events/state/events_controller.dart';
import 'package:lotti/get_it.dart';
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

JournalImage _image(String id) {
  final now = DateTime(2026, 5, 12);
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: ImageData(
      capturedAt: now,
      imageId: id,
      imageFile: '$id.jpg',
      imageDirectory: '/images/2026/',
    ),
  );
}

void main() {
  late MockJournalDb db;
  late MockEntitiesCacheService cache;
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
    docDir = Directory.systemTemp;

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
      ),
    ).thenAnswer((_) async => events);
  }

  test('queries JournalEvent entities and resolves category styling', () async {
    stubEvents([_event(id: 'e1')]);
    when(() => db.getJournalEntitiesForIds(any())).thenAnswer((_) async => []);

    final resolved = await loadResolvedEvents();

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
      ),
    ).captured.single;
    expect(captured, const ['JournalEvent']);
  });

  test('resolves a cover image from coverArtId', () async {
    stubEvents([_event(id: 'e1', coverArtId: 'img-1')]);
    when(
      () => db.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => [_image('img-1')]);

    final resolved = await loadResolvedEvents();

    final cover = resolved.single.coverImage;
    expect(cover, isA<FileImage>());
    expect(
      (cover! as FileImage).file.path,
      getFullImagePath(_image('img-1'), documentsDirectory: docDir.path),
    );
  });

  test('does not fetch cover images when no event has cover art', () async {
    stubEvents([_event(id: 'e1')]);

    await loadResolvedEvents();

    verifyNever(() => db.getJournalEntitiesForIds(any()));
  });

  test(
    'passes private filter through when private entries are hidden',
    () async {
      when(() => cache.showPrivateEntries).thenReturn(false);
      stubEvents([]);

      await loadResolvedEvents();

      final captured = verify(
        () => db.getJournalEntities(
          types: any(named: 'types'),
          ids: any(named: 'ids'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: captureAny(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).captured.single;
      expect(captured, const [false]);
    },
  );
}
