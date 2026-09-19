import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/week_context.dart';
import 'package:lotti/features/daily_os_next/agents/domain/week_rollup.dart';

import '../../../agents/test_data/entity_factories.dart';

PlannedBlock _block({
  required String categoryId,
  required DateTime start,
  required int minutes,
  PlannedBlockState state = PlannedBlockState.drafted,
}) => PlannedBlock(
  id: 'block-$categoryId-${start.toIso8601String()}',
  categoryId: categoryId,
  startTime: start,
  endTime: start.add(Duration(minutes: minutes)),
  state: state,
);

DayPlanData _data(DateTime planDate, List<PlannedBlock> blocks) => DayPlanData(
  planDate: planDate,
  status: const DayPlanStatus.draft(),
  plannedBlocks: blocks,
);

void main() {
  test('the week label is formatted from the key, never converted', () {
    // localDay() on this zone-free Monday renders 2026-05-31 anywhere west of
    // UTC — a wrong week label on otherwise-correct totals.
    final rendered = renderRecentWeeksJson(
      rollups: [
        makeTestWeekRollup(
          id: 'week_rollup_v2:2026-06-01',
          weekStart: DateTime.utc(2026, 6),
        ),
      ],
      categoryName: (id) => id,
    );

    expect(rendered!.single['weekStart'], '2026-06-01');
  });

  group('computeWeekRollupAggregates', () {
    test('sums planned minutes per category across days, skipping dropped '
        'blocks, and counts distinct planned days', () {
      final monday = DateTime(2026, 5, 18);
      final tuesday = DateTime(2026, 5, 19);
      final result = computeWeekRollupAggregates(
        dayPlans: [
          makeTestDayPlan(
            dayId: 'dayplan-2026-05-18',
            planDate: monday,
            data: _data(monday, [
              _block(
                categoryId: 'cat-work',
                start: DateTime(2026, 5, 18, 9),
                minutes: 120,
              ),
              _block(
                categoryId: 'cat-health',
                start: DateTime(2026, 5, 18, 18),
                minutes: 45,
              ),
              _block(
                categoryId: 'cat-work',
                start: DateTime(2026, 5, 18, 14),
                minutes: 60,
                state: PlannedBlockState.dropped,
              ),
            ]),
          ),
          makeTestDayPlan(
            dayId: 'dayplan-2026-05-19',
            planDate: tuesday,
            data: _data(tuesday, [
              _block(
                categoryId: 'cat-work',
                start: DateTime(2026, 5, 19, 9),
                minutes: 90,
              ),
            ]),
          ),
        ],
        recordedSpans: const [],
      );

      expect(result.daysWithPlans, 2);
      expect(
        result.plannedMinutesByCategory,
        {'cat-health': 45, 'cat-work': 210},
        reason: 'The dropped 60-minute block must not count.',
      );
      expect(result.recordedMinutesByCategory, isEmpty);
    });

    test('sums recorded minutes per category, bucketing null categories '
        'under the uncategorized key', () {
      final result = computeWeekRollupAggregates(
        dayPlans: const [],
        recordedSpans: [
          RecordedSpan(
            categoryId: 'cat-work',
            start: DateTime(2026, 5, 18, 9),
            duration: const Duration(minutes: 50),
          ),
          RecordedSpan(
            categoryId: null,
            start: DateTime(2026, 5, 19, 8),
            duration: const Duration(minutes: 25),
          ),
          RecordedSpan(
            categoryId: 'cat-work',
            start: DateTime(2026, 5, 20, 9),
            duration: const Duration(minutes: 10),
          ),
        ],
      );

      expect(result.daysWithPlans, 0);
      expect(result.recordedMinutesByCategory, {
        uncategorizedRollupKey: 25,
        'cat-work': 60,
      });
    });

    test('emits keys in sorted order so equal aggregates serialize '
        'byte-identically', () {
      final monday = DateTime(2026, 5, 18);
      final result = computeWeekRollupAggregates(
        dayPlans: [
          makeTestDayPlan(
            dayId: 'dayplan-2026-05-18',
            planDate: monday,
            data: _data(monday, [
              _block(
                categoryId: 'z-cat',
                start: DateTime(2026, 5, 18, 9),
                minutes: 30,
              ),
              _block(
                categoryId: 'a-cat',
                start: DateTime(2026, 5, 18, 11),
                minutes: 30,
              ),
            ]),
          ),
        ],
        recordedSpans: const [],
      );

      expect(result.plannedMinutesByCategory.keys.toList(), [
        'a-cat',
        'z-cat',
      ]);
    });
  });

  group('renderRecentWeeksJson', () {
    test('returns null for no rollups so the section is omitted', () {
      expect(
        renderRecentWeeksJson(rollups: const [], categoryName: (_) => null),
        isNull,
      );
    });

    test('renders newest week first with names resolved, uncategorized '
        'labeled, and unknown ids passed through', () {
      final rendered = renderRecentWeeksJson(
        rollups: [
          makeTestWeekRollup(
            id: 'week_rollup_v2:2026-05-11',
            weekStart: DateTime(2026, 5, 11),
            plannedMinutesByCategory: const {'cat-work': 300},
            recordedMinutesByCategory: const {},
            daysWithPlans: 3,
          ),
          makeTestWeekRollup(
            weekStart: DateTime(2026, 5, 18),
            recordedMinutesByCategory: const {
              uncategorizedRollupKey: 20,
              'cat-unknown': 15,
              'cat-work': 310,
            },
          ),
        ],
        categoryName: (id) => id == 'cat-work' ? 'Work' : null,
      )!;

      expect(rendered, hasLength(2));
      expect(rendered.first['weekStart'], '2026-05-18');
      expect(rendered.first['daysWithPlans'], 5);
      expect(rendered.first['plannedMinutes'], {'Work': 480});
      expect(rendered.first['recordedMinutes'], {
        'Uncategorized': 20,
        'Work': 310,
        'cat-unknown': 15,
      });
      expect(rendered.last['weekStart'], '2026-05-11');
      expect(
        rendered.last.containsKey('recordedMinutes'),
        isFalse,
        reason: 'An empty minutes map renders no key at all.',
      );
    });

    test('colliding display names merge by summing and are sanitized', () {
      final rendered = renderRecentWeeksJson(
        rollups: [
          makeTestWeekRollup(
            plannedMinutesByCategory: const {'cat-a': 30, 'cat-b': 45},
            recordedMinutesByCategory: const {},
          ),
        ],
        categoryName: (_) => 'Deep\nWork',
      )!;

      expect(
        rendered.single['plannedMinutes'],
        {'Deep Work': 75},
        reason:
            'Both ids resolve to the same (newline-collapsed) name and '
            'must merge, not overwrite.',
      );
    });
  });

  group('properties', () {
    final monday = DateTime(2026, 5, 18);
    final category = glados.any.choose(['cat-work', 'cat-health', '']);
    final block = glados.any.combine4(
      glados.any.intInRange(0, 7),
      category,
      glados.any.intInRange(0, 300),
      glados.any.choose(PlannedBlockState.values),
      (int day, String categoryId, int minutes, PlannedBlockState state) =>
          _block(
            categoryId: categoryId,
            start: monday.add(Duration(days: day, hours: 8, minutes: minutes)),
            minutes: minutes,
            state: state,
          ),
    );
    final span = glados.any.combine3(
      glados.any.choose(['cat-work', 'cat-health', null]),
      glados.any.intInRange(0, 7),
      glados.any.intInRange(0, 20000),
      (String? categoryId, int day, int seconds) => RecordedSpan(
        categoryId: categoryId,
        start: monday.add(Duration(days: day, hours: 9)),
        duration: Duration(seconds: seconds),
      ),
    );

    List<DayPlanEntity> plans(List<PlannedBlock> blocks) => [
      for (var day = 0; day < 7; day++)
        if (blocks.any((b) => b.startTime.day == monday.day + day))
          makeTestDayPlan(
            id: 'plan-$day',
            dayId: 'dayplan-2026-05-${18 + day}',
            planDate: monday.add(Duration(days: day)),
            data: _data(monday.add(Duration(days: day)), [
              for (final b in blocks)
                if (b.startTime.day == monday.day + day) b,
            ]),
          ),
    ];

    glados.Glados3(
      glados.any.listWithLengthInRange(0, 15, block),
      glados.any.listWithLengthInRange(0, 15, span),
      glados.any.intInRange(0, 1000),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'totals match the inputs, keys are sorted, input order is irrelevant',
      (blocks, spans, seed) {
        final result = computeWeekRollupAggregates(
          dayPlans: plans(blocks),
          recordedSpans: spans,
        );

        final plannedTotal = blocks
            .where((b) => b.state != PlannedBlockState.dropped)
            .fold<int>(
              0,
              (sum, b) => sum + b.endTime.difference(b.startTime).inMinutes,
            );
        final recordedTotal = spans.fold<int>(
          0,
          (sum, s) => sum + s.duration.inMinutes,
        );
        int total(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);
        expect(total(result.plannedMinutesByCategory), plannedTotal);
        expect(total(result.recordedMinutesByCategory), recordedTotal);
        expect(result.daysWithPlans, plans(blocks).length);

        for (final map in [
          result.plannedMinutesByCategory,
          result.recordedMinutesByCategory,
        ]) {
          expect(map.keys.toList(), [...map.keys]..sort());
        }

        final random = Random(seed);
        final reordered = computeWeekRollupAggregates(
          dayPlans: plans([...blocks]..shuffle(random)).reversed.toList(),
          recordedSpans: [...spans]..shuffle(random),
        );
        String encode(
          ({
            int daysWithPlans,
            Map<String, int> plannedMinutesByCategory,
            Map<String, int> recordedMinutesByCategory,
          })
          r,
        ) => jsonEncode([
          r.daysWithPlans,
          r.plannedMinutesByCategory,
          r.recordedMinutesByCategory,
        ]);
        expect(encode(reordered), encode(result));
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.listWithLengthInRange(0, 8, glados.any.intInRange(0, 60)),
      glados.any.intInRange(0, 1000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'recent weeks render newest first, one object per rollup',
      (weekOffsets, seed) {
        final weeks = weekOffsets.toSet().toList()..shuffle(Random(seed));
        final rendered = renderRecentWeeksJson(
          rollups: [
            for (final w in weeks)
              makeTestWeekRollup(
                id: 'week-$w',
                weekStart: DateTime.utc(2026, 5, 18 - 7 * w),
              ),
          ],
          categoryName: (id) => id,
        );
        if (weeks.isEmpty) {
          expect(rendered, isNull);
          return;
        }
        final labels = rendered!.map((w) => w['weekStart']! as String).toList();
        expect(labels, hasLength(weeks.length));
        expect(labels, [...labels]..sort((a, b) => b.compareTo(a)));
      },
      tags: 'glados',
    );
  });
}
