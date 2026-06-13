import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Token-driven section card for settings definition forms.
///
/// Replaces the legacy `LottiFormSection` on the definitions pages: a
/// quiet overline header (title, optional description) above a grouped
/// card that mirrors `DesignSystemGroupedList`'s surface (background
/// level02, decorative hairline, radii.m), so detail forms and list pages
/// share one visual language.
class SettingsFormSection extends StatelessWidget {
  const SettingsFormSection({
    required this.title,
    required this.children,
    this.description,
    super.key,
  });

  /// Section heading shown above the card.
  final String title;

  /// Optional one-liner under the title explaining the section.
  final String? description;

  /// Form rows inside the card, separated by `cardItemSpacing`.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiet header flush with the card edge: one left rail; size
          // and color grade section vs field (field labels are bold
          // high-emphasis). Caption tracking — heavy letter-spacing on
          // sentence case reads as a kerning bug, and a wrapped tracked
          // overline reads as broken, so the title stays on one line.
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: spacing.step3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // A real step above the caption helper (size + weight)
                  // while color keeps it quieter than the high-emphasis
                  // field labels inside the card.
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                if (description != null) ...[
                  SizedBox(height: spacing.step1),
                  Text(
                    description!,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.m),
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) SizedBox(height: spacing.cardItemSpacing),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
