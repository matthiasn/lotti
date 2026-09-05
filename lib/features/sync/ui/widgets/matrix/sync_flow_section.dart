import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The sync feature's card container, on the design-system section-card
/// surface.
///
/// Delegates its material — `background.level02`, hairline
/// `decorative.level01` border, section-card radius, no shadow — to
/// [DesignSystemSectionCard], so every sync card restyles with the design
/// system instead of holding its own `colorScheme` + literal-alpha copy.
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
    final resolvedPadding =
        padding ?? EdgeInsets.all(tokens.spacing.cardPadding);

    final content = Padding(padding: resolvedPadding, child: child);

    // Padding stays on this side of the delegation so the accent bar can
    // live in the padding gutter: a flagged card keeps the exact content
    // rail of its unflagged siblings.
    return DesignSystemSectionCard(
      padding: EdgeInsets.zero,
      child: accent == null
          ? content
          : Stack(
              children: [
                content,
                Positioned(
                  left: (tokens.spacing.cardPadding - tokens.spacing.step2) / 2,
                  top: tokens.spacing.cardPadding,
                  bottom: tokens.spacing.cardPadding,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                    ),
                    child: SizedBox(width: tokens.spacing.step2),
                  ),
                ),
              ],
            ),
    );
  }
}
