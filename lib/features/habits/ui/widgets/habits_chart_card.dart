import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
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
  const HabitsChartCard({super.key});

  /// Time spans offered for the habits chart and the per-row history strips —
  /// short-to-quarter, habit-scale windows, unlike the months/quarters the
  /// Insights surface uses.
  static const List<int> timeSpans = [7, 14, 30, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(habitsControllerProvider);
    final controller = ref.read(habitsControllerProvider.notifier);

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
                    messages.habitsCompletionRateTitle,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                if (state.minY > 20)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: controller.toggleZeroBased,
                    icon: Icon(
                      state.zeroBased
                          ? MdiIcons.unfoldMoreHorizontal
                          : MdiIcons.unfoldLessHorizontal,
                      size: tokens.spacing.step5,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                SizedBox(width: tokens.spacing.step2),
                TimeSpanSegmentedControl(
                  timeSpanDays: state.timeSpanDays,
                  onValueChanged: controller.setTimeSpan,
                  segments: timeSpans,
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.step4),
            const HabitCompletionRateChart(),
          ],
        ),
      ),
    );
  }
}
