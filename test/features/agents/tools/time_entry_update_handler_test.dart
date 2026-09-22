import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/time_entry_update_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import 'time_entry_update_handler_test_helpers.dart';

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

      glados.Glados(
        glados.any.timeEntryUpdateScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated validation, linkage, range, and persistence semantics',
        (scenario) async {
          final localPersistenceLogic = MockPersistenceLogic();
          final localJournalDb = MockJournalDb();
          final localTimeService = MockTimeService();
          final localDomainLogger = MockDomainLogger();
          final localHandler = TimeEntryUpdateHandler(
            persistenceLogic: localPersistenceLogic,
            journalDb: localJournalDb,
            timeService: localTimeService,
            domainLogger: localDomainLogger,
          );

          final entry = makeEntry(
            dateFrom: GeneratedTimeEntryUpdateScenario.existingStart,
            dateTo: scenario.existingEnd,
          );
          final otherEntry = makeEntry(id: 'other-entry');

          when(
            () => localJournalDb.journalEntityById(entryId),
          ).thenAnswer((_) async => entry);
          when(
            () => localJournalDb.getLinkedEntities(sourceTaskId),
          ).thenAnswer(
            (_) async => scenario.isLinked ? [entry] : [otherEntry],
          );
          when(
            localTimeService.getCurrent,
          ).thenReturn(scenario.isActiveTimer ? entry : null);
          when(
            () => localPersistenceLogic.updateJournalEntry(
              journalEntityId: any(named: 'journalEntityId'),
              entryText: any(named: 'entryText'),
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
            ),
          ).thenAnswer((_) async => scenario.persistenceSucceeds);
          when(
            () => localDomainLogger.log(
              any(),
              any(),
              subDomain: any(named: 'subDomain'),
            ),
          ).thenReturn(null);

          final result = await withClock(
            Clock.fixed(GeneratedTimeEntryUpdateScenario.now),
            () => localHandler.handle(sourceTaskId, scenario.args),
          );

          if (!scenario.shouldAttemptWrite) {
            expect(result.success, isFalse, reason: '$scenario');
            expect(result.errorMessage, isNotNull, reason: '$scenario');
            expect(
              result.nonRetryable,
              scenario.failsOnArguments,
              reason: '$scenario',
            );
            verifyNever(() => localTimeService.updateCurrent(any()));
            verifyNever(
              () => localPersistenceLogic.updateJournalEntry(
                journalEntityId: any(named: 'journalEntityId'),
                entryText: any(named: 'entryText'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
              ),
            );
            return;
          }

          expect(result.success, scenario.shouldSucceed, reason: '$scenario');
          verify(
            () => localPersistenceLogic.updateJournalEntry(
              journalEntityId: entryId,
              entryText: scenario.expectedEntryText,
              dateFrom: scenario.parsedStart,
              dateTo: scenario.expectedDateTo,
            ),
          ).called(1);
          expect(result.nonRetryable, isFalse, reason: '$scenario');

          // Only a successful write to a timer running here refreshes the
          // in-memory snapshot the running indicator reads.
          if (scenario.shouldSucceed && scenario.isActiveTimer) {
            final snapshot =
                verify(
                      () => localTimeService.updateCurrent(captureAny()),
                    ).captured.single
                    as JournalEntry;
            expect(
              snapshot.entryText,
              scenario.expectedEntryText,
              reason: '$scenario',
            );
            expect(
              snapshot.meta.dateTo,
              GeneratedTimeEntryUpdateScenario.now,
              reason: '$scenario',
            );
          } else {
            verifyNever(() => localTimeService.updateCurrent(any()));
          }

          if (scenario.shouldSucceed) {
            expect(result.mutatedEntityId, entryId, reason: '$scenario');
            expect(
              result.output,
              contains('Updated time entry'),
              reason: '$scenario',
            );
          } else {
            expect(
              result.errorMessage,
              'updateJournalEntry returned false',
              reason: '$scenario',
            );
          }
        },
        tags: 'glados',
      );
    });

    group('retry semantics', () {
      // Each of these is decided by the arguments alone, so a confirmed
      // proposal carrying them can never apply and is retracted.
      final argumentFailures = <String, Map<String, dynamic>>{
        'missing entryId': {'summary': 'x'},
        'no changes': {'entryId': entryId},
        'blank summary': {'entryId': entryId, 'summary': ' '},
        'blank startTime': {'entryId': entryId, 'startTime': ' '},
        'unparseable startTime': {'entryId': entryId, 'startTime': 'soon'},
        'non-string endTime': {'entryId': entryId, 'endTime': 7},
        'unparseable endTime': {'entryId': entryId, 'endTime': '14:00Z'},
      };

      for (final MapEntry(key: label, value: args)
          in argumentFailures.entries) {
        test('an invalid argument is not retryable: $label', () async {
          final result = await handler.handle(sourceTaskId, args);

          expect(result.success, isFalse);
          expect(result.nonRetryable, isTrue);
        });
      }

      test('an entry that is not a journal entry is not retryable', () async {
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => makeTask(id: entryId));

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.errorMessage, 'Unsupported entry type');
        expect(result.nonRetryable, isTrue);
      });

      test('an entry not synced to this device yet stays retryable', () async {
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.errorMessage, 'Entry not found');
        expect(result.output, contains('not synced to this device yet'));
        expect(result.nonRetryable, isFalse);
      });

      test('an entry whose link has not synced yet stays retryable', () async {
        when(
          () => mockJournalDb.journalEntityById(entryId),
        ).thenAnswer((_) async => makeEntry());
        when(
          () => mockJournalDb.getLinkedEntities(sourceTaskId),
        ).thenAnswer((_) async => []);

        final result = await handler.handle(sourceTaskId, {
          'entryId': entryId,
          'summary': 'Updated notes',
        });

        expect(result.errorMessage, 'Entry is not linked from source task');
        expect(result.nonRetryable, isFalse);
      });

      test(
        'a range that depends on the stored entry stays retryable',
        () async {
          stubEntry(makeEntry());

          final result = await handler.handle(sourceTaskId, {
            'entryId': entryId,
            'endTime': '2026-04-15T12:30:00',
          });

          expect(result.errorMessage, 'endTime is not after startTime');
          expect(result.nonRetryable, isFalse);
        },
      );

      test('a failed write stays retryable', () async {
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

        expect(result.errorMessage, 'updateJournalEntry returned false');
        expect(result.nonRetryable, isFalse);
      });
    });

    group('running timer', () {
      final now = DateTime(2026, 4, 15, 15, 42);

      Future<ToolExecutionResult> handleAt(Map<String, dynamic> args) =>
          withClock(
            Clock.fixed(now),
            () => handler.handle(sourceTaskId, args),
          );

      test(
        'rewrites the text of a timer running on this device, stamping its '
        'live end and refreshing the snapshot the indicator reads',
        () async {
          final running = makeEntry(
            dateTo: DateTime(2026, 4, 15, 13),
            text: '',
          );
          stubEntry(running);
          when(() => mockTimeService.getCurrent()).thenReturn(running);

          final result = await handleAt({
            'entryId': entryId,
            'summary': 'Drafted the rollback plan',
          });

          expect(result.success, isTrue);
          expect(result.mutatedEntityId, entryId);
          expect(result.output, 'Updated time entry (13:00–15:42)');
          verify(
            () => mockPersistenceLogic.updateJournalEntry(
              journalEntityId: entryId,
              entryText: const EntryText(
                plainText: 'Drafted the rollback plan [generated]',
              ),
              dateTo: now,
            ),
          ).called(1);

          final snapshot =
              verify(
                    () => mockTimeService.updateCurrent(captureAny()),
                  ).captured.single
                  as JournalEntry;
          expect(
            snapshot.entryText?.plainText,
            'Drafted the rollback plan [generated]',
          );
          expect(snapshot.meta.id, entryId);
          expect(snapshot.meta.dateFrom, running.meta.dateFrom);
          expect(snapshot.meta.dateTo, now);
          expect(snapshot.meta.updatedAt, now);
        },
      );

      test(
        'applies a text update just the same when the timer is not running '
        'on this device — stopped, restarted, or ticking elsewhere',
        () async {
          stubEntry(makeEntry());

          final result = await handleAt({
            'entryId': entryId,
            'summary': 'Drafted the rollback plan',
          });

          expect(result.success, isTrue);
          // The stored end is left alone: this device does not own a live one.
          verify(
            () => mockPersistenceLogic.updateJournalEntry(
              journalEntityId: entryId,
              entryText: const EntryText(
                plainText: 'Drafted the rollback plan [generated]',
              ),
            ),
          ).called(1);
          verifyNever(() => mockTimeService.updateCurrent(any()));
        },
      );

      test(
        'applies a text update to a timer ticking on another device, whose '
        'synced entry has no length yet',
        () async {
          // The reported case: the suggestion was written on the desktop
          // while its timer ran; the phone confirms it, holding only the
          // synced entry — started at 14:10 and, as far as it knows, ended
          // then too.
          stubEntry(
            makeEntry(
              dateFrom: DateTime(2026, 4, 15, 14, 10),
              dateTo: DateTime(2026, 4, 15, 14, 10),
              text: '',
            ),
          );

          final result = await handleAt({
            'entryId': entryId,
            'summary': 'Drafted the rollback plan',
          });

          expect(result.success, isTrue);
          verify(
            () => mockPersistenceLogic.updateJournalEntry(
              journalEntityId: entryId,
              entryText: const EntryText(
                plainText: 'Drafted the rollback plan [generated]',
              ),
            ),
          ).called(1);
        },
      );

      test(
        'still checks a range edit against the entry it lands on',
        () async {
          stubEntry(
            makeEntry(
              dateFrom: DateTime(2026, 4, 15, 14, 10),
              dateTo: DateTime(2026, 4, 15, 14, 10),
            ),
          );

          final result = await handleAt({
            'entryId': entryId,
            'endTime': '2026-04-15T14:00:00',
          });

          expect(result.errorMessage, 'endTime is not after startTime');
        },
      );

      test(
        'leaves the snapshot alone when a different entry is running here',
        () async {
          stubEntry(makeEntry());
          when(
            () => mockTimeService.getCurrent(),
          ).thenReturn(makeEntry(id: 'other-timer'));

          final result = await handleAt({
            'entryId': entryId,
            'summary': 'Drafted the rollback plan',
          });

          expect(result.success, isTrue);
          verifyNever(() => mockTimeService.updateCurrent(any()));
        },
      );

      for (final field in ['startTime', 'endTime']) {
        test(
          'refuses a $field edit while the timer runs here, retryably',
          () async {
            final running = makeEntry();
            stubEntry(running);
            when(() => mockTimeService.getCurrent()).thenReturn(running);

            final result = await handleAt({
              'entryId': entryId,
              'summary': 'Drafted the rollback plan',
              field: '2026-04-15T12:30:00',
            });

            expect(result.success, isFalse);
            expect(result.errorMessage, 'Running timer range is locked');
            expect(result.output, contains('until the timer is stopped'));
            // Stopping the timer makes the same proposal applicable.
            expect(result.nonRetryable, isFalse);
            verifyNever(
              () => mockPersistenceLogic.updateJournalEntry(
                journalEntityId: any(named: 'journalEntityId'),
                entryText: any(named: 'entryText'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
              ),
            );
          },
        );
      }

      test('keeps the snapshot untouched when the write fails', () async {
        final running = makeEntry();
        stubEntry(running);
        when(() => mockTimeService.getCurrent()).thenReturn(running);
        when(
          () => mockPersistenceLogic.updateJournalEntry(
            journalEntityId: any(named: 'journalEntityId'),
            entryText: any(named: 'entryText'),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => false);

        final result = await handleAt({
          'entryId': entryId,
          'summary': 'Drafted the rollback plan',
        });

        expect(result.success, isFalse);
        verifyNever(() => mockTimeService.updateCurrent(any()));
      });
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
        // The success output pins the resolved range in HH:mm–HH:mm form so
        // the wake-visible summary matches what was written.
        expect(result.output, contains('(13:30–15:15)'));
        expect(
          result.output,
          matches(RegExp(r'\(\d{2}:\d{2}–\d{2}:\d{2}\)')),
        );
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
