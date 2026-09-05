import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/sleep_asleep_backfill_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';

/// A staged sleep sample as the import stored it, carrying the full metadata
/// the generic copy has to inherit.
QuantitativeEntry _stageEntry({
  required String id,
  String dataType = 'HealthDataType.SLEEP_LIGHT',
  DateTime? dateFrom,
}) {
  final from = dateFrom ?? DateTime(2026, 3, 1, 23, 12);
  final to = from.add(const Duration(minutes: 42));
  return QuantitativeEntry(
    meta: Metadata(
      id: id,
      createdAt: from,
      updatedAt: from,
      dateFrom: from,
      dateTo: to,
    ),
    data: QuantitativeData.discreteQuantityData(
      dateFrom: from,
      dateTo: to,
      value: 42,
      dataType: dataType,
      unit: 'HealthDataUnit.MINUTE',
      deviceType: 'Watch7,1',
      platformType: 'IOS',
      sourceId: 'com.apple.health',
      sourceName: 'Watch',
    ),
  );
}

void main() {
  late SleepAsleepBackfillService service;
  late MockJournalDb journalDb;
  late MockPersistenceLogic persistenceLogic;
  late MockDomainLogger logger;

  // Keeps the year sweep to 2015–2016 so a test's stubs stay enumerable.
  final now = DateTime(2016, 6, 15);

  setUpAll(registerAllFallbackValues);

  setUp(() {
    journalDb = MockJournalDb();
    persistenceLogic = MockPersistenceLogic();
    logger = MockDomainLogger();
    service = SleepAsleepBackfillService(
      journalDb: journalDb,
      persistenceLogic: persistenceLogic,
      logger: logger,
    );

    when(
      () => journalDb.getQuantitativeByTypeIncludingPrivate(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
    // A missing copy: the write is accepted and an entity comes back.
    when(() => persistenceLogic.createQuantitativeEntry(any())).thenAnswer((
      invocation,
    ) async {
      final data = invocation.positionalArguments.first as QuantitativeData;
      return QuantitativeEntry(
        data: data,
        meta: Metadata(
          id: 'written',
          createdAt: data.dateFrom,
          updatedAt: data.dateFrom,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
        ),
      );
    });
  });

  void stubWindow(
    List<QuantitativeEntry> entries, {
    int year = 2015,
    String dataType = 'HealthDataType.SLEEP_LIGHT',
  }) {
    when(
      () => journalDb.getQuantitativeByTypeIncludingPrivate(
        type: dataType,
        rangeStart: DateTime(year),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => entries);
  }

  group('SleepAsleepBackfillService', () {
    test('writes the generic copy a core-sleep sample never got', () async {
      final stage = _stageEntry(id: 'core-1');
      stubWindow([stage]);

      final report = await service.backfill(now: now);

      final written =
          verify(
                () => persistenceLogic.createQuantitativeEntry(captureAny()),
              ).captured.single
              // The variant has to survive the copy too: the import writes a
              // DiscreteQuantityData, and a different variant would serialise
              // differently and so hash to a different id.
              as DiscreteQuantityData;

      // The copy must be the stage row with only its type swapped. That is
      // what the import writes, and because the id is a uuidV5 over the whole
      // payload, anything else here would produce a row a later import would
      // not recognise — and would therefore duplicate.
      expect(
        written,
        stage.data.copyWith(dataType: 'HealthDataType.SLEEP_ASLEEP'),
      );
      expect(written.dataType, 'HealthDataType.SLEEP_ASLEEP');
      expect(written.value, 42);
      expect(written.dateFrom, stage.data.dateFrom);
      expect(written.dateTo, stage.data.dateTo);
      expect(written.sourceId, 'com.apple.health');

      expect(report.created, 1);
      expect(report.scanned, 1);
      expect(report.failed, 0);
    });

    test(
      'counts a copy that already exists rather than duplicating it',
      () async {
        // `createQuantitativeEntry` returns null when the deterministic id is
        // already stored — the second run of the backfill, and every row
        // imported after the duplication set was corrected.
        stubWindow([_stageEntry(id: 'already-copied')]);
        when(
          () => persistenceLogic.createQuantitativeEntry(any()),
        ).thenAnswer((_) async => null);

        final report = await service.backfill(now: now);

        expect(report.created, 0);
        expect(report.scanned, 1);
        expect(
          report.count(SleepAsleepBackfillStatus.alreadyPresent),
          1,
        );
      },
    );

    test('sweeps the staged types only', () async {
      await service.backfill(now: now);

      final types = verify(
        () => journalDb.getQuantitativeByTypeIncludingPrivate(
          type: captureAny(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).captured.cast<String>().toSet();

      // In-bed and awake are not sleep, and the generic type is the
      // destination — copying it onto itself would double every night.
      expect(types, {
        'HealthDataType.SLEEP_LIGHT',
        'HealthDataType.SLEEP_DEEP',
        'HealthDataType.SLEEP_REM',
      });
    });

    test('keeps going after a window that throws', () async {
      when(
        () => journalDb.getQuantitativeByTypeIncludingPrivate(
          type: 'HealthDataType.SLEEP_LIGHT',
          rangeStart: DateTime(2015),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenThrow(Exception('db unavailable'));
      stubWindow(
        [
          _stageEntry(id: 'later', dateFrom: DateTime(2016, 2, 1, 2)),
        ],
        year: 2016,
        dataType: 'HealthDataType.SLEEP_REM',
      );

      final report = await service.backfill(now: now);

      expect(report.failed, 1, reason: 'the throwing window is recorded');
      expect(
        report.created,
        1,
        reason: 'a window after the failure is still swept',
      );
    });

    test('visits an entry once when two windows both return it', () async {
      // Windows overlap by a day so a segment spanning New Year is not lost;
      // the entry must still be copied exactly once.
      final spansNewYear = _stageEntry(
        id: 'new-year',
        dateFrom: DateTime(2015, 12, 31, 23, 40),
      );
      stubWindow([spansNewYear]);
      stubWindow([spansNewYear], year: 2016);

      final report = await service.backfill(now: now);

      expect(report.scanned, 1);
      expect(report.created, 1);
      verify(
        () => persistenceLogic.createQuantitativeEntry(any()),
      ).called(1);
    });
  });
}
