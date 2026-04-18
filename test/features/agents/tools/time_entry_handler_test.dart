import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';
import 'package:lotti/features/agents/tools/time_entry_handler.dart';
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
  late TimeEntryHandler handler;

  const sourceTaskId = 'source-task-001';
  const categoryId = 'cat-001';
  // Fixed "now" for all tests: 2026-03-17 at 15:30.
  final testNow = DateTime(2026, 3, 17, 15, 30);

  Task makeSourceTask({String? taskCategoryId = categoryId}) {
    return Task(
      meta: Metadata(
        id: sourceTaskId,
        dateFrom: DateTime(2026, 3, 17),
        dateTo: DateTime(2026, 3, 17),
        createdAt: DateTime(2026, 3, 17),
        updatedAt: DateTime(2026, 3, 17),
        categoryId: taskCategoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: sourceTaskId,
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

  JournalEntry makeJournalEntry(String id) {
    return JournalEntry(
      meta: Metadata(
        id: id,
        dateFrom: DateTime(2026, 3, 17, 14),
        dateTo: DateTime(2026, 3, 17, 14),
        createdAt: DateTime(2026, 3, 17, 14),
        updatedAt: DateTime(2026, 3, 17, 14),
        categoryId: categoryId,
      ),
      entryText: const EntryText(plainText: 'test'),
    );
  }

  setUp(() async {
    final mocks = await setUpTestGetIt();

    mockJournalDb = mocks.journalDb;
    mockPersistenceLogic = MockPersistenceLogic();
    mockTimeService = MockTimeService();
    mockDomainLogger = MockDomainLogger();

    handler = TimeEntryHandler(
      persistenceLogic: mockPersistenceLogic,
      journalDb: mockJournalDb,
      timeService: mockTimeService,
      domainLogger: mockDomainLogger,
    );

    // Default stubs.
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
  });

  tearDown(tearDownTestGetIt);

  group('TimeEntryHandler', () {
    group('validation', () {
      test('returns failure when summary is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'startTime': '2026-03-17T14:00:00'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"summary" must be a non-empty'));
        expect(result.errorMessage, 'Missing, empty, or too-long summary');
      });

      test('returns failure when summary is empty', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'startTime': '2026-03-17T14:00:00', 'summary': '   '},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"summary" must be a non-empty'));
      });

      test('returns failure when summary exceeds 500 characters', () async {
        final result = await handler.handle(
          sourceTaskId,
          {
            'startTime': '2026-03-17T14:00:00',
            'summary': 'x' * 501,
          },
        );

        expect(result.success, isFalse);
        expect(result.output, contains('500 characters'));
        expect(result.errorMessage, 'Missing, empty, or too-long summary');
      });

      test('returns failure when startTime is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'summary': 'Worked on API'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('valid ISO 8601'));
        expect(result.errorMessage, 'Missing or invalid startTime');
      });

      test('returns failure when startTime is unparseable', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'startTime': 'not-a-date', 'summary': 'Worked on API'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('valid ISO 8601'));
        expect(result.errorMessage, 'Unparseable startTime');
      });

      test('returns failure when startTime is date-only', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'startTime': '2026-03-17', 'summary': 'Worked on API'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('valid ISO 8601'));
        expect(result.errorMessage, 'Unparseable startTime');
      });

      test('returns failure when startTime has a timezone suffix', () async {
        final result = await handler.handle(
          sourceTaskId,
          {
            'startTime': '2026-03-17T14:00:00Z',
            'summary': 'Worked on API',
          },
        );

        expect(result.success, isFalse);
        expect(result.output, contains('valid ISO 8601'));
        expect(result.errorMessage, 'Unparseable startTime');
      });

      test('returns failure when startTime is not today', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-16T14:00:00',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains("today's date"));
          expect(result.errorMessage, 'startTime is not today');
        });
      });

      test('returns failure when endTime is unparseable', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': 'bad-time',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('"endTime" must be a valid'));
          expect(result.errorMessage, 'Unparseable endTime');
        });
      });

      test('returns failure when endTime has a timezone suffix', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:00:00+01:00',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('"endTime" must be a valid'));
          expect(result.errorMessage, 'Unparseable endTime');
        });
      });

      test('returns failure when endTime has invalid type', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': 123,
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('"endTime" must be a valid'));
          expect(result.errorMessage, 'Missing or invalid endTime');
        });
      });

      test('returns failure when endTime is before startTime', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T13:00:00',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('endTime must be after startTime'));
          expect(result.errorMessage, 'endTime is not after startTime');
        });
      });

      test('returns failure when endTime equals startTime', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T14:00:00',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('endTime must be after startTime'));
        });
      });

      test('returns failure when endTime is on a different day', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-18T01:00:00',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('same day'));
          expect(result.errorMessage, 'endTime is on a different day');
        });
      });

      test('returns failure when endTime is in the future', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T16:00:00',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('must not be after the current time'));
          expect(result.errorMessage, 'endTime is after current time');
        });
      });

      test('returns failure when startTime is in the future', () async {
        // testNow = 2026-03-17T15:30 — 23:00 is today but in the future.
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T23:00:00',
              'summary': 'Future work',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('must not be in the future'));
          expect(result.errorMessage, 'startTime is in the future');
        });
      });

      test('returns failure when timer is already running', () async {
        when(
          () => mockTimeService.getCurrent(),
        ).thenReturn(makeJournalEntry('existing-timer'));

        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'summary': 'Start working',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('timer is already running'));
          expect(result.errorMessage, 'Timer already running');
        });
      });

      test('returns failure when source task is not found', () async {
        when(() => mockTimeService.getCurrent()).thenReturn(null);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => null);

        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:00:00',
              'summary': 'Worked on API',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('not found or not a Task'));
          expect(result.errorMessage, 'Source task lookup failed');
        });
      });
    });

    group('completed session', () {
      setUp(() {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => makeSourceTask());

        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (inv) async => Metadata(
            id: 'new-entry-001',
            dateFrom: inv.namedArguments[#dateFrom] as DateTime,
            dateTo:
                (inv.namedArguments[#dateTo] as DateTime?) ??
                (inv.namedArguments[#dateFrom] as DateTime),
            createdAt: testNow,
            updatedAt: testNow,
            categoryId: inv.namedArguments[#categoryId] as String?,
          ),
        );

        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockTimeService.getCurrent()).thenReturn(null);
      });

      test('returns failure when createDbEntity returns false', () async {
        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        ).thenAnswer((_) async => false);

        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:00:00',
              'summary': 'Persisted session',
            },
          );

          expect(result.success, isFalse);
          expect(result.output, contains('failed to persist'));
          expect(result.errorMessage, 'createDbEntity returned false');

          // Timer must not start when persistence fails.
          verifyNever(() => mockTimeService.start(any(), any()));
        });
      });

      test(
        'creates entry with correct dateFrom and dateTo in a single write',
        () async {
          await withClock(Clock.fixed(testNow), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-03-17T14:00:00',
                'endTime': '2026-03-17T15:00:00',
                'summary': 'Worked on API integration',
              },
            );

            expect(result.success, isTrue);
            expect(result.mutatedEntityId, 'new-entry-001');
            expect(result.output, contains('14:00–15:00'));
            expect(result.output, contains('Worked on API integration'));

            // Verify createMetadata was called with both dateFrom and dateTo
            // so the correct time range is written in a single DB operation.
            verify(
              () => mockPersistenceLogic.createMetadata(
                dateFrom: DateTime(2026, 3, 17, 14),
                dateTo: DateTime(2026, 3, 17, 15),
                categoryId: categoryId,
              ),
            ).called(1);

            // Verify createDbEntity was called with the generated marker
            // appended to the plain text, and with the correct linkedId.
            verify(
              () => mockPersistenceLogic.createDbEntity(
                any(
                  that: isA<JournalEntry>().having(
                    (e) => e.entryText?.plainText,
                    'plainText',
                    endsWith(' [generated]'),
                  ),
                ),
                linkedId: sourceTaskId,
              ),
            ).called(1);

            // Verify TimeService was NOT started.
            verifyNever(() => mockTimeService.start(any(), any()));
          });
        },
      );

      test('inherits category from source task', () async {
        await withClock(Clock.fixed(testNow), () async {
          await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:00:00',
              'summary': 'Session work',
            },
          );

          verify(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              categoryId: categoryId,
            ),
          ).called(1);
        });
      });

      test('trims summary whitespace', () async {
        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:00:00',
              'summary': '  Padded summary  ',
            },
          );

          expect(result.success, isTrue);
          expect(result.output, contains('Padded summary'));
        });
      });

      test(
        'validates completed sessions against the wake timestamp argument',
        () async {
          await withClock(Clock.fixed(DateTime(2026, 3, 18, 0, 5)), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-03-17T23:00:00',
                'endTime': '2026-03-17T23:45:00',
                'summary': 'Late session',
                timeEntryReferenceTimestampArg: '2026-03-17T23:55:00',
              },
            );

            expect(result.success, isTrue);
            expect(result.output, contains('23:00–23:45'));
          });
        },
      );

      test(
        'accepts completed session whose endTime extends past the wake '
        'timestamp (user is the authority at approval time)',
        () async {
          // Reproduces the P0 scenario: agent wakes at 11:48:23, model
          // rounds/estimates endTime past wake, user approves later. The
          // "not in the future" cutoff must not apply at approval time.
          await withClock(Clock.fixed(DateTime(2026, 4, 18, 12, 54)), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-04-18T11:13:50',
                'endTime': '2026-04-18T11:48:50',
                'summary': 'Design walkthrough',
                timeEntryReferenceTimestampArg: '2026-04-18T11:48:23.029723',
              },
            );

            expect(result.success, isTrue);
            expect(result.output, contains('11:13–11:48'));
          });
        },
      );

      test(
        'accepts completed session whose endTime is in the actual future at '
        'approval time as long as it stays on the same day',
        () async {
          // Item 23 from the P0 logs: end=13:00, wake=11:48, approval<13:00.
          await withClock(Clock.fixed(DateTime(2026, 4, 18, 12, 57)), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-04-18T11:00:00',
                'endTime': '2026-04-18T13:00:00',
                'summary': 'Comprehensive walkthrough',
                timeEntryReferenceTimestampArg: '2026-04-18T11:48:23.029723',
              },
            );

            expect(result.success, isTrue);
            expect(result.output, contains('11:00–13:00'));
          });
        },
      );

      test(
        'still rejects completed session when endTime spills into the next '
        'day (same-day constraint is preserved)',
        () async {
          await withClock(Clock.fixed(DateTime(2026, 4, 18, 23, 0)), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-04-18T23:30:00',
                'endTime': '2026-04-19T00:30:00',
                'summary': 'Crossing midnight',
                timeEntryReferenceTimestampArg: '2026-04-18T22:00:00',
              },
            );

            expect(result.success, isFalse);
            expect(result.output, contains('same day'));
            expect(result.errorMessage, 'endTime is on a different day');
          });
        },
      );

      test(
        'at wake time (no reference timestamp injected) still rejects '
        'completed session with endTime in the future',
        () async {
          // testNow = 2026-03-17T15:30 — endTime 16:00 is in the future.
          await withClock(Clock.fixed(testNow), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-03-17T14:00:00',
                'endTime': '2026-03-17T16:00:00',
                'summary': 'Would be hallucinated',
              },
            );

            expect(result.success, isFalse);
            expect(result.errorMessage, 'endTime is after current time');
          });
        },
      );
    });

    group('running timer', () {
      setUp(() {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => makeSourceTask());

        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (inv) async => Metadata(
            id: 'timer-entry-001',
            dateFrom: inv.namedArguments[#dateFrom] as DateTime,
            dateTo:
                (inv.namedArguments[#dateTo] as DateTime?) ??
                (inv.namedArguments[#dateFrom] as DateTime),
            createdAt: testNow,
            updatedAt: testNow,
            categoryId: inv.namedArguments[#categoryId] as String?,
          ),
        );

        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockTimeService.getCurrent()).thenReturn(null);
        when(
          () => mockTimeService.start(any(), any()),
        ).thenAnswer((_) async {});
      });

      test(
        'creates entry and starts TimeService with in-memory entity',
        () async {
          await withClock(Clock.fixed(testNow), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-03-17T14:00:00',
                'summary': 'Starting work on feature',
              },
            );

            expect(result.success, isTrue);
            expect(result.mutatedEntityId, 'timer-entry-001');
            expect(result.output, contains('running timer from 14:00'));
            expect(result.output, contains('Starting work on feature'));

            // TimeService.start is called with the in-memory entity — no DB
            // re-fetch needed since TimeService only stores it in memory.
            verify(
              () => mockTimeService.start(any(), any()),
            ).called(1);
          });
        },
      );

      test(
        'returns failure and does not start timer when persistence fails',
        () async {
          when(
            () => mockPersistenceLogic.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
            ),
          ).thenAnswer((_) async => false);

          await withClock(Clock.fixed(testNow), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-03-17T14:00:00',
                'summary': 'Timer that fails to persist',
              },
            );

            expect(result.success, isFalse);
            expect(result.output, contains('failed to persist'));
            verifyNever(() => mockTimeService.start(any(), any()));
          });
        },
      );

      test(
        'returns error with mutatedEntityId when TimeService.start throws',
        () async {
          when(
            () => mockTimeService.start(any(), any()),
          ).thenThrow(StateError('stream already closed'));

          await withClock(Clock.fixed(testNow), () async {
            final result = await handler.handle(
              sourceTaskId,
              {
                'startTime': '2026-03-17T14:00:00',
                'summary': 'Timer start throws',
              },
            );

            // Entry was persisted but timer failed — report error with id so
            // the caller knows the entry exists.
            expect(result.success, isFalse);
            expect(result.errorMessage, 'Timer start failed after persistence');
            expect(result.mutatedEntityId, 'timer-entry-001');
            expect(result.output, contains('saved'));
            expect(result.output, contains('timer'));
          });
        },
      );
    });

    group('domain logging', () {
      setUp(() {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => makeSourceTask());

        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (inv) async => Metadata(
            id: 'log-entry-001',
            dateFrom: inv.namedArguments[#dateFrom] as DateTime,
            dateTo:
                (inv.namedArguments[#dateTo] as DateTime?) ??
                (inv.namedArguments[#dateFrom] as DateTime),
            createdAt: testNow,
            updatedAt: testNow,
            categoryId: categoryId,
          ),
        );

        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockTimeService.getCurrent()).thenReturn(null);
      });

      test('logs completed session creation', () async {
        await withClock(Clock.fixed(testNow), () async {
          await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:00:00',
              'summary': 'Logged session',
            },
          );

          verify(
            () => mockDomainLogger.log(
              any(),
              any(that: contains('completed session')),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
        });
      });

      test('logs running timer creation', () async {
        when(
          () => mockTimeService.start(any(), any()),
        ).thenAnswer((_) async {});

        await withClock(Clock.fixed(testNow), () async {
          await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'summary': 'Timer started',
            },
          );

          verify(
            () => mockDomainLogger.log(
              any(),
              any(that: contains('running timer')),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
        });
      });
    });

    group('category inheritance', () {
      test('passes null categoryId when source has no category', () async {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => makeSourceTask(taskCategoryId: null));

        when(
          () => mockPersistenceLogic.createMetadata(
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (inv) async => Metadata(
            id: 'no-cat-entry',
            dateFrom: inv.namedArguments[#dateFrom] as DateTime,
            dateTo:
                (inv.namedArguments[#dateTo] as DateTime?) ??
                (inv.namedArguments[#dateFrom] as DateTime),
            createdAt: testNow,
            updatedAt: testNow,
          ),
        );

        when(
          () => mockPersistenceLogic.createDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        ).thenAnswer((_) async => true);

        when(() => mockTimeService.getCurrent()).thenReturn(null);

        await withClock(Clock.fixed(testNow), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:00:00',
              'summary': 'No category session',
            },
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockPersistenceLogic.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          )..called(1);
          expect(captured.captured.single, isNull);
        });
      });
    });
  });
}
