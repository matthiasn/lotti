import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart' show getIt;
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

final testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late MockJournalDb mockJournalDb;
  late MockVectorClockService mockVectorClockService;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockOutboxService mockOutboxService;
  late JournalRepository repository;
  late ProviderContainer container;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockVectorClockService = MockVectorClockService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockOutboxService = MockOutboxService();

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
      ..registerSingleton<NotificationService>(MockNotificationService())
      ..registerSingleton<LoggingService>(MockLoggingService())
      ..registerSingleton<VectorClockService>(mockVectorClockService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<OutboxService>(mockOutboxService)
      ..registerSingleton<TimeService>(MockTimeService());

    container = ProviderContainer();
    final ref = container.read(testRefProvider);
    repository = JournalRepository(ref);

    registerFallbackValue(
      Metadata(
        id: 'test-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        dateFrom: DateTime(2023),
        dateTo: DateTime(2023),
        starred: false,
        private: false,
        flag: EntryFlag.none,
      ),
    );
    registerFallbackValue(
      JournalEntity.journalEntry(
        entryText: const EntryText(plainText: 'test', markdown: 'test'),
        meta: Metadata(
          id: 'test-id',
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          dateFrom: DateTime(2023),
          dateTo: DateTime(2023),
          starred: false,
        ),
      ),
    );
    registerFallbackValue(
      SyncMessage.entryLink(
        entryLink: EntryLink.basic(
          id: 'link-id',
          fromId: 'from-id',
          toId: 'to-id',
          updatedAt: DateTime(2023),
          createdAt: DateTime(2023),
          vectorClock: null,
        ),
        status: SyncEntryStatus.update,
      ),
    );
    registerFallbackValue(
      EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        updatedAt: DateTime(2023),
        createdAt: DateTime(2023),
        vectorClock: null,
      ),
    );
    registerFallbackValue(
      TaskData(
        status: TaskStatus.open(
          id: 'status-id',
          createdAt: DateTime(2023),
          utcOffset: 0,
        ),
        dateFrom: DateTime(2023),
        dateTo: DateTime(2023),
        statusHistory: const [],
        title: 'Test Task',
      ),
    );
    registerFallbackValue(EntryFlag.none);
    registerFallbackValue(DateTime(2023));
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
  });

  group('updateLink with collapsed', () {
    test('persists collapsed change locally but does not sync', () async {
      final testLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );
      final updatedLink = testLink.copyWith(collapsed: true);

      when(() => mockJournalDb.entryLinkById(updatedLink.id))
          .thenAnswer((_) async => testLink);
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(updatedLink);

      expect(result, isTrue);
      verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
      verify(() => mockUpdateNotifications.notify(any())).called(1);
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
      verifyNever(() => mockVectorClockService.getNextVectorClock());
    });

    test('skips update when collapsed is unchanged (both null)', () async {
      final testLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );

      when(() => mockJournalDb.entryLinkById(testLink.id))
          .thenAnswer((_) async => testLink);

      final result = await repository.updateLink(testLink);

      expect(result, isFalse);
      verifyNever(() => mockJournalDb.upsertEntryLink(any()));
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('skips update when collapsed is unchanged (both false)', () async {
      final testLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        collapsed: false,
      );
      final existing = testLink.copyWith(collapsed: false);

      when(() => mockJournalDb.entryLinkById(testLink.id))
          .thenAnswer((_) async => existing);

      final result = await repository.updateLink(testLink);

      expect(result, isFalse);
      verifyNever(() => mockJournalDb.upsertEntryLink(any()));
    });

    test('treats null and false collapsed as equivalent', () async {
      final existingLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        // collapsed is null
      );
      final incomingLink = existingLink.copyWith(collapsed: false);

      when(() => mockJournalDb.entryLinkById(incomingLink.id))
          .thenAnswer((_) async => existingLink);

      final result = await repository.updateLink(incomingLink);

      expect(result, isFalse);
      verifyNever(() => mockJournalDb.upsertEntryLink(any()));
    });

    test('persists collapsed true -> false locally without syncing', () async {
      final existingLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        collapsed: true,
      );
      final incomingLink = existingLink.copyWith(collapsed: false);

      when(() => mockJournalDb.entryLinkById(incomingLink.id))
          .thenAnswer((_) async => existingLink);
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(incomingLink);

      expect(result, isTrue);
      verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
      verifyNever(() => mockVectorClockService.getNextVectorClock());
    });

    test('notifies affected IDs after collapsed update', () async {
      final testLink = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );
      final updatedLink = testLink.copyWith(collapsed: true);

      when(() => mockJournalDb.entryLinkById(updatedLink.id))
          .thenAnswer((_) async => testLink);
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});

      await repository.updateLink(updatedLink);

      verify(
        () => mockUpdateNotifications.notify({'from-id', 'to-id'}),
      ).called(1);
    });
  });

  group('_hasSyncableChange via updateLink', () {
    test('detects fromId change as meaningful', () async {
      final existing = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-1',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );
      final incoming = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-2',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );

      when(() => mockJournalDb.entryLinkById(incoming.id))
          .thenAnswer((_) async => existing);
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'node1': 1}));
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(incoming);

      expect(result, isTrue);
      verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
    });

    test('detects toId change as meaningful', () async {
      final existing = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-1',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );
      final incoming = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-2',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );

      when(() => mockJournalDb.entryLinkById(incoming.id))
          .thenAnswer((_) async => existing);
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'node1': 1}));
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(incoming);

      expect(result, isTrue);
      verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
    });

    test('detects createdAt change as meaningful', () async {
      final existing = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );
      final incoming = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );

      when(() => mockJournalDb.entryLinkById(incoming.id))
          .thenAnswer((_) async => existing);
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'node1': 1}));
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(incoming);

      expect(result, isTrue);
    });

    test('detects deletedAt change as meaningful', () async {
      final existing = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );
      final incoming = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        deletedAt: DateTime(2024),
      );

      when(() => mockJournalDb.entryLinkById(incoming.id))
          .thenAnswer((_) async => existing);
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'node1': 1}));
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(incoming);

      expect(result, isTrue);
    });

    test('strips collapsed from sync payload on syncable change', () async {
      final existing = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        collapsed: true,
      );
      // Change hidden (syncable) while collapsed is true
      final incoming = existing.copyWith(hidden: true);

      when(() => mockJournalDb.entryLinkById(incoming.id))
          .thenAnswer((_) async => existing);
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'node1': 1}));
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      await repository.updateLink(incoming);

      // Verify the sync message has collapsed stripped (set to null)
      final captured =
          verify(() => mockOutboxService.enqueueMessage(captureAny()))
              .captured
              .single as SyncEntryLink;
      expect(captured.entryLink.collapsed, isNull);
    });

    test('detects hidden change as meaningful', () async {
      final existing = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );
      final incoming = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        hidden: true,
      );

      when(() => mockJournalDb.entryLinkById(incoming.id))
          .thenAnswer((_) async => existing);
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'node1': 1}));
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(incoming);

      expect(result, isTrue);
    });

    test('skips update when no fields changed', () async {
      final link = EntryLink.basic(
        id: 'link-id',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
        hidden: true,
        collapsed: true,
      );

      when(() => mockJournalDb.entryLinkById(link.id))
          .thenAnswer((_) async => link);

      final result = await repository.updateLink(link);

      expect(result, isFalse);
      verifyNever(() => mockJournalDb.upsertEntryLink(any()));
    });

    test('proceeds when existing link is null (new link)', () async {
      final link = EntryLink.basic(
        id: 'new-link',
        fromId: 'from-id',
        toId: 'to-id',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        vectorClock: null,
      );

      when(() => mockJournalDb.entryLinkById(link.id))
          .thenAnswer((_) async => null);
      when(() => mockVectorClockService.getNextVectorClock())
          .thenAnswer((_) async => const VectorClock({'node1': 1}));
      when(() => mockJournalDb.upsertEntryLink(any()))
          .thenAnswer((_) async => 1);
      when(() => mockUpdateNotifications.notify(any()))
          .thenAnswer((_) async {});
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      final result = await repository.updateLink(link);

      expect(result, isTrue);
      verify(() => mockJournalDb.upsertEntryLink(any())).called(1);
    });
  });
}
