import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/running_timer_update_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

enum _GeneratedRunningSummaryShape {
  absent,
  valid,
  paddedValid,
  empty,
  tooLong,
  nonString,
}

enum _GeneratedTimerIdShape {
  absent,
  exact,
  paddedExact,
  wrong,
  empty,
  nonString,
}

enum _GeneratedCurrentTimerShape {
  none,
  journalMatchingId,
  journalDifferentId,
  measurementMatchingId,
}

enum _GeneratedLinkedSourceShape { sameSource, otherSource, none }

class _GeneratedRunningTimerUpdateScenario {
  const _GeneratedRunningTimerUpdateScenario({
    required this.summaryShape,
    required this.timerIdShape,
    required this.currentShape,
    required this.linkedSourceShape,
    required this.persistenceSucceeds,
    required this.seed,
  });

  final _GeneratedRunningSummaryShape summaryShape;
  final _GeneratedTimerIdShape timerIdShape;
  final _GeneratedCurrentTimerShape currentShape;
  final _GeneratedLinkedSourceShape linkedSourceShape;
  final bool persistenceSucceeds;
  final int seed;

  Object? get rawSummary => switch (summaryShape) {
    _GeneratedRunningSummaryShape.absent => null,
    _GeneratedRunningSummaryShape.valid => 'Generated timer summary $seed',
    _GeneratedRunningSummaryShape.paddedValid =>
      '  Generated timer summary $seed  ',
    _GeneratedRunningSummaryShape.empty => '   ',
    _GeneratedRunningSummaryShape.tooLong => 'x' * 501,
    _GeneratedRunningSummaryShape.nonString => seed,
  };

  Object? get rawTimerId => switch (timerIdShape) {
    _GeneratedTimerIdShape.absent => null,
    _GeneratedTimerIdShape.exact => 'timer-entry-001',
    _GeneratedTimerIdShape.paddedExact => ' timer-entry-001 ',
    _GeneratedTimerIdShape.wrong => 'wrong-timer-$seed',
    _GeneratedTimerIdShape.empty => '   ',
    _GeneratedTimerIdShape.nonString => seed,
  };

  Map<String, dynamic> get args => {
    if (summaryShape != _GeneratedRunningSummaryShape.absent)
      'summary': rawSummary,
    if (timerIdShape != _GeneratedTimerIdShape.absent) 'timerId': rawTimerId,
  };

  String? get trimmedSummary {
    final summary = rawSummary;
    return summary is String ? summary.trim() : null;
  }

  String? get trimmedTimerId {
    final timerId = rawTimerId;
    return timerId is String ? timerId.trim() : null;
  }

  String get currentId => switch (currentShape) {
    _GeneratedCurrentTimerShape.none => 'none',
    _GeneratedCurrentTimerShape.journalMatchingId ||
    _GeneratedCurrentTimerShape.measurementMatchingId => 'timer-entry-001',
    _GeneratedCurrentTimerShape.journalDifferentId => 'active-other-$seed',
  };

  bool get hasInvalidSummary =>
      trimmedSummary == null ||
      trimmedSummary!.isEmpty ||
      trimmedSummary!.length > 500;

  bool get hasInvalidTimerId =>
      trimmedTimerId == null || trimmedTimerId!.isEmpty;

  bool get hasNoActiveTimer => currentShape == _GeneratedCurrentTimerShape.none;

  bool get hasSourceMismatch =>
      linkedSourceShape != _GeneratedLinkedSourceShape.sameSource;

  bool get hasTimerIdMismatch => currentId != trimmedTimerId;

  bool get hasUnsupportedCurrentEntity =>
      currentShape == _GeneratedCurrentTimerShape.measurementMatchingId;

  bool get shouldAttemptPersist =>
      !hasInvalidSummary &&
      !hasInvalidTimerId &&
      !hasNoActiveTimer &&
      !hasSourceMismatch &&
      !hasTimerIdMismatch &&
      !hasUnsupportedCurrentEntity;

