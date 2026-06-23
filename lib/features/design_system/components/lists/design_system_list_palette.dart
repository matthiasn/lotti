import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Shared palette values for design-system list surfaces.
///
/// Kept in one place so the task list, settings list, and any future
/// list-style surface derive their "activated / selected row" fill from
/// the same source — avoiding drift between hand-tuned alpha values
/// scattered across feature modules.
class DesignSystemListPalette {
  const DesignSystemListPalette._();

  /// Alpha applied to `tokens.colors.interactive.enabled` to produce the
  /// subdued "selected row" fill. 12 % opacity is intentionally lighter
  /// than the generated `surface.selected` token so selection reads as a
  /// gentle hint rather than a loud block — matching the task list's
  /// established treatment.
  static const double activatedFillAlpha = 0.12;

  /// Stronger alpha for surfaces where the activated row is *the* semantic
  /// signal a user scans for (e.g. the current-default model in the AI model
  /// picker), and the gentle [activatedFillAlpha] loses too much of the
  /// interactive accent's chroma over a near-black background to read as
  /// "selected". Opt in per call site via [activatedFillStrong].
  static const double activatedFillStrongAlpha = 0.18;

  /// Computed default fill used when a list row is activated/selected.
  static Color activatedFill(DsTokens tokens) =>
      tokens.colors.interactive.enabled.withValues(alpha: activatedFillAlpha);

  /// Computed stronger fill for rows whose activated state carries primary
  /// meaning. See [activatedFillStrongAlpha].
  static Color activatedFillStrong(DsTokens tokens) => tokens
      .colors
      .interactive
      .enabled
      .withValues(alpha: activatedFillStrongAlpha);
}
