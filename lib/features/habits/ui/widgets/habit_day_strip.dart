import 'package:flutter/material.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Compact day-strip used by the habits card and the completion dialog.
///
/// Renders one cell per [HabitResult] in chronological order. The cell color
/// is sourced from [habitCompletionColor] so it stays in lock-step with the
/// stacked-area chart at the top of the habits tab.
class HabitDayStrip extends StatelessWidget {
  const HabitDayStrip({
    required this.results,
    this.showGaps = true,
    this.showLabels = false,
    this.cellHeight = 14,
    this.onTapDay,
    this.semanticPrefix,
    super.key,
  });

  final List<HabitResult> results;
  final bool showGaps;
  final bool showLabels;
  final double cellHeight;
  final void Function(String dayString)? onTapDay;

  /// Prepended to each cell's accessibility label (e.g. the habit name) so
  /// screen readers announce "Audio Journal 2026-05-22" rather than a bare
  /// date.
  final String? semanticPrefix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final days = results.length;

    final gap = showGaps
        ? SizedBox(
            width: days < 20
                ? 4
                : days < 40
                ? 2
                : 1,
          )
        : const SizedBox.shrink();

    final cells = results.map((res) {
      final cell = ClipRRect(
        borderRadius: BorderRadius.circular(showGaps ? tokens.radii.xs : 0),
        child: Container(
          height: cellHeight,
          color: habitCompletionColor(tokens, res.completionType),
        ),
      );

      final labelled = Semantics(
        label: semanticPrefix == null
            ? res.dayString
            : '$semanticPrefix ${res.dayString}',
        child: cell,
      );

      final wrapped = onTapDay == null
          ? labelled
          : GestureDetector(
              onTap: () => onTapDay!(res.dayString),
              child: labelled,
            );

      return Flexible(
        child: Tooltip(
          excludeFromSemantics: true,
          message: chartDateFormatter(res.dayString),
          child: wrapped,
        ),
      );
    });

    final strip = Row(children: intersperse(gap, cells).toList());

    if (!showLabels) {
      return strip;
    }

    final monoStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    return Row(
      children: [
        Text(context.messages.habitsCardStripDaysLabel(days), style: monoStyle),
        SizedBox(width: tokens.spacing.step2),
        Expanded(child: strip),
        SizedBox(width: tokens.spacing.step2),
        Text(context.messages.habitsCardStripNowLabel, style: monoStyle),
      ],
    );
  }
}
