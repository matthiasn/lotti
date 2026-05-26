import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Small teal pill (`✦ why`) that opens a popover showing the verbatim
/// `reason` string the agent attached to a placed block.
///
/// Mandatory on every AI placement — the absence of a reason should
/// surface as a missing WhyChip in production (the underlying tool
/// handler refuses to place an ai block without one).
class WhyChip extends StatelessWidget {
  const WhyChip({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    return Tooltip(
      message: reason,
      preferBelow: false,
      decoration: BoxDecoration(
        color: tokens.colors.background.level03,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: teal.withValues(alpha: 0.32)),
      ),
      textStyle: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      padding: EdgeInsets.all(tokens.spacing.step3),
      margin: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      waitDuration: const Duration(milliseconds: 100),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step2,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          color: teal.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(tokens.radii.s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 10, color: teal),
            SizedBox(width: tokens.spacing.step1),
            Text(
              context.messages.dailyOsNextDayWhyChipLabel,
              style: tokens.typography.styles.others.overline.copyWith(
                color: teal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
