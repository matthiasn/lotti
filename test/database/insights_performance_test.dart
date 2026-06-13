import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
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
    '10k-entry year: cold fetch+bucketize is fast, every period switch is '
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
      await db.transaction(() async {
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
      });

      final repository = InsightsRepository(db);
      final yearRange = periodContaining(InsightsPeriodUnit.year, now);
      final windowStartDay = windowStartDayFor(yearRange);

      // Warm-up: one untimed query so JIT compilation and SQLite
      // page-cache population don't count against the budget — on
      // contended CI runners (the whole suite shares one thread under
      // very_good test) those first-run costs dominate.
      await repository.fetchTimeRows(
        start: dayStart(windowStartDay),
        end: dayStart(epochDay(now) + 1),
      );

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
      // Product budget is 200ms and locally this measures ~35ms; the
      // assertion is an order-of-magnitude regression guard (an O(n²)
      // bucketizer or a fan-out join measures in seconds), with generous
      // headroom for anemic, contended CI runners.
      expect(coldWatch.elapsedMilliseconds, lessThan(2000));

      // --- Hot path: every period switch must slice in-memory. ---
      // This is the "instantaneous range switching" requirement: zero DB,
      // chart+table+KPIs recomputed from buckets. Best-of-three: the
      // minimum is robust to CI scheduler spikes while still catching
      // real complexity regressions.
      final periods = [
        for (final unit in InsightsPeriodUnit.values)
          periodContaining(unit, now),
      ];
      var bestHotMs = 1 << 30;
      final attempts = <int>[];
      for (var attempt = 0; attempt < 3; attempt++) {
        final hotWatch = Stopwatch()..start();
        for (final range in periods) {
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
        attempts.add(hotWatch.elapsedMilliseconds);
        bestHotMs = math.min(bestHotMs, hotWatch.elapsedMilliseconds);
      }
      // ignore: avoid_print
      print(
        'all ${periods.length} period switches: '
        '$attempts ms (best $bestHotMs ms)',
      );
      // All periods together must beat the single-switch budget.
      expect(bestHotMs, lessThan(200));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
