import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class DesignSystemAiAssistantButton extends StatefulWidget {
  const DesignSystemAiAssistantButton({
    required this.assetName,
    required this.semanticLabel,
    this.onPressed,
    super.key,
  });

  static const buttonSize = 56.0;
  static const assetExtent = 108.0;

  final String assetName;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  State<DesignSystemAiAssistantButton> createState() =>
      _DesignSystemAiAssistantButtonState();
}

class _DesignSystemAiAssistantButtonState
    extends State<DesignSystemAiAssistantButton> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant DesignSystemAiAssistantButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && _hovered) {
      _hovered = false;
    }
  }

  void _handleKeyActivate() {
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final tokens = context.designTokens;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: SizedBox.square(
        dimension: DesignSystemAiAssistantButton.buttonSize,
        child: Focus(
          canRequestFocus: enabled,
          onKeyEvent: enabled
              ? (node, event) {
                  if (event is KeyDownEvent &&
                      !HardwareKeyboard.instance.isControlPressed &&
                      !HardwareKeyboard.instance.isMetaPressed &&
                      !HardwareKeyboard.instance.isAltPressed &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.space)) {
                    _handleKeyActivate();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
              : null,
          child: MouseRegion(
            onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
            onExit: enabled ? (_) => setState(() => _hovered = false) : null,
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hovered
                      ? tokens.colors.surface.hover
                      : Colors.transparent,
                ),
                child: OverflowBox(
                  minWidth: DesignSystemAiAssistantButton.assetExtent,
                  maxWidth: DesignSystemAiAssistantButton.assetExtent,
                  minHeight: DesignSystemAiAssistantButton.assetExtent,
                  maxHeight: DesignSystemAiAssistantButton.assetExtent,
                  child: ExcludeSemantics(
                    child: Image.asset(
                      widget.assetName,
                      width: DesignSystemAiAssistantButton.assetExtent,
                      height: DesignSystemAiAssistantButton.assetExtent,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
