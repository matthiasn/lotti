import 'package:flutter/material.dart';

class DesignSystemAiAssistantButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: enabled,
      image: !enabled,
      enabled: enabled,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: buttonSize,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: OverflowBox(
              minWidth: assetExtent,
              maxWidth: assetExtent,
              minHeight: assetExtent,
              maxHeight: assetExtent,
              child: ExcludeSemantics(
                child: Image.asset(
                  assetName,
                  width: assetExtent,
                  height: assetExtent,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
