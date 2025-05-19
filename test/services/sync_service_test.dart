import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/services/sync_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockJournalDb extends Mock implements JournalDb {}

class MockOutboxService extends Mock implements OutboxService {}

class MockLoggingService extends Mock implements LoggingService {}

class SyncMessageFake extends Fake implements SyncMessage {}

void main() {
  late SyncService syncService;
  late MockJournalDb mockJournalDb;
  late MockOutboxService mockOutboxService;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(SyncMessageFake());
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockOutboxService = MockOutboxService();
    mockLoggingService = MockLoggingService();
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<OutboxService>(mockOutboxService)
      ..registerSingleton<LoggingService>(mockLoggingService);
    syncService = SyncService();
  });

  tearDown(getIt.reset);

  group('SyncService Tests', () {
    test('syncTags enqueues tags for sync', () async {
      final testTag = TagEntity.genericTag(
        id: '1',
        tag: 'test',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        inactive: false,
      );
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value([testTag]));
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await syncService.syncTags();

      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('syncTags skips deleted and inactive tags', () async {
      final deletedTag = TagEntity.genericTag(
        id: '2',
        tag: 'deleted',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        deletedAt: DateTime.now(),
        inactive: false,
      );
      final inactiveTag = TagEntity.genericTag(
        id: '3',
        tag: 'inactive',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        inactive: true,
      );
      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => Stream.value([deletedTag, inactiveTag]));

      await syncService.syncTags();

      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });
  });
}
