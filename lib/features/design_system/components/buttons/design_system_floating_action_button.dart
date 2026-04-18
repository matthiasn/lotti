import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemFloatingActionButton extends StatefulWidget {
  const DesignSystemFloatingActionButton({
    required this.semanticLabel,
    this.onPressed,
    this.icon = Icons.add_rounded,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  State<DesignSystemFloatingActionButton> createState() =>
      _DesignSystemFloatingActionButtonState();
}

class _DesignSystemFloatingActionButtonState
    extends State<DesignSystemFloatingActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemFloatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onPressed != null;
    final dimension =
        tokens.typography.lineHeight.subtitle1 + (tokens.spacing.step5 * 2);
    final backgroundColor = switch ((_pressed, _hovered)) {
      (_, _) when !enabled => tokens.colors.interactive.enabled,
      (true, _) => tokens.colors.interactive.pressed,
      (_, true) => tokens.colors.interactive.hover,
      _ => tokens.colors.interactive.enabled,
    };

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled
            ? (_) => setState(() {
                _hovered = false;
                _pressed = false;
              })
            : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: dimension,
            height: dimension,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.xl),
              color: backgroundColor,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.radii.xl),
              onTap: widget.onPressed,
              onHighlightChanged: enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: Center(
                child: Icon(
                  widget.icon,
                  size: tokens.typography.lineHeight.subtitle1,
                  color: tokens.colors.text.onInteractiveAlert,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      return button;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: button,
    );
  }
}
