import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/measurable_choice_reindex.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('choiceTitlesChanged', () {
    test('a definition seen for the first time changes nothing indexed', () {
      expect(choiceTitlesChanged(null, measurableHydration), isFalse);
    });

    test('a renamed choice, active or archived, is a change', () {
      expect(
        choiceTitlesChanged(
          measurableHydration,
          measurableHydration.copyWith(
            choices: [
              hydrationClear.copyWith(title: 'Crystal clear'),
              hydrationPale,
              hydrationDark,
              hydrationBrown,
            ],
          ),
        ),
        isTrue,
      );
      expect(
        choiceTitlesChanged(
          measurableHydration,
          measurableHydration.copyWith(
            choices: [
              hydrationClear,
              hydrationPale,
              hydrationDark,
              hydrationBrown.copyWith(title: 'Amber'),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('adding, archiving, reordering or dropping a choice is not', () {
      expect(
        choiceTitlesChanged(
          measurableHydration,
          measurableHydration.copyWith(
            choices: [
              hydrationDark,
              hydrationClear.copyWith(archived: true),
              hydrationPale,
              const MeasurableChoice(id: 'new', title: 'Orange'),
            ],
          ),
        ),
        isFalse,
      );
      expect(
        choiceTitlesChanged(
          measurableHydration,
          measurableHydration.copyWith(choices: null),
        ),
        isFalse,
      );
      expect(
        choiceTitlesChanged(
          measurableWater,
          measurableWater.copyWith(displayName: 'Still water'),
        ),
        isFalse,
      );
    });
  });

  group('reindexMeasurementsForChoiceTitles', () {
    late MockJournalDb journalDb;
    late MockFts5Db fts5Db;

    setUp(() {
      journalDb = MockJournalDb();
      fts5Db = MockFts5Db();
      when(
        () => fts5Db.insertText(
          any(),
          removePrevious: any(named: 'removePrevious'),
        ),
      ).thenAnswer((_) async {});
    });

    test(
      'stamps the definition into the cache, reads every measurement of the '
      'type and rewrites the rows of the choice recordings only',
      () async {
        final numeric = testMeasurementChocolateEntry.copyWith(
          data: testMeasurementChocolateEntry.data.copyWith(
            dataTypeId: measurableHydration.id,
          ),
        );
        DateTime? start;
        DateTime? end;
        when(
          () => journalDb.getMeasurementsByType(
            type: measurableHydration.id,
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((invocation) async {
          start = invocation.namedArguments[#rangeStart] as DateTime;
          end = invocation.namedArguments[#rangeEnd] as DateTime;
          return [testMeasurementHydrationEntry, numeric, testTextEntry];
        });
        final cache = <String, MeasurableDataType>{};
        final renamed = measurableHydration.copyWith(
          choices: [
            hydrationClear.copyWith(title: 'Crystal'),
            hydrationPale,
          ],
        );

        await reindexMeasurementsForChoiceTitles(
          journalDb: journalDb,
          fts5Db: fts5Db,
          cachedDataTypes: cache,
          dataType: renamed,
        );

        expect(cache[measurableHydration.id], renamed);
        // All of history, not a chart window.
        expect(start!.isBefore(DateTime(2000)), isTrue);
        expect(end!.isAfter(DateTime(2090)), isTrue);
        verify(
          () => fts5Db.insertText(
            testMeasurementHydrationEntry,
            removePrevious: true,
          ),
        ).called(1);
        verifyNever(
          () => fts5Db.insertText(
            numeric,
            removePrevious: any(named: 'removePrevious'),
          ),
        );
        verifyNever(
          () => fts5Db.insertText(
            any(that: isA<JournalEntry>()),
            removePrevious: any(named: 'removePrevious'),
          ),
        );
      },
    );
  });
}
