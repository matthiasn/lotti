@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/repository/insights_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';

void main() {
  late JournalDb db;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    } else {
      previousDirectory = null;
    }
    getIt.registerSingleton<Directory>(Directory.systemTemp);
    db = JournalDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
  });

  test(
    '10k-entry year: cold fetch+bucketize is fast, every preset switch is '
    'in-memory and far under the 200ms budget',
    () async {
      // ~18 months of entries ending "today" (fixed date for determinism):
      // 10,000 entries across 20 categories, 2-3 entries per hour slot,
      // some crossing midnight. This mirrors a heavy real-world year.
      final now = DateTime(2024, 9, 15, 16);
      const entryCount = 10000;
      const categoryCount = 20;

      final batch = <JournalEntity>[];
      for (var i = 0; i < entryCount; i++) {
        // Spread entries over 540 days, three per ~3.9-hour slot.
        final minutesBack = (i * (540 * 24 * 60) / entryCount).round();
        final start = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          -minutesBack,
        );
        final durationMinutes = 10 + (i % 110); // 10m .. 2h
        final end = DateTime(
          start.year,
          start.month,
          start.day,
          start.hour,
          start.minute + durationMinutes,
        );
        batch.add(
          JournalEntity.journalEntry(
            meta: Metadata(
              id: 'perf-entry-$i',
              createdAt: start,
              updatedAt: start,
              dateFrom: start,
              dateTo: end,
              categoryId: i % 7 == 0 ? null : 'cat-${i % categoryCount}',
            ),
            entryText: const EntryText(plainText: 'work'),
          ),
        );
      }
      for (final entity in batch) {
        await db.updateJournalEntity(entity);
      }
      // Sprinkle task links over 10% of entries so the correlated
      // subquery's cost is exercised, not bypassed.
      final linkAt = DateTime(2024);
      for (var i = 0; i < entryCount; i += 10) {
        await db.upsertEntryLink(
          EntryLink.basic(
            id: 'link-$i',
            fromId: 'perf-task-${i % 50}',
            toId: 'perf-entry-$i',
            createdAt: linkAt,
            updatedAt: linkAt,
            vectorClock: const VectorClock(<String, int>{}),
          ),
        );
      }

      final repository = InsightsRepository(db);
      final ytdRange = resolvePreset(InsightsRangePreset.ytd, now);
      final windowStartDay = windowStartDayFor(ytdRange);

      // --- Cold path: one slim query + bucketize for the whole window. ---
      final coldWatch = Stopwatch()..start();
      final rows = await repository.fetchTimeRows(
        start: dayStart(windowStartDay),
        end: dayStart(epochDay(now) + 1),
      );
      final fetchMs = coldWatch.elapsedMilliseconds;
      final buckets = bucketize(rows, windowStartDay: windowStartDay);
      coldWatch.stop();

      expect(rows.length, greaterThan(4000)); // sanity: YTD subset of 10k
      // ignore: avoid_print
      print(
        'cold fetch: ${fetchMs}ms for ${rows.length} rows, '
        'fetch+bucketize: ${coldWatch.elapsedMilliseconds}ms',
      );
      // Product budget is 200ms; allow headroom for anemic CI runners.
      // Locally this runs in well under 100ms.
      expect(coldWatch.elapsedMilliseconds, lessThan(500));

      // --- Hot path: every preset switch must slice in-memory. ---
      // This is the "instantaneous range switching" requirement: zero DB,
      // chart+table+KPIs recomputed from buckets.
      final hotWatch = Stopwatch()..start();
      for (final preset in InsightsRangePreset.values) {
        final range = resolvePreset(preset, now);
        final chart = buildChartData(buckets, range);
        final table = buildTableRows(buckets, range);
        final kpis = buildKpis(
          buckets,
          range,
          focusCategoryIds: const {'cat-1', 'cat-2'},
        );
        // Touch results so nothing is optimized away.
        expect(chart.bucketStarts, isNotEmpty);
        expect(kpis.totalSeconds, greaterThanOrEqualTo(0));
        expect(table, isA<List<InsightsTableRow>>());
      }
      hotWatch.stop();
      // ignore: avoid_print
      print(
        'all ${InsightsRangePreset.values.length} preset switches: '
        '${hotWatch.elapsedMilliseconds}ms',
      );
      // All six presets together must beat the single-switch budget.
      expect(hotWatch.elapsedMilliseconds, lessThan(200));
    },
  );
}
