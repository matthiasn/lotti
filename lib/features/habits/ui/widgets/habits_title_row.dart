import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Top-of-page row for the Habits tab: `Habits · YYYY-MM-DD`.
///
/// The title uses display-level typography and the date is muted so it reads
/// as a secondary anchor without competing for attention.
class HabitsTitleRow extends StatelessWidget {
  const HabitsTitleRow({this.todayOverride, super.key});

  /// Optional explicit "today" used by tests to keep snapshots deterministic.
  final DateTime? todayOverride;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final today = todayOverride ?? DateTime.now();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step4,
        tokens.spacing.step4,
        tokens.spacing.step4,
        tokens.spacing.step2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            context.messages.settingsHabitsTitle,
            style: tokens.typography.styles.display.display2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            '·',
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            today.ymd,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