  bool get shouldSucceed => shouldAttemptPersist && persistenceSucceeds;

  EntryText get expectedEntryText => EntryText(
    plainText: '$trimmedSummary [generated]',
  );

  @override
  String toString() {
    return '_GeneratedRunningTimerUpdateScenario('
        'summaryShape: $summaryShape, '
        'timerIdShape: $timerIdShape, '
        'currentShape: $currentShape, '
        'linkedSourceShape: $linkedSourceShape, '
        'persistenceSucceeds: $persistenceSucceeds, '
        'currentId: $currentId)';
  }
}

extension _AnyRunningTimerUpdateScenario on glados.Any {
  glados.Generator<_GeneratedRunningSummaryShape>
  get generatedRunningSummaryShape =>
      glados.AnyUtils(this).choose(_GeneratedRunningSummaryShape.values);

  glados.Generator<_GeneratedTimerIdShape> get generatedTimerIdShape =>
      glados.AnyUtils(this).choose(_GeneratedTimerIdShape.values);

  glados.Generator<_GeneratedCurrentTimerShape>
  get generatedCurrentTimerShape =>
      glados.AnyUtils(this).choose(_GeneratedCurrentTimerShape.values);

  glados.Generator<_GeneratedLinkedSourceShape>
  get generatedLinkedSourceShape =>
      glados.AnyUtils(this).choose(_GeneratedLinkedSourceShape.values);

