import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/time_entry_update_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late MockTimeService mockTimeService;
  late MockDomainLogger mockDomainLogger;
  late TimeEntryUpdateHandler handler;

  const sourceTaskId = 'source-task-001';
  const entryId = 'entry-001';

  JournalEntry makeEntry({
    String id = entryId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String text = 'Original notes [generated]',
  }) {
    final start = dateFrom ?? DateTime(2026, 4, 15, 13);
    return JournalEntry(
      meta: Metadata(
        id: id,
        dateFrom: start,
        dateTo: dateTo ?? start.add(const Duration(hours: 1)),
        createdAt: DateTime(2026, 4, 15, 12),
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
      entryText: EntryText(plainText: text),
    );
  }

  Task makeTask({String id = 'task-entity'}) {
    return Task(
      meta: Metadata(
        id: id,
        dateFrom: DateTime(2026, 4, 15),
        dateTo: DateTime(2026, 4, 15),
        createdAt: DateTime(2026, 4, 15),
        updatedAt: DateTime(2026, 4, 15),
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: id,
          createdAt: DateTime(2026, 4, 15),
          utcOffset: 0,
        ),
        dateFrom: DateTime(2026, 4, 15),
        dateTo: DateTime(2026, 4, 15),
        statusHistory: [],
        title: 'Not a time entry',
      ),
    );
  }

  void stubEntry(JournalEntry entry) {
    when(
      () => mockJournalDb.journalEntityById(entry.meta.id),
    ).thenAnswer((_) async => entry);
    when(
      () => mockJournalDb.getLinkedEntities(sourceTaskId),
    ).thenAnswer((_) async => [entry]);
  }

  setUp(() async {
    await setUpTestGetIt();

    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    mockTimeService = MockTimeService();
    mockDomainLogger = MockDomainLogger();

    handler = TimeEntryUpdateHandler(
      persistenceLogic: mockPersistenceLogic,
      journalDb: mockJournalDb,
      timeService: mockTimeService,
      domainLogger: mockDomainLogger,
    );

    when(() => mockTimeService.getCurrent()).thenReturn(null);
    when(
      () => mockPersistenceLogic.updateJournalEntry(
        journalEntityId: any(named: 'journalEntityId'),
        entryText: any(named: 'entryText'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
  });

  tearDown(tearDownTestGetIt);

  group('TimeEntryUpdateHandler', () {
    group('validation', () {
      test('returns failure when entryId is missing', () async {
        final result = await handler.handle(sourceTaskId, {
          'summary': 'Updated notes',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Missing or invalid entryId');
      });

      test('returns failure when entryId is not a string', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': 42,
          'summary': 'Updated notes',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Missing or invalid entryId');
      });

      test('returns failure when no changes are specified', () async {
        final result = await handler.handle(sourceTaskId, {'entryId': entryId});

        expect(result.success, isFalse);
        expect(result.errorMessage, 'No changes specified');
      });

      test('returns failure when summary is empty', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': '   ',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Missing, empty, or too-long summary');
      });

      test('returns failure when summary exceeds 500 characters', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'x' * 501,
        });

        expect(result.success, isFalse);
        expect(result.output, contains('500 characters'));
      });

      test('returns failure when summary is not a string', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 99,
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Missing, empty, or too-long summary');
      });

      test('returns failure when startTime is unparseable', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'startTime': 'not-a-date',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Unparseable startTime');
      });

      test('returns failure when startTime is empty', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'startTime': '',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Missing or invalid startTime');
        expect(result.output, contains('explicit local time'));
      });

      test('returns failure when startTime has invalid type', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'startTime': 42,
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Missing or invalid startTime');
      });

      test('returns failure when endTime has timezone suffix', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'endTime': '2026-04-15T14:00:00Z',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Unparseable endTime');
      });

      test('returns failure when endTime has invalid type', () async {
        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'endTime': true,
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Missing or invalid endTime');
      });

      test('returns failure when entry is not found', () async {
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Entry not found');
      });

      test('returns failure when entry is not a JournalEntry', () async {
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => makeTask(id: entryId));

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Unsupported entry type');
      });

      test('returns failure when entry is not linked from this task', () async {
        final entry = makeEntry();
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => entry);
        when(
          () => mockJournalDb.getLinkedEntities(sourceTaskId),
        ).thenAnswer((_) async => [makeEntry(id: 'other-entry')]);

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Entry is not linked from source task');
        verifyNever(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: any(named: 'journalEntityId'),
            entryText: any(named: 'entryText'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        );
      });

      test('returns failure when entry is the active timer', () async {
        final entry = makeEntry();
        stubEntry(entry);
        when(() => mockTimeService.getCurrent()).thenReturn(entry);

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Entry is the active timer');
        verifyNever(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: any(named: 'journalEntityId'),
            entryText: any(named: 'entryText'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        );
      });

      test(
        'returns failure when resolved endTime is not after startTime',
        () async {
          stubEntry(makeEntry());

          final result = await handler.handle(sourceTaskId, {
            'entryId': entryId,
            'endTime': '2026-04-15T12:30:00',
          });

          expect(result.success, isFalse);
          expect(result.errorMessage, 'endTime is not after startTime');
        },
      );
    });

    group('updates', () {
      test('updates text only with generated suffix', () async {
        stubEntry(makeEntry());

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Added rollback discussion',
        });

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, entryId);

        final captured = verify(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: entryId,
            entryText: captureAny(named: 'entryText'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        )..called(1);
        expect(
          (captured.captured.single as EntryText).plainText,
          'Added rollback discussion [generated]',
        );
      });

      test('updates dateFrom only', () async {
        stubEntry(makeEntry());

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'startTime': '2026-04-15T12:30:00',
        });

        expect(result.success, isTrue);
        verify(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: entryId,
            dateFrom: DateTime(2026, 4, 15, 12, 30),
          ),
        ).called(1);
      });

      test('trims surrounding whitespace from datetime arguments', () async {
        stubEntry(makeEntry());

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'startTime': ' 2026-04-15T12:30:00 ',
          'endTime': ' 2026-04-15T14:45:00 ',
        });

        expect(result.success, isTrue);
        verify(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: entryId,
            dateFrom: DateTime(2026, 4, 15, 12, 30),
            dateTo: DateTime(2026, 4, 15, 14, 45),
          ),
        ).called(1);
      });

      test('updates dateTo only', () async {
        stubEntry(makeEntry());

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'endTime': '2026-04-15T14:45:00',
        });

        expect(result.success, isTrue);
        verify(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: entryId,
            dateTo: DateTime(2026, 4, 15, 14, 45),
          ),
        ).called(1);
      });

      test('updates text, dateFrom, and dateTo together', () async {
        stubEntry(makeEntry());

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'startTime': '2026-04-15T13:30:00',
          'endTime': '2026-04-15T15:15:00',
          'summary': 'Workshop plus token budgets',
        });

        expect(result.success, isTrue);
        verify(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: entryId,
            entryText: any(named: 'entryText'),
            dateFrom: DateTime(2026, 4, 15, 13, 30),
            dateTo: DateTime(2026, 4, 15, 15, 15),
          ),
        ).called(1);
      });

      test('accepts future and midnight-spanning edits', () async {
        stubEntry(
          makeEntry(
            dateFrom: DateTime(2026, 4, 15, 23),
            dateTo: DateTime(2026, 4, 16),
          ),
        );

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'startTime': '2027-01-01T23:30:00',
          'endTime': '2027-01-02T00:30:00',
        });

        expect(result.success, isTrue);
        verify(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: entryId,
            dateFrom: DateTime(2027, 1, 1, 23, 30),
            dateTo: DateTime(2027, 1, 2, 0, 30),
          ),
        ).called(1);
      });

      test('succeeds without a domain logger', () async {
        stubEntry(makeEntry());

        final handlerWithoutLogger = TimeEntryUpdateHandler(
          persistenceLogic: mockPersistenceLogic,
          journalDb: mockJournalDb,
          timeService: mockTimeService,
        );

        final result = await handlerWithoutLogger.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'No logger configured',
        });

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, entryId);
      });

      test('returns failure when persistence fails', () async {
        stubEntry(makeEntry());
        when(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: any(named: 'journalEntityId'),
            entryText: any(named: 'entryText'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => false);

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.success, isFalse);
        expect(result.errorMessage, 'updateJournalEntry returned false');
      });
    });
  });
}
