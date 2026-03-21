import 'package:flutter/widgets.dart';

extension DesignSystemDisabledOverlay on Widget {
  Widget withDisabledOpacity({
    required bool enabled,
    required double disabledOpacity,
  }) {
    if (enabled) return this;
    return Opacity(opacity: disabledOpacity, child: this);
  }
}
