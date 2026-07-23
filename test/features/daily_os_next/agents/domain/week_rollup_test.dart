import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
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
            id: 'week_rollup:2026-05-11',
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
}