  glados.Generator<_GeneratedRunningTimerUpdateScenario>
  get runningTimerUpdateScenario => glados.CombinableAny(this).combine6(
    generatedRunningSummaryShape,
    generatedTimerIdShape,
    generatedCurrentTimerShape,
    generatedLinkedSourceShape,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 10000),
    (
      _GeneratedRunningSummaryShape summaryShape,
      _GeneratedTimerIdShape timerIdShape,
      _GeneratedCurrentTimerShape currentShape,
      _GeneratedLinkedSourceShape linkedSourceShape,
      bool persistenceSucceeds,
      int seed,
    ) => _GeneratedRunningTimerUpdateScenario(
      summaryShape: summaryShape,
      timerIdShape: timerIdShape,
      currentShape: currentShape,
      linkedSourceShape: linkedSourceShape,
      persistenceSucceeds: persistenceSucceeds,
      seed: seed,
    ),
  );
}

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

  /// Stubs an active running timer (default [makeRunningTimer]) linked from
  /// [linkedFrom] (default: the source task under test).
  void stubActiveTimer({JournalEntity? timer, JournalEntity? linkedFrom}) {
    when(
      () => mockTimeService.getCurrent(),
    ).thenReturn(timer ?? makeRunningTimer());
    when(
      () => mockTimeService.linkedFrom,
    ).thenReturn(linkedFrom ?? makeSourceTask());
  }

  /// Stubs the time service with no active timer.
  void stubNoTimer() {
    when(() => mockTimeService.getCurrent()).thenReturn(null);
  }

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
      stubNoTimer();

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
      stubActiveTimer();

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
        stubActiveTimer(linkedFrom: makeSourceTask(id: otherTaskId));

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
      'task ownership is checked before timerId comparison so the active '
      'timer id is never disclosed across tasks',
      () async {
        // An agent waking for task A submits an arbitrary `timerId` while a
        // timer is actually running for task B. The handler must short-circuit
        // on the source-task mismatch and produce a generic message — it
        // must NOT fall through to the timerId comparison branch, which
        // would otherwise echo task B's real timer id back to the caller.
        stubActiveTimer(linkedFrom: makeSourceTask(id: otherTaskId));

        final result = await handler.handle(
          sourceTaskId,
          {'timerId': 'guessed-id', 'summary': 'Working on API'},
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Timer source task mismatch');
        // Real timer id must not appear anywhere in the user-visible output.
        expect(result.output, isNot(contains(timerId)));
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
        stubActiveTimer(timer: notAJournalEntry);

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

    glados.Glados(
      glados.any.runningTimerUpdateScenario,
      glados.ExploreConfig(numRuns: 220),
    ).test(
      'matches generated validation, ownership, id, type, and persistence semantics',
      (scenario) async {
        final localPersistenceLogic = MockPersistenceLogic();
        final localTimeService = MockTimeService();
        final localDomainLogger = MockDomainLogger();
        final localHandler = RunningTimerUpdateHandler(
          persistenceLogic: localPersistenceLogic,
          timeService: localTimeService,
          domainLogger: localDomainLogger,
        );

        final current = switch (scenario.currentShape) {
          _GeneratedCurrentTimerShape.none => null,
          _GeneratedCurrentTimerShape.journalMatchingId ||
          _GeneratedCurrentTimerShape.journalDifferentId => makeRunningTimer(
            id: scenario.currentId,
          ),
          _GeneratedCurrentTimerShape.measurementMatchingId =>
            JournalEntity.measurement(
              meta: Metadata(
                id: scenario.currentId,
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
            ),
        };

        final linkedFrom = switch (scenario.linkedSourceShape) {
          _GeneratedLinkedSourceShape.sameSource => makeSourceTask(),
          _GeneratedLinkedSourceShape.otherSource => makeSourceTask(
            id: otherTaskId,
          ),
          _GeneratedLinkedSourceShape.none => null,
        };

        when(localTimeService.getCurrent).thenReturn(current);
        when(() => localTimeService.linkedFrom).thenReturn(linkedFrom);
        when(() => localTimeService.updateCurrent(any())).thenReturn(null);
        when(
          () => localPersistenceLogic.updateJournalEntityText(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async => scenario.persistenceSucceeds);
        when(
          () => localDomainLogger.log(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        await withClock(Clock.fixed(testNow), () async {
          final result = await localHandler.handle(
            sourceTaskId,
            scenario.args,
          );

          if (!scenario.shouldAttemptPersist) {
            expect(result.success, isFalse, reason: '$scenario');
            expect(result.errorMessage, isNotNull, reason: '$scenario');
            verifyNever(
              () => localPersistenceLogic.updateJournalEntityText(
                any(),
                any(),
                any(),
              ),
            );
            verifyNever(() => localTimeService.updateCurrent(any()));
            return;
          }

          expect(result.success, scenario.shouldSucceed, reason: '$scenario');
          verify(
            () => localPersistenceLogic.updateJournalEntityText(
              scenario.trimmedTimerId!,
              scenario.expectedEntryText,
              testNow,
            ),
          ).called(1);

          if (scenario.shouldSucceed) {
            expect(
              result.mutatedEntityId,
              scenario.trimmedTimerId,
              reason: '$scenario',
            );
            verify(
              () => localTimeService.updateCurrent(
                any(
                  that: isA<JournalEntry>()
                      .having(
                        (entry) => entry.entryText,
                        'entryText',
                        scenario.expectedEntryText,
                      )
                      .having(
                        (entry) => entry.meta.dateTo,
                        'meta.dateTo',
                        testNow,
                      )
                      .having(
                        (entry) => entry.meta.updatedAt,
                        'meta.updatedAt',
                        testNow,
                      ),
                ),
              ),
            ).called(1);
          } else {
            expect(
              result.errorMessage,
              'updateJournalEntityText returned false',
              reason: '$scenario',
            );
            verifyNever(() => localTimeService.updateCurrent(any()));
          }
        });
      },
      tags: 'glados',
    );

    test(
      'returns failure when persistence layer reports failure',
      () async {
        stubActiveTimer();
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
        stubActiveTimer();
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
      stubActiveTimer();
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
            any(
              that: allOf(
                contains('Updated running timer'),
                isNot(contains(timerId)),
                isNot(contains(sourceTaskId)),
                isNot(contains('Logged description')),
              ),
            ),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
      });
    });
  });
}
