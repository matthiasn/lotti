import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';

export 'generated/design_tokens.g.dart';
export 'motion_tokens.dart';

/// Convenience access to the design-system tokens from any [BuildContext].
extension DesignTokensBuildContextExtension on BuildContext {
  /// The `DsTokens` registered on the active theme.
  ///
  /// Throws a [StateError] if the theme was not built by `DesignSystemTheme`
  /// and therefore lacks the `DsTokens` extension.
  DsTokens get designTokens {
    final tokens = Theme.of(this).extension<DsTokens>();
    if (tokens == null) {
      throw StateError('DsTokens extension is missing from the active theme.');
    }
    return tokens;
  }
}
