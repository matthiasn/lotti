import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// "N of M habits completed today · X failed · Y skipped" — the redesign's
/// post-chart summary line. Hides the failed/skipped chunks when their counts
/// are zero so the line stays compact.
class HabitsSummaryLine extends ConsumerWidget {
  const HabitsSummaryLine({this.todayOverride, super.key});

  /// Optional explicit "today" used by tests to keep counts deterministic.
  final DateTime? todayOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsControllerProvider);
    final tokens = context.designTokens;

    final today = (todayOverride ?? DateTime.now()).ymd;
    final total = state.habitDefinitions.length;
    final done = state.completedToday.length;
    final failed = state.failedByDay[today]?.length ?? 0;
    final skipped = state.skippedByDay[today]?.length ?? 0;

    final neutralStyle = tokens.typography.styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    final chunks = <Widget>[
      Text(
        context.messages.habitsSummaryCompleted(done, total),
        style: neutralStyle.copyWith(
          color: tokens.colors.text.highEmphasis,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (failed > 0)
        Text(
          context.messages.habitsSummaryFailed(failed),
          style: neutralStyle.copyWith(
            color: tokens.colors.alert.error.defaultColor,
          ),
        ),
      if (skipped > 0)
        Text(
          context.messages.habitsSummarySkipped(skipped),
          style: neutralStyle.copyWith(
            color: tokens.colors.alert.warning.defaultColor,
          ),
        ),
    ];

    final dot = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
      child: Text(
        '·',
        style: neutralStyle.copyWith(color: tokens.colors.text.lowEmphasis),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: intersperse(dot, chunks).toList(),
      ),
    );
  }
}
