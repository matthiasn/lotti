import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockJournalDb extends Mock implements JournalDb {}

class MockOutboxService extends Mock implements OutboxService {}

class MockLoggingService extends Mock implements LoggingService {}

class SyncMessageFake extends Fake implements SyncMessage {}

void main() {
  late SyncMaintenanceRepository syncService;
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
    syncService = SyncMaintenanceRepository();
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
          .thenAnswer((_) => Future.value());

      await syncService.syncTags();

      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('syncTags skips deleted tags', () async {
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
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) => Future.value());

      await syncService.syncTags();

      final capturedMessages =
          verify(() => mockOutboxService.enqueueMessage(captureAny())).captured;

      // Expect that exactly one message was captured
      expect(capturedMessages.length, 1);

      // Expect that the captured message is the inactiveTag
      final inactiveTagMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              tagEntity: (syncTag) => syncTag.tagEntity.id == inactiveTag.id,
            ) ??
            false,
        orElse: () =>
            null, // Add orElse to handle not found case, though expect will fail if it's null
      );
      expect(
        inactiveTagMessage,
        isNotNull,
        reason: 'Message for inactiveTag was not captured',
      );

      // Expect that no message for the deletedTag was captured
      final deletedTagMessage = capturedMessages.firstWhere(
        (m) =>
            (m as SyncMessage).mapOrNull(
              tagEntity: (syncTag) => syncTag.tagEntity.id == deletedTag.id,
            ) ??
            false,
        orElse: () => null, // Add orElse to return null if not found
      );
      expect(
        deletedTagMessage,
        isNull,
        reason: 'Message for deletedTag was captured but should not have been',
      );
    });
  });
}
