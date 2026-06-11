import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Category tag: a neutral pill in which only the leading dot carries the
/// category colour. Category colours are user data, so a tinted pill would
/// collide with the fixed status-badge palette on the same cards.
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
        color: tokens.colors.surface.enabled,
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
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseHex(String hex) => categoryColorFromHex(hex);
}
