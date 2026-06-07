import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/time_entry_update_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

enum _GeneratedSummaryShape {
  absent,
  valid,
  paddedValid,
  empty,
  tooLong,
  nonString,
}

enum _GeneratedTimeArgShape {
  absent,
  valid,
  paddedValid,
  empty,
  invalidType,
  timezone,
  invalidLocal,
}

class _GeneratedTimeEntryUpdateScenario {
  const _GeneratedTimeEntryUpdateScenario({
    required this.summaryShape,
    required this.startShape,
    required this.endShape,
    required this.flags,
    required this.startOffsetSeed,
    required this.endOffsetSeed,
    required this.seed,
  });

  final _GeneratedSummaryShape summaryShape;
  final _GeneratedTimeArgShape startShape;
  final _GeneratedTimeArgShape endShape;
  final int flags;
  final int startOffsetSeed;
  final int endOffsetSeed;
  final int seed;

  static final existingStart = DateTime(2026, 4, 15, 13);
  static final existingEnd = DateTime(2026, 4, 15, 14);

  bool get isLinked => flags.isOdd;
  bool get isActiveTimer => flags & 2 != 0;
  bool get persistenceSucceeds => flags & 4 != 0;

  int get startOffsetMinutes => (startOffsetSeed % 361) - 180;
  int get endOffsetMinutes => (endOffsetSeed % 361) - 180;

  DateTime get generatedStart =>
      existingStart.add(Duration(minutes: startOffsetMinutes));

  DateTime get generatedEnd =>
      existingEnd.add(Duration(minutes: endOffsetMinutes));

  Object? get rawSummary => switch (summaryShape) {
    _GeneratedSummaryShape.absent => null,
    _GeneratedSummaryShape.valid => 'Generated summary $seed',
    _GeneratedSummaryShape.paddedValid => '  Generated summary $seed  ',
    _GeneratedSummaryShape.empty => '   ',
    _GeneratedSummaryShape.tooLong => 'x' * 501,
    _GeneratedSummaryShape.nonString => seed,
  };

  Object? rawTime(_GeneratedTimeArgShape shape, DateTime value) {
    final text = _formatLocal(value);
    return switch (shape) {
      _GeneratedTimeArgShape.absent => null,
      _GeneratedTimeArgShape.valid => text,
      _GeneratedTimeArgShape.paddedValid => ' $text ',
      _GeneratedTimeArgShape.empty => '',
      _GeneratedTimeArgShape.invalidType => seed,
      _GeneratedTimeArgShape.timezone => '${text}Z',
      _GeneratedTimeArgShape.invalidLocal => '2026-00-01T00:00:00',
    };
  }

  Map<String, dynamic> get args => {
    'entryId': 'entry-001',
    if (summaryShape != _GeneratedSummaryShape.absent) 'summary': rawSummary,
    if (startShape != _GeneratedTimeArgShape.absent)
      'startTime': rawTime(startShape, generatedStart),
    if (endShape != _GeneratedTimeArgShape.absent)
      'endTime': rawTime(endShape, generatedEnd),
  };

  bool get hasNoChanges =>
      summaryShape == _GeneratedSummaryShape.absent &&
      startShape == _GeneratedTimeArgShape.absent &&
      endShape == _GeneratedTimeArgShape.absent;

  bool get hasInvalidSummary => switch (summaryShape) {
    _GeneratedSummaryShape.empty ||
    _GeneratedSummaryShape.tooLong ||
    _GeneratedSummaryShape.nonString => true,
    _ => false,
  };

  bool hasInvalidTime(_GeneratedTimeArgShape shape) {
    return switch (shape) {
      _GeneratedTimeArgShape.empty ||
      _GeneratedTimeArgShape.invalidType ||
      _GeneratedTimeArgShape.timezone ||
      _GeneratedTimeArgShape.invalidLocal => true,
      _ => false,
    };
  }

