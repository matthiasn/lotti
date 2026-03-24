import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

const _kThumbAlpha = 0.64;
const _kThumbRadius = Radius.circular(10);
const _kTrackPadding = 2.0;

enum DesignSystemScrollbarSize {
  small,
  defaultSize,
}

class DesignSystemScrollbar extends StatelessWidget {
  const DesignSystemScrollbar({
    required this.child,
    this.controller,
    this.size = DesignSystemScrollbarSize.defaultSize,
    this.thumbVisibility,
    super.key,
  });

  final Widget child;
  final ScrollController? controller;
  final DesignSystemScrollbarSize size;
  final bool? thumbVisibility;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spec = _ScrollbarSpec.fromTokens(tokens, size);

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(spec.thumbColor),
        thickness: WidgetStatePropertyAll(spec.thumbThickness),
        radius: _kThumbRadius,
        crossAxisMargin: _kTrackPadding,
        mainAxisMargin: _kTrackPadding,
        minThumbLength: spec.minThumbLength,
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: thumbVisibility,
        child: child,
      ),
    );
  }
}

class _ScrollbarSpec {
  const _ScrollbarSpec({
    required this.thumbColor,
    required this.thumbThickness,
    required this.minThumbLength,
  });

  factory _ScrollbarSpec.fromTokens(
    DsTokens tokens,
    DesignSystemScrollbarSize size,
  ) {
    final thumbColor = tokens.colors.text.highEmphasis.withValues(
      alpha: _kThumbAlpha,
    );

    return switch (size) {
      DesignSystemScrollbarSize.small => _ScrollbarSpec(
        thumbColor: thumbColor,
        thumbThickness: tokens.spacing.step2,
        minThumbLength: tokens.spacing.step9,
      ),
      DesignSystemScrollbarSize.defaultSize => _ScrollbarSpec(
        thumbColor: thumbColor,
        thumbThickness: tokens.spacing.step3,
        minThumbLength: tokens.spacing.step12,
      ),
    };
  }

  final Color thumbColor;
  final double thumbThickness;
  final double minThumbLength;
}
