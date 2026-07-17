import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The design system's one empty-state grammar: a quiet glyph, an optional
/// `subtitle1` title, an optional `caption` hint, and an optional action.
///
/// Every empty surface — list zero-states, desktop detail panes with nothing
/// selected — composes this instead of hand-rolling its own icon/text ramp,
/// so two empty blocks visible in one frame can never speak two typographic
/// dialects.
class DesignSystemEmptyState extends StatelessWidget {
  const DesignSystemEmptyState({
    required this.icon,
    this.title,
    this.hint,
    this.action,
    super.key,
  });

  final IconData icon;

  /// Primary line at `subtitle1` / high emphasis. Omit for a deferential
  /// block (e.g. a pane whose sibling already carries the message) — the
  /// hint then stands alone at caption tier.
  final String? title;

  /// Secondary line at `caption` / medium emphasis.
  final String? hint;

  /// Optional call to action rendered under the text.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: tokens.spacing.step9,
              color: tokens.colors.text.lowEmphasis,
            ),
            if (title != null) ...[
              SizedBox(height: tokens.spacing.step5),
              Text(
                title!,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ],
            if (hint != null) ...[
              SizedBox(
                height: title != null
                    ? tokens.spacing.step3
                    : tokens.spacing.step5,
              ),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: tokens.spacing.step6),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
