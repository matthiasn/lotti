import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A small translucent pill rendered over a cover photo. With [dotColor] it
/// reads as a category tag; without it, as a neutral info chip (e.g. an
/// upcoming-event date or a status). Shared by the overview cards and the
/// detail hero so overlay chrome stays consistent.
class EventOverlayPill extends StatelessWidget {
  const EventOverlayPill({required this.label, this.dotColor, super.key});

  final String label;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: tokens.spacing.step1),
          ],
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
