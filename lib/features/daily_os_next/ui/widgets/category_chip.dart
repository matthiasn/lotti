import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Small tinted chip that shows the category name in the category's
/// own colour.
///
/// `colorHex` on [DayAgentCategory] is intentionally a plain hex
/// string so the agent layer stays platform-agnostic; this widget is
/// the single place that lifts it into a Flutter [Color].
class CategoryChip extends StatelessWidget {
  const CategoryChip({required this.category, super.key});

  final DayAgentCategory category;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = _parseHex(category.colorHex);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            category.name,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseHex(String hex) => categoryColorFromHex(hex);
}
