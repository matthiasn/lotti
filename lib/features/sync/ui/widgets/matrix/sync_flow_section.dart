import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';

/// The sync feature's card container: token-padded, rounded, softly elevated.
///
/// [accentColor] draws a rounded edge bar along the leading side — used to
/// mark a card that needs attention (e.g. a device that blocks sync) without
/// borrowing the outlined grammar of message callouts.
class SyncFlowSection extends StatelessWidget {
  const SyncFlowSection({
    required this.child,
    super.key,
    this.padding,
    this.accentColor,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = accentColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.spacing.cardPadding),
        child: accent == null
            ? child
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(
                          tokens.radii.badgesPills,
                        ),
                      ),
                      child: SizedBox(width: tokens.spacing.step2),
                    ),
                    SizedBox(width: tokens.spacing.step4),
                    Expanded(child: child),
                  ],
                ),
              ),
      ),
    );
  }
}
