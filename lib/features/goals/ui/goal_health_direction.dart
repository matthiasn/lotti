import 'package:flutter/material.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The independent direction hue. A goal can be behind while improving or
/// healthy while slipping, so direction never borrows the status hue.
Color goalHealthDirectionColor(
  GoalHealthDirection direction,
  DsColors colors,
) => switch (direction) {
  GoalHealthDirection.up => colors.alert.success.defaultColor,
  GoalHealthDirection.flat => colors.text.lowEmphasis,
  GoalHealthDirection.down => colors.alert.warning.defaultColor,
};

/// The Material icon for a direction, stroked in the chip's hue by the row.
IconData goalHealthDirectionIcon(GoalHealthDirection direction) =>
    switch (direction) {
      GoalHealthDirection.up => Icons.trending_up_rounded,
      GoalHealthDirection.flat => Icons.trending_flat_rounded,
      GoalHealthDirection.down => Icons.trending_down_rounded,
    };

/// The screen-reader label for a trend direction — the arrow is otherwise the
/// row's only signal that attainment is rising, holding, or falling, and it
/// carries no text a screen reader can announce on its own.
String goalHealthDirectionLabel(
  AppLocalizations messages,
  GoalHealthDirection direction,
) => switch (direction) {
  GoalHealthDirection.up => messages.goalHealthTrendUp,
  GoalHealthDirection.flat => messages.goalHealthTrendFlat,
  GoalHealthDirection.down => messages.goalHealthTrendDown,
};

/// A separate trend pill for the goal's direction of travel.
class GoalHealthDirectionChip extends StatelessWidget {
  const GoalHealthDirectionChip({required this.direction, super.key});

  final GoalHealthDirection direction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = goalHealthDirectionColor(direction, tokens.colors);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: SurfaceAlphas.washChip),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            goalHealthDirectionIcon(direction),
            size: IconSizes.xs,
            color: tokens.colors.text.highEmphasis,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            goalHealthDirectionLabel(context.messages, direction),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
