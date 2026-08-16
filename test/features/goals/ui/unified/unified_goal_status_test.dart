import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final messages = AppLocalizationsEn();

  GoalHabitProgressView habitView({required int successes, int target = 4}) =>
      GoalHabitProgressView(
        habitId: 'habit',
        name: 'Habit',
        targetCount: target,
        days: const [],
        successfulWeeks: 0,
        evaluatedSuccesses: successes,
      );

  group('unifiedGoalStatusOf', () {
    test('collapses every runtime status into the four-pill vocabulary', () {
      expect(
        unifiedGoalStatusOf(GoalTrackStatus.onTrack),
        UnifiedGoalStatus.onTrack,
      );
      expect(
        unifiedGoalStatusOf(GoalTrackStatus.achieved),
        UnifiedGoalStatus.onTrack,
      );
      expect(
        unifiedGoalStatusOf(GoalTrackStatus.atRisk),
        UnifiedGoalStatus.atRisk,
      );
      // `recovering` deliberately reads as At risk here (not the coarse
      // vocabulary's "Restarting") — the recovery hint carries the
      // fresh-start framing on the unified surface.
      expect(
        unifiedGoalStatusOf(GoalTrackStatus.recovering),
        UnifiedGoalStatus.atRisk,
      );
      expect(
        unifiedGoalStatusOf(GoalTrackStatus.offTrack),
        UnifiedGoalStatus.behind,
      );
      expect(
        unifiedGoalStatusOf(GoalTrackStatus.insufficientData),
        UnifiedGoalStatus.noData,
      );
      expect(unifiedGoalStatusOf(null), UnifiedGoalStatus.noData);
    });
  });

  group('unifiedGoalStatusLabel', () {
    test('uses the four unified pill words', () {
      expect(
        unifiedGoalStatusLabel(messages, UnifiedGoalStatus.onTrack),
        'On track',
      );
      expect(
        unifiedGoalStatusLabel(messages, UnifiedGoalStatus.atRisk),
        'At risk',
      );
      expect(
        unifiedGoalStatusLabel(messages, UnifiedGoalStatus.behind),
        'Behind',
      );
      expect(
        unifiedGoalStatusLabel(messages, UnifiedGoalStatus.noData),
        'No data',
      );
    });
  });

  group('unifiedGoalStatusColor', () {
    test('on-track reads success, both off-track states share the warning '
        'hue, no-data is neutral — never a red on this surface', () {
      final colors = resolveTestTheme().extension<DsTokens>()!.colors;
      expect(
        unifiedGoalStatusColor(UnifiedGoalStatus.onTrack, colors),
        colors.alert.success.defaultColor,
      );
      expect(
        unifiedGoalStatusColor(UnifiedGoalStatus.atRisk, colors),
        colors.alert.warning.defaultColor,
      );
      expect(
        unifiedGoalStatusColor(UnifiedGoalStatus.behind, colors),
        colors.alert.warning.defaultColor,
      );
      expect(
        unifiedGoalStatusColor(UnifiedGoalStatus.noData, colors),
        colors.text.lowEmphasis,
      );
      expect(
        unifiedGoalStatusColor(UnifiedGoalStatus.behind, colors),
        isNot(colors.alert.error.defaultColor),
      );
    });
  });

  group('goalCriterionHabitIds', () {
    const window = GoalWindow.rollingDays(count: 7);

    test('a bare habit criterion claims its habit id', () {
      expect(
        goalCriterionHabitIds(
          const GoalCriterion.habit(
            criterionId: 'c1',
            habitId: 'walk',
            window: window,
            targetCount: 4,
          ),
        ),
        {'walk'},
      );
    });

    test('composite criteria collect habit ids across every nesting level, '
        'deduplicated', () {
      const tree = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'c1',
            habitId: 'walk',
            window: window,
            targetCount: 4,
          ),
          GoalCriterion.anyOf(
            criterionId: 'any',
            criteria: [
              GoalCriterion.habit(
                criterionId: 'c2',
                habitId: 'gym',
                window: window,
                targetCount: 2,
              ),
              GoalCriterion.habit(
                criterionId: 'c3',
                habitId: 'walk',
                window: window,
                targetCount: 1,
              ),
            ],
          ),
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: window,
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 10000,
          ),
        ],
      );
      expect(goalCriterionHabitIds(tree), {'walk', 'gym'});
    });

    test('signal-only criteria claim nothing', () {
      expect(
        goalCriterionHabitIds(
          const GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: window,
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 10000,
          ),
        ),
        isEmpty,
      );
      expect(
        goalCriterionHabitIds(
          const GoalCriterion.measurable(
            criterionId: 'weight',
            dataTypeId: 'weight-type',
            window: window,
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 80,
          ),
        ),
        isEmpty,
      );
      expect(
        goalCriterionHabitIds(
          const GoalCriterion.categoryTime(
            criterionId: 'writing-time',
            categoryId: 'category-1',
            window: window,
            aggregation: GoalAggregation.dailySumThenAverage,
            targetHours: 2,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('unifiedGoalSummary', () {
    test('no-data goals get the setup nudge — unless a standing one-liner '
        'already describes the goal (never contradict it)', () {
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.noData,
          progress: null,
        ),
        'No data yet — record a habit or connect a signal to start tracking.',
      );
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.noData,
          progress: null,
          oneLiner: 'Waiting on the first step samples.',
        ),
        'Waiting on the first step samples.',
      );
    });

    test('habit goals summarise the on-track fraction from live state', () {
      final progress = GoalProgressView(
        today: DateTime.utc(2026, 8, 15),
        habits: [
          habitView(successes: 4),
          habitView(successes: 2),
        ],
      );
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.behind,
          progress: progress,
          // The one-liner must NOT win over the deterministic template for
          // habit goals — generated prose is a detail-page privilege.
          oneLiner: 'The gym has been quiet.',
        ),
        '1 of 2 habits on track',
      );
    });

    test('all habits at rate reads as the all-on-track line — but ONLY '
        'beside an on-track pill', () {
      final progress = GoalProgressView(
        today: DateTime.utc(2026, 8, 15),
        habits: [habitView(successes: 4), habitView(successes: 5)],
      );
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.onTrack,
          progress: progress,
        ),
        'All 2 habits on track — nothing needed today.',
      );
      // Right after a quick-complete the live projection reaches full count
      // while the pill still carries the persisted Behind register: the
      // summary stays a factual fraction, never an all-clear the pill
      // contradicts.
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.behind,
          progress: progress,
        ),
        '2 of 2 habits on track',
      );
    });

    test('mixed goals (habit AND metric dimensions) defer to the standing '
        'one-liner — a habit-only fraction could contradict the pill', () {
      final progress = GoalProgressView(
        today: DateTime.utc(2026, 8, 15),
        habits: [habitView(successes: 4)],
        metric: const GoalMetricProgressView(
          name: 'Step count',
          target: 10000,
          days: [],
        ),
      );
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.behind,
          progress: progress,
          oneLiner: 'The steps average is lagging.',
        ),
        'The steps average is lagging.',
      );
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.behind,
          progress: progress,
        ),
        isNull,
      );
    });

    test('goals without habit dimensions fall back to the standing '
        'one-liner, or render no line at all', () {
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.onTrack,
          progress: GoalProgressView(today: DateTime.utc(2026, 8, 15)),
          oneLiner: 'Averaging 11k steps.',
        ),
        'Averaging 11k steps.',
      );
      expect(
        unifiedGoalSummary(
          messages,
          status: UnifiedGoalStatus.onTrack,
          progress: GoalProgressView(today: DateTime.utc(2026, 8, 15)),
          oneLiner: '   ',
        ),
        isNull,
      );
    });
  });

  group('UnifiedGoalStatusPill', () {
    testWidgets('Behind is the only solid fill and folds the recovery hint '
        'into its label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const UnifiedGoalStatusPill(
            status: UnifiedGoalStatus.behind,
            recoveryHint: '2 days to recover',
          ),
        ),
      );

      expect(find.text('Behind · 2 days to recover'), findsOneWidget);
      final tokens = resolveTestTheme().extension<DsTokens>()!;
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Behind · 2 days to recover'),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      // Solid warning fill with the on-alert ink — the strongest signal on
      // the card, still not a red.
      expect(decoration.color, tokens.colors.alert.warning.defaultColor);
      expect(
        tester
            .widget<Text>(find.text('Behind · 2 days to recover'))
            .style
            ?.color,
        tokens.colors.text.onInteractiveAlert,
      );
    });

    testWidgets('At risk keeps the wash fill but still folds the hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const UnifiedGoalStatusPill(
            status: UnifiedGoalStatus.atRisk,
            recoveryHint: '1 day of buffer',
          ),
        ),
      );

      expect(find.text('At risk · 1 day of buffer'), findsOneWidget);
      final tokens = resolveTestTheme().extension<DsTokens>()!;
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('At risk · 1 day of buffer'),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.color,
        tokens.colors.alert.warning.defaultColor.withValues(
          alpha: SurfaceAlphas.washChip,
        ),
      );
      expect(
        tester
            .widget<Text>(find.text('At risk · 1 day of buffer'))
            .style
            ?.color,
        tokens.colors.text.highEmphasis,
      );
    });

    testWidgets('an on-track pill never renders a hint — the glance budget '
        'rule', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const UnifiedGoalStatusPill(
            status: UnifiedGoalStatus.onTrack,
            recoveryHint: '3 days of buffer',
          ),
        ),
      );

      expect(find.text('On track'), findsOneWidget);
      expect(find.textContaining('buffer'), findsNothing);
    });
  });
}
