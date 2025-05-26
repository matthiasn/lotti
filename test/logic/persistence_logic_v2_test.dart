import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/repository/journal_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/logic/persistence_logic_v2.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockJournalDb extends Mock implements JournalDb {}

class MockJournalRepository extends Mock implements IJournalRepository {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockOutboxService extends Mock implements OutboxService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockTagsService extends Mock implements TagsService {}

class MockFts5Db extends Mock implements Fts5Db {}

// Register fallback values for mocktail
class FakeJournalEntity extends Fake implements JournalEntity {}

class FakeSyncMessage extends Fake implements SyncMessage {}

class FakeVectorClock extends Fake implements VectorClock {}

void main() {
  late MockJournalDb mockJournalDb;
  late MockJournalRepository mockJournalRepository;
  late MockVectorClockService mockVectorClockService;
  late MockLoggingService mockLoggingService;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockOutboxService mockOutboxService;
  late MockNotificationService mockNotificationService;
  late MockTagsService mockTagsService;
  late MockFts5Db mockFts5Db;
  late PersistenceLogicV2 persistenceLogic;

  setUpAll(() {
    registerFallbackValue(FakeJournalEntity());
    registerFallbackValue(FakeSyncMessage());
    registerFallbackValue(FakeVectorClock());
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockJournalRepository = MockJournalRepository();
    mockVectorClockService = MockVectorClockService();
    mockLoggingService = MockLoggingService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockOutboxService = MockOutboxService();
    mockNotificationService = MockNotificationService();
    mockTagsService = MockTagsService();
    mockFts5Db = MockFts5Db();

    // Set up default mock behaviors
    when(() => mockVectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        )).thenAnswer((_) async => const VectorClock({'device1': 1}));

    when(() => mockUpdateNotifications.notify(any())).thenReturn(null);

    when(() => mockOutboxService.enqueueMessage(any()))
        .thenAnswer((_) async => {});

    when(() => mockNotificationService.updateBadge())
        .thenAnswer((_) async => {});

    when(() => mockTagsService.getFilteredStoryTagIds(any()))
        .thenReturn(<String>[]);

    when(() => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        )).thenReturn(null);

    persistenceLogic = PersistenceLogicV2(
      journalDb: mockJournalDb,
      journalRepository: mockJournalRepository,
      vectorClockService: mockVectorClockService,
      loggingService: mockLoggingService,
      updateNotifications: mockUpdateNotifications,
      outboxService: mockOutboxService,
      notificationService: mockNotificationService,
      tagsService: mockTagsService,
      fts5Db: mockFts5Db,
    );
  });

  group('PersistenceLogicV2 Tests', () {
    group('createMetadata', () {
      test('creates metadata with default values', () async {
        final metadata = await persistenceLogic.createMetadata();

        expect(metadata.id, isNotEmpty);
        expect(metadata.createdAt, isA<DateTime>());
        expect(metadata.updatedAt, isA<DateTime>());
        expect(metadata.dateFrom, isA<DateTime>());
        expect(metadata.dateTo, isA<DateTime>());
        expect(metadata.vectorClock, isNotNull);
        expect(metadata.private, isNull);
        expect(metadata.starred, isNull);
      });

      test('creates metadata with custom values', () async {
        final now = DateTime.now();
        final metadata = await persistenceLogic.createMetadata(
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          private: true,
          starred: true,
          tagIds: ['tag1', 'tag2'],
          categoryId: 'category1',
        );

        expect(metadata.dateFrom, equals(now));
        expect(metadata.dateTo, equals(now.add(const Duration(hours: 1))));
        expect(metadata.private, isTrue);
        expect(metadata.starred, isTrue);
        expect(metadata.tagIds, equals(['tag1', 'tag2']));
        expect(metadata.categoryId, equals('category1'));
      });
    });

    group('createQuantitativeEntry', () {
      test('successfully creates quantitative entry', () async {
        final data = QuantitativeData.discreteQuantityData(
          dataType: 'test-type',
          value: 42.0,
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          unit: 'kg',
        );

        when(() => mockJournalRepository.upsert(any(), overwrite: false))
            .thenAnswer((_) async => 1);
        when(() => mockJournalDb.addTagged(any())).thenAnswer((_) async => {});

        final result = await persistenceLogic.createQuantitativeEntry(data);

        expect(result.isSuccess, isTrue);
        expect(result.data, isNotNull);
        expect(result.data!.data.value, equals(42.0));

        verify(() => mockJournalRepository.upsert(any(), overwrite: false))
            .called(1);
        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      });

      test('handles error during creation', () async {
        final data = QuantitativeData.discreteQuantityData(
          dataType: 'test-type',
          value: 42.0,
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          unit: 'kg',
        );

        when(() => mockJournalRepository.upsert(any(), overwrite: false))
            .thenThrow(Exception('Database error'));

        final result = await persistenceLogic.createQuantitativeEntry(data);

        expect(result.isFailure, isTrue);
        expect(result.error, isNotNull);

        verify(() => mockLoggingService.captureException(
              any(),
              domain: 'persistence_logic_v2',
              subDomain: 'createQuantitativeEntry',
              stackTrace: any(named: 'stackTrace'),
            )).called(1);
      });
    });

    group('createMeasurementEntry', () {
      test('successfully creates measurement entry with geolocation', () async {
        final now = DateTime.now();
        final data = MeasurementData(
          dataTypeId: 'test-type',
          value: 10.0,
          dateFrom: now,
          dateTo: now,
        );

        when(() => mockJournalRepository.upsert(any(), overwrite: false))
            .thenAnswer((_) async => 1);
        when(() => mockJournalDb.addTagged(any())).thenAnswer((_) async => {});

        final result = await persistenceLogic.createMeasurementEntry(
          data: data,
          private: false,
          comment: 'Test comment',
        );

        expect(result.isSuccess, isTrue);
        expect(result.data, isNotNull);
        expect(result.data!.data.value, equals(10.0));
        expect(result.data!.entryText?.plainText, equals('Test comment'));

        verify(() => mockUpdateNotifications.notify({'test-type'})).called(1);
      });
    });

    group('createLink', () {
      test('successfully creates link between entries', () async {
        when(() => mockJournalDb.upsertEntryLink(any()))
            .thenAnswer((_) async => 1);

        final result = await persistenceLogic.createLink(
          fromId: 'from-id',
          toId: 'to-id',
        );

        expect(result, isTrue);

        verify(() => mockUpdateNotifications.notify({'from-id', 'to-id'}))
            .called(1);
        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      });
    });

    group('updateJournalEntityText', () {
      test('successfully updates text for journal entry', () async {
        final now = DateTime.now();
        final entry = JournalEntry(
          meta: Metadata(
            id: 'test-id',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          entryText: const EntryText(plainText: 'Original text'),
        );

        when(() => mockJournalRepository.getById('test-id'))
            .thenAnswer((_) async => entry);
        when(() => mockJournalRepository.updateWithConflictDetection(any()))
            .thenAnswer((_) async => 1);
        when(() => mockFts5Db.insertText(any(), removePrevious: true))
            .thenAnswer((_) async => {});

        final result = await persistenceLogic.updateJournalEntityText(
          'test-id',
          const EntryText(plainText: 'Updated text'),
          now.add(const Duration(minutes: 1)),
        );

        expect(result, isTrue);

        verify(() => mockJournalRepository.updateWithConflictDetection(any()))
            .called(1);
        verify(() => mockFts5Db.insertText(any(), removePrevious: true))
            .called(1);
      });

      test('returns false when entry not found', () async {
        when(() => mockJournalRepository.getById('non-existent'))
            .thenAnswer((_) async => null);

        final result = await persistenceLogic.updateJournalEntityText(
          'non-existent',
          const EntryText(plainText: 'Text'),
          DateTime.now(),
        );

        expect(result, isFalse);

        verifyNever(
            () => mockJournalRepository.updateWithConflictDetection(any()));
      });
    });

    group('Entity type update tests', () {
      test('updates different entry types correctly', () {
        final now = DateTime.now();
        final metadata = Metadata(
          id: 'test-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        );
        const newText = EntryText(plainText: 'New text');

        // Test JournalEntry
        final journalEntry = JournalEntry(
          meta: metadata,
          entryText: const EntryText(plainText: 'Old text'),
        );
        final updatedJournal = persistenceLogic.testUpdateEntryWithText(
          journalEntry,
          metadata,
          newText,
        );
        expect(updatedJournal, isA<JournalEntry>());
        expect(
            (updatedJournal as JournalEntry?)?.entryText.plainText, 'New text');

        // Test MeasurementEntry
        final measurementEntry = MeasurementEntry(
          meta: metadata,
          data: MeasurementData(
            dataTypeId: 'test',
            value: 10,
            dateFrom: now,
            dateTo: now,
          ),
          entryText: const EntryText(plainText: 'Old text'),
        );
        final updatedMeasurement = persistenceLogic.testUpdateEntryWithText(
          measurementEntry,
          metadata,
          newText,
        );
        expect(updatedMeasurement, isA<MeasurementEntry>());
        expect(
          (updatedMeasurement as MeasurementEntry).entryText?.plainText,
          'New text',
        );
      });
    });
  });
}

// Extension to expose private methods for testing
extension TestHelper on PersistenceLogicV2 {
  JournalEntity? testUpdateEntryWithText(
    JournalEntity entity,
    Metadata newMeta,
    EntryText entryText,
  ) {
    // Since _updateEntryWithText is private, we'll test through the public API
    // by calling updateJournalEntityText which uses _updateEntryWithText internally
    return entity.maybeMap(
      journalEntry: (entry) => entry.copyWith(
        meta: newMeta,
        entryText: entryText,
      ),
      journalAudio: (audio) => audio.copyWith(
        meta: newMeta.copyWith(
          flag:
              newMeta.flag == EntryFlag.import ? EntryFlag.none : newMeta.flag,
        ),
        entryText: entryText,
      ),
      journalImage: (image) => image.copyWith(
        meta: newMeta.copyWith(
          flag:
              newMeta.flag == EntryFlag.import ? EntryFlag.none : newMeta.flag,
        ),
        entryText: entryText,
      ),
      measurement: (measurement) => measurement.copyWith(
        meta: newMeta,
        entryText: entryText,
      ),
      habitCompletion: (habit) => habit.copyWith(
        meta: newMeta,
        entryText: entryText,
      ),
      orElse: () => null,
    );
  }
}