  DateTime? parsedTime(_GeneratedTimeArgShape shape, DateTime value) {
    return switch (shape) {
      _GeneratedTimeArgShape.valid ||
      _GeneratedTimeArgShape.paddedValid => value,
      _ => null,
    };
  }

  DateTime? get parsedStart => parsedTime(startShape, generatedStart);
  DateTime? get parsedEnd => parsedTime(endShape, generatedEnd);

  DateTime get resolvedStart => parsedStart ?? existingStart;
  DateTime get resolvedEnd => parsedEnd ?? existingEnd;

  bool get hasInvalidRange => !resolvedEnd.isAfter(resolvedStart);

  bool get shouldAttemptWrite =>
      !hasNoChanges &&
      !hasInvalidSummary &&
      !hasInvalidTime(startShape) &&
      !hasInvalidTime(endShape) &&
      isLinked &&
      !isActiveTimer &&
      !hasInvalidRange;

  bool get shouldSucceed => shouldAttemptWrite && persistenceSucceeds;

  EntryText? get expectedEntryText {
    final summary = rawSummary;
    if (summary is! String) return null;
    return EntryText(plainText: '${summary.trim()} [generated]');
  }

  @override
  String toString() {
    return '_GeneratedTimeEntryUpdateScenario('
        'summaryShape: $summaryShape, '
        'startShape: $startShape, '
        'endShape: $endShape, '
        'isLinked: $isLinked, '
        'isActiveTimer: $isActiveTimer, '
        'persistenceSucceeds: $persistenceSucceeds, '
        'resolvedStart: $resolvedStart, '
        'resolvedEnd: $resolvedEnd)';
  }
}

extension _AnyTimeEntryUpdateScenario on glados.Any {
  glados.Generator<_GeneratedSummaryShape> get generatedSummaryShape =>
      glados.AnyUtils(this).choose(_GeneratedSummaryShape.values);

  glados.Generator<_GeneratedTimeArgShape> get generatedTimeArgShape =>
      glados.AnyUtils(this).choose(_GeneratedTimeArgShape.values);

  glados.Generator<_GeneratedTimeEntryUpdateScenario>
  get timeEntryUpdateScenario => glados.CombinableAny(this).combine7(
    generatedSummaryShape,
    generatedTimeArgShape,
    generatedTimeArgShape,
    glados.IntAnys(this).intInRange(0, 7),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      _GeneratedSummaryShape summaryShape,
      _GeneratedTimeArgShape startShape,
      _GeneratedTimeArgShape endShape,
      int flags,
      int startOffsetSeed,
      int endOffsetSeed,
      int seed,
    ) => _GeneratedTimeEntryUpdateScenario(
      summaryShape: summaryShape,
      startShape: startShape,
      endShape: endShape,
      flags: flags,
      startOffsetSeed: startOffsetSeed,
      endOffsetSeed: endOffsetSeed,
      seed: seed,
    ),
  );
}

String _formatLocal(DateTime value) {
  return '${_fourDigits(value.year)}-${_twoDigits(value.month)}-'
      '${_twoDigits(value.day)}T${_twoDigits(value.hour)}:'
      '${_twoDigits(value.minute)}:${_twoDigits(value.second)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
String _fourDigits(int value) => value.toString().padLeft(4, '0');

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

      glados.Glados(
        glados.any.timeEntryUpdateScenario,
        glados.ExploreConfig(numRuns: 200),
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
            dateFrom: _GeneratedTimeEntryUpdateScenario.existingStart,
            dateTo: _GeneratedTimeEntryUpdateScenario.existingEnd,
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

          final result = await localHandler.handle(
            sourceTaskId,
            scenario.args,
          );

          if (!scenario.shouldAttemptWrite) {
            expect(result.success, isFalse, reason: '$scenario');
            expect(result.errorMessage, isNotNull, reason: '$scenario');
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
              dateTo: scenario.parsedEnd,
            ),
          ).called(1);

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
