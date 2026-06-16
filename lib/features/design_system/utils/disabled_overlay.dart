import 'package:flutter/widgets.dart';

/// Widget extension for applying the design system's standard disabled dimming.
extension DesignSystemDisabledOverlay on Widget {
  /// Returns this widget unchanged when [enabled], or wrapped in an [Opacity]
  /// at [disabledOpacity] when disabled — the shared way DS controls signal a
  /// disabled state.
  Widget withDisabledOpacity({
    required bool enabled,
    required double disabledOpacity,
  }) {
    if (enabled) return this;
    return Opacity(opacity: disabledOpacity, child: this);
  }
}
