import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';

/// The sync feature's card container: token-padded, rounded, softly elevated.
///
/// [accentColor] replaces the default hairline outline — used to mark a card
/// that needs attention (e.g. a device that blocks sync) at container level.
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
        border: Border.all(
          color:
              accentColor ??
              context.colorScheme.outline.withValues(alpha: 0.16),
          // The attention state is weight + hue, not hue alone.
          width: accentColor != null ? tokens.spacing.step1 : 1,
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
        child: child,
      ),
    );
  }
}
