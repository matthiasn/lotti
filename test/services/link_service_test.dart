import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinkService Tests', () {
    late MockJournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockTagsService mockTagsService;
    late LinkService linkService;

    setUpAll(() {
      registerFallbackValue(testTextEntry);
      registerFallbackValue(InsightLevel.info);
      registerFallbackValue(InsightType.log);
    });

    setUp(() {
      // Unregister existing instances
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<PersistenceLogic>()) {
        getIt.unregister<PersistenceLogic>();
      }
      if (getIt.isRegistered<TagsService>()) {
        getIt.unregister<TagsService>();
      }
      if (getIt.isRegistered<LoggingService>()) {
        getIt.unregister<LoggingService>();
      }

      mockJournalDb = MockJournalDb();
      mockPersistenceLogic = MockPersistenceLogic();
      mockTagsService = MockTagsService();

      // Register a mock LoggingService that TagsRepository needs
      final mockLoggingService = MockLoggingService();
      when(() => mockLoggingService.captureEvent(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            level: any(named: 'level'),
            type: any(named: 'type'),
          )).thenAnswer((_) {});

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<LoggingService>(mockLoggingService);

      linkService = LinkService();

      // Stub HapticFeedback to avoid platform channel dependency under fake time
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (methodCall) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          return null;
        }
        return null;
      });
    });

    test('createLink does nothing when both IDs are null', () async {
      // Verify that createLink completes without calling persistence logic
      await linkService.createLink();

      verifyNever(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      );
    });

    test('createLink does nothing when only linkFromId is set', () {
      fakeAsync((async) {
        linkService.linkFrom('from-id');

        // Allow async tasks started by linkFrom/createLink to run.
        async.flushMicrotasks();

        verifyNever(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        );
      });
    });

    test('createLink creates link when both IDs are set via linkTo', () {
      fakeAsync((async) {
        // Set up mocks
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockJournalDb.journalEntityById('from-id'))
            .thenAnswer((_) async => testTextEntry);

        when(() => mockTagsService.getFilteredStoryTagIds(any()))
            .thenReturn([testStoryTag1.id]);

        // Set linkFromId first
        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        // Then set linkToId which should trigger createLink
        linkService.linkTo('to-id');
        async.flushMicrotasks();

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          ),
        ).called(1);

        verify(() => mockJournalDb.journalEntityById('from-id')).called(1);
        verify(() => mockTagsService.getFilteredStoryTagIds(any())).called(1);
      });
    });

    test('createLink creates link when both IDs are set via linkFrom', () {
      fakeAsync((async) {
        // Set up mocks
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockJournalDb.journalEntityById('from-id'))
            .thenAnswer((_) async => testTextEntry);

        when(() => mockTagsService.getFilteredStoryTagIds(any()))
            .thenReturn([testStoryTag1.id]);

        // Set linkToId first
        linkService.linkTo('to-id');
        async.flushMicrotasks();

        // Then set linkFromId which should trigger createLink
        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          ),
        ).called(1);
      });
    });

    test('createLink handles entity without tags', () {
      fakeAsync((async) {
        final entryWithoutTags = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(tagIds: null),
        );

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockJournalDb.journalEntityById('from-id'))
            .thenAnswer((_) async => entryWithoutTags);

        when(() => mockTagsService.getFilteredStoryTagIds(null)).thenReturn([]);

        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        linkService.linkTo('to-id');
        async.flushMicrotasks();

        verify(() => mockTagsService.getFilteredStoryTagIds(null)).called(1);
      });
    });

    test('createLink handles missing linked entity', () {
      fakeAsync((async) {
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockJournalDb.journalEntityById('from-id'))
            .thenAnswer((_) async => null);

        when(() => mockTagsService.getFilteredStoryTagIds(any()))
            .thenReturn([]);

        linkService.linkFrom('from-id');
        async.flushMicrotasks();

        linkService.linkTo('to-id');
        async.flushMicrotasks();

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'from-id',
            toId: 'to-id',
          ),
        ).called(1);
      });
    });
  });
}
