import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/running_timer_update_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockPersistenceLogic mockPersistenceLogic;
  late MockTimeService mockTimeService;
  late MockDomainLogger mockDomainLogger;
  late RunningTimerUpdateHandler handler;

  const sourceTaskId = 'source-task-001';
  const otherTaskId = 'other-task-999';
  const timerId = 'timer-entry-001';
  const categoryId = 'cat-001';

  final testNow = DateTime(2026, 3, 17, 15, 30);

  Task makeSourceTask({String id = sourceTaskId}) {
    return Task(
      meta: Metadata(
        id: id,
        dateFrom: DateTime(2026, 3, 17),
        dateTo: DateTime(2026, 3, 17),
        createdAt: DateTime(2026, 3, 17),
        updatedAt: DateTime(2026, 3, 17),
        categoryId: categoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: id,
          createdAt: DateTime(2026, 3, 17),
          utcOffset: 0,
        ),
        dateFrom: DateTime(2026, 3, 17),
        dateTo: DateTime(2026, 3, 17),
        statusHistory: [],
        title: 'Source Task',
      ),
    );
  }

  JournalEntry makeRunningTimer({
    String id = timerId,
    String? text,
  }) {
    return JournalEntry(
      meta: Metadata(
        id: id,
        dateFrom: DateTime(2026, 3, 17, 14),
        dateTo: DateTime(2026, 3, 17, 15, 29),
        createdAt: DateTime(2026, 3, 17, 14),
        updatedAt: DateTime(2026, 3, 17, 14),
        categoryId: categoryId,
      ),
      entryText: text == null ? null : EntryText(plainText: text),
    );
  }

  setUp(() async {
    await setUpTestGetIt();

    mockPersistenceLogic = MockPersistenceLogic();
    mockTimeService = MockTimeService();
    mockDomainLogger = MockDomainLogger();

    handler = RunningTimerUpdateHandler(
      persistenceLogic: mockPersistenceLogic,
      timeService: mockTimeService,
      domainLogger: mockDomainLogger,
    );

    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(() => mockTimeService.updateCurrent(any())).thenReturn(null);
  });

  tearDown(tearDownTestGetIt);

  group('RunningTimerUpdateHandler', () {
    test('returns failure when summary is missing', () async {
      final result = await handler.handle(sourceTaskId, {'timerId': timerId});

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing, empty, or too-long summary');
    });

    test('returns failure when summary is empty', () async {
      final result = await handler.handle(
        sourceTaskId,
        {'timerId': timerId, 'summary': '   '},
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing, empty, or too-long summary');
    });

    test('returns failure when summary exceeds 500 characters', () async {
      final result = await handler.handle(
        sourceTaskId,
        {'timerId': timerId, 'summary': 'x' * 501},
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing, empty, or too-long summary');
    });

    test('returns failure when timerId is missing', () async {
      final result = await handler.handle(
        sourceTaskId,
        {'summary': 'Working on API'},
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing or invalid timerId');
    });

    test('returns failure when no timer is active', () async {
      when(() => mockTimeService.getCurrent()).thenReturn(null);

      final result = await handler.handle(
        sourceTaskId,
        {'timerId': timerId, 'summary': 'Working on API'},
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'No active timer');
      verifyNever(
        () => mockPersistenceLogic.updateJournalEntityText(any(), any(), any()),
      );
    });

    test('returns failure when timerId does not match active timer', () async {
      when(() => mockTimeService.getCurrent()).thenReturn(makeRunningTimer());
      when(() => mockTimeService.linkedFrom).thenReturn(makeSourceTask());

      final result = await handler.handle(
        sourceTaskId,
        {'timerId': 'wrong-id', 'summary': 'Working on API'},
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Timer id mismatch');
      verifyNever(
        () => mockPersistenceLogic.updateJournalEntityText(any(), any(), any()),
      );
    });

    test(
      'returns failure when active timer belongs to a different task',
      () async {
        when(() => mockTimeService.getCurrent()).thenReturn(makeRunningTimer());
        when(
          () => mockTimeService.linkedFrom,
        ).thenReturn(makeSourceTask(id: otherTaskId));

        final result = await handler.handle(
          sourceTaskId,
          {'timerId': timerId, 'summary': 'Working on API'},
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Timer source task mismatch');
        verifyNever(
          () =>
              mockPersistenceLogic.updateJournalEntityText(any(), any(), any()),
        );
      },
    );

    test(
      'returns failure when active entity is not a JournalEntry',
      () async {
        // Defensive: TimeService is supposed to always hold a JournalEntry,
        // but if a different JournalEntity subtype somehow ends up there
        // (e.g. via UI state corruption), the handler must refuse cleanly
        // rather than try to update via the wrong code path.
        final notAJournalEntry = JournalEntity.measurement(
          meta: Metadata(
            id: timerId,
            dateFrom: DateTime(2026, 3, 17, 14),
            dateTo: DateTime(2026, 3, 17, 15, 29),
            createdAt: DateTime(2026, 3, 17, 14),
            updatedAt: DateTime(2026, 3, 17, 14),
          ),
          data: MeasurementData(
            dateFrom: DateTime(2026, 3, 17, 14),
            dateTo: DateTime(2026, 3, 17, 14),
            value: 1,
            dataTypeId: 'type-1',
          ),
        );
        when(() => mockTimeService.getCurrent()).thenReturn(notAJournalEntry);
        when(() => mockTimeService.linkedFrom).thenReturn(makeSourceTask());

        final result = await handler.handle(
          sourceTaskId,
          {'timerId': timerId, 'summary': 'Working on API'},
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Unsupported timer entity type');
        verifyNever(
          () =>
              mockPersistenceLogic.updateJournalEntityText(any(), any(), any()),
        );
      },
    );

    test(
      'returns failure when persistence layer reports failure',
      () async {
        when(() => mockTimeService.getCurrent()).thenReturn(makeRunningTimer());
        when(() => mockTimeService.linkedFrom).thenReturn(makeSourceTask());
        when(
          () => mockPersistenceLogic.updateJournalEntityText(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => false);

        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'timerId': timerId, 'summary': 'Working on API'},
          );

          expect(result.success, isFalse);
          expect(
            result.errorMessage,
            'updateJournalEntityText returned false',
          );
          verifyNever(() => mockTimeService.updateCurrent(any()));
        });
      },
    );

    test(
      'persists update with [generated] marker, current dateTo, and refreshes '
      'TimeService snapshot on success',
      () async {
        when(() => mockTimeService.getCurrent()).thenReturn(makeRunningTimer());
        when(() => mockTimeService.linkedFrom).thenReturn(makeSourceTask());
        when(
          () => mockPersistenceLogic.updateJournalEntityText(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'timerId': timerId, 'summary': '  Refined description  '},
          );

          expect(result.success, isTrue);
          expect(result.mutatedEntityId, timerId);
          expect(result.output, contains('Refined description'));

          verify(
            () => mockPersistenceLogic.updateJournalEntityText(
              timerId,
              any(
                that: isA<EntryText>().having(
                  (e) => e.plainText,
                  'plainText',
                  'Refined description [generated]',
                ),
              ),
              testNow,
            ),
          ).called(1);

          verify(
            () => mockTimeService.updateCurrent(
              any(
                that: isA<JournalEntry>()
                    .having(
                      (e) => e.entryText?.plainText,
                      'plainText',
                      'Refined description [generated]',
                    )
                    .having((e) => e.meta.dateTo, 'meta.dateTo', testNow)
                    .having(
                      (e) => e.meta.updatedAt,
                      'meta.updatedAt',
                      testNow,
                    ),
              ),
            ),
          ).called(1);
        });
      },
    );

    test('logs the update on success', () async {
      when(() => mockTimeService.getCurrent()).thenReturn(makeRunningTimer());
      when(() => mockTimeService.linkedFrom).thenReturn(makeSourceTask());
      when(
        () => mockPersistenceLogic.updateJournalEntityText(any(), any(), any()),
      ).thenAnswer((_) async => true);

      await withClock(Clock.fixed(testNow), () async {
        await handler.handle(
          sourceTaskId,
          {'timerId': timerId, 'summary': 'Logged description'},
        );

        verify(
          () => mockDomainLogger.log(
            any(),
            any(that: contains('Updated running timer $timerId')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
      });
    });
  });
}
