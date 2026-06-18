import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Section divider for the grouped habit lists ("Due now", "Later today",
/// "Completed"). The label leads with high-emphasis subtitle weight so the
/// grouping that should guide the eye stays louder than the rows it chunks; the
/// count sits beside it in a quiet pill so each bucket's size reads at a glance.
class HabitsSectionHeader extends StatelessWidget {
  const HabitsSectionHeader({
    required this.label,
    required this.count,
    super.key,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step2,
        top: tokens.spacing.step6,
        bottom: tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: tokens.typography.weight.semiBold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level03,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step1,
              ),
              child: Text(
                '$count',
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
