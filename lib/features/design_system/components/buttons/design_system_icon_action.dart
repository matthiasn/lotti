import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Compact icon-only action for card headers and panel corners — the stats
/// refresh control is the reference use.
///
/// Sits below `DesignSystemButton`: it carries no label and no variant, so it
/// cannot read as a surface's primary action. Where a caption-tier *labelled*
/// row is wanted instead, reach for `DesignSystemInlineAction`.
///
/// The busy state swaps the glyph for a spinner of the same dimension, so the
/// button does not resize under the pointer mid-action.
///
/// The glyph stays compact but the pointer target is [TapTargets.minimum]
/// square. An icon-only control has no label to widen its hit area, so without
/// that floor the whole target would be the 16dp glyph — well under the
/// recommended minimum on touch devices.
///
/// [tooltip] doubles as the semantic label, published on an explicit button
/// node with the visual subtree excluded beneath it. The tooltip and the
/// spinner would otherwise each contribute their own node, and none of them
/// would say `button`.
class DesignSystemIconAction extends StatelessWidget {
  const DesignSystemIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isBusy = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;

  /// A null callback disables the control and drops its glyph to the
  /// low-emphasis step.
  final VoidCallback? onPressed;

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = onPressed != null;
    final foreground = enabled
        ? tokens.colors.text.mediumEmphasis
        : tokens.colors.text.lowEmphasis;

    void handleTap() {
      HapticFeedback.selectionClick();
      onPressed!();
    }

    return Semantics(
      container: true,
      button: true,
      label: tooltip,
      enabled: enabled,
      onTap: enabled ? handleTap : null,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.radii.smallChips),
              onTap: enabled ? handleTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: TapTargets.minimum,
                  minHeight: TapTargets.minimum,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: isBusy
                      ? const DesignSystemSpinner(
                          size: IconSizes.s,
                          strokeWidth: BorderWidths.emphasis,
                        )
                      : Icon(icon, size: IconSizes.s, color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
