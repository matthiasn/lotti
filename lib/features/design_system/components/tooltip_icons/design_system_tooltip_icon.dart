import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

const _kIconSize = 16.0;

/// The design-system's help glyph — a small token-colored icon that reveals
/// [message] in a tooltip on hover/long-press.
///
/// Defaults to a rounded help-outline [icon] and exposes itself as a labelled
/// button to semantics ([semanticsLabel], falling back to [message]).
class DesignSystemTooltipIcon extends StatelessWidget {
  const DesignSystemTooltipIcon({
    required this.message,
    this.icon,
    this.semanticsLabel,
    super.key,
  });

  final String message;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Tooltip(
      message: message,
      child: Semantics(
        label: semanticsLabel ?? message,
        button: true,
        child: Icon(
          icon ?? Icons.help_outline_rounded,
          size: _kIconSize,
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
