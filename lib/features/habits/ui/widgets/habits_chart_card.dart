import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';

/// The completion-rate line chart wrapped in the calm card shell used across
/// the app (Time Analysis chart card, KPI cards): a titled, bordered surface a
/// step lighter than the page, with the time-span switch in the header instead
/// of behind a hidden calendar toggle.
///
/// The chart itself ([HabitCompletionRateChart]) keeps its live per-day
/// breakdown caption; this card adds the title, the always-visible time-span
/// selector, and the optional zero-baseline toggle (only meaningful once the
/// lowest day clears the 20% floor).
class HabitsChartCard extends ConsumerWidget {
  const HabitsChartCard({
    this.habitIds,
    this.title,
    this.showTimeSpanPicker = true,
    super.key,
  });

  /// Hidden when a hosting page provides its own page-wide range control
  /// (the goal detail dashboard) — two pickers for one shared span would
  /// fight over the same state.
  final bool showTimeSpanPicker;

  /// When non-null, the card renders the §4b goal-scoped chart variant for
  /// these habits. The zero-baseline toggle hides in that mode — its gate
  /// reads the roster-wide floor, which says nothing about the scoped line.
  final Set<String>? habitIds;

  /// Card title override; defaults to the habits page's own.
  final String? title;

  /// Time spans offered for the habits chart and the per-row history strips —
  /// fortnight-to-quarter, habit-scale windows. (7 days was dropped: it's too
  /// short to read a trend, and the rolling average needs a week just to fill.)
  static const List<int> timeSpans = [14, 30, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);
    // Scoped mode: the habits state only carries ACTIVE definitions and
    // their completions. A goal whose referenced habits are all deactivated
    // would chart a fabricated all-zero line — suppress the card instead.
    // (A partially inactive set charts its active members honestly: the
    // inactive ids are absent from the day maps' denominators.)
    if (habitIds != null) {
      final activeIds = {for (final habit in state.habitDefinitions) habit.id};
      if (habitIds!.intersection(activeIds).isEmpty) {
        return const SizedBox.shrink();
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? messages.habitsCompletionRateTitle,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                if (habitIds == null && state.minY > 20)
                  Semantics(
                    label: state.zeroBased
                        ? messages.habitsChartUseDynamicBaseline
                        : messages.habitsChartUseZeroBaseline,
                    button: true,
                    toggled: state.zeroBased,
                    excludeSemantics: true,
                    onTap: controller.toggleZeroBased,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: controller.toggleZeroBased,
                      tooltip: state.zeroBased
                          ? messages.habitsChartUseDynamicBaseline
                          : messages.habitsChartUseZeroBaseline,
                      isSelected: state.zeroBased,
                      icon: Icon(
                        state.zeroBased
                            ? LottiIcons.expandBoth
                            : LottiIcons.collapseBoth,
                        size: tokens.spacing.step5,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                if (showTimeSpanPicker) ...[
                  SizedBox(width: tokens.spacing.step2),
                  TimeSpanSegmentedControl(
                    timeSpanDays: state.timeSpanDays,
                    onValueChanged: controller.setTimeSpan,
                    segments: timeSpans,
                  ),
                ],
              ],
            ),
            SizedBox(height: tokens.spacing.step4),
            HabitCompletionRateChart(habitIds: habitIds),
          ],
        ),
      ),
    );
  }
}
