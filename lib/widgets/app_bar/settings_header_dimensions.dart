/// Centralized dimensions and helpers for SettingsPageHeader.
///
/// This groups all spacing constants and layout breakpoints so they can be
/// tuned consistently and referenced across files. Each value is documented
/// with its intended role in the header layout.
class SettingsHeaderDimensions {
  // Spacing above the title block inside the flexible space area.
  static const double topSpacing = 0;

  // Gap between title and subtitle.
  static const double subtitleGap = 6;

  // Gap between subtitle and a provided bottom widget (e.g., segmented chips).
  static const double subtitleBottomGapWithBottom = 4;

  // Tiny spacer above the bottom widget to separate from the header container.
  static const double bottomShim = 2;

  // Footer spacing when a subtitle is present but no bottom widget is provided.
  static const double footerWithSubtitle = 8;

  // Footer spacing when neither subtitle nor bottom widget is provided.
  static const double footerNoSubtitle = 6;

  // Minimum collapsed body height when a subtitle exists (excludes top inset).
  static const double collapsedMinWithSubtitle = 24;

  // Minimum collapsed body height when no subtitle exists (excludes top inset).
  static const double collapsedMinNoSubtitle = 24;

  /// Returns the responsive horizontal padding for the header content given
  /// the available `width`.
  static double horizontalPadding(double width) {
    if (width >= 1600) return 160;
    if (width >= 1200) return 120;
    if (width >= 992) return 88;
    if (width >= 720) return 56;
    if (width >= 540) return 36;
    if (width >= 420) return 28;
    return 20;
  }

  /// Returns the responsive title font size. When `wide` is true, uses wider
  /// desktop/tablet sizing at mid‑range widths.
  static double titleFontSize({required double width, required bool wide}) {
    if (width >= 1600) return 46;
    if (width >= 1200) return 42;
    if (width >= 992) return 38;
    if (wide) return 34;
    if (width >= 600) return 32;
    if (width >= 420) return 30;
    return 28;
  }

  /// Normalized collapse progress [0..1] for a flexible space with the given
  /// heights.
  static double collapseProgress(
    double expandedHeight,
    double collapsedHeight,
    double currentHeight,
  ) {
    final available = expandedHeight - collapsedHeight;
    if (available <= 0) return 1;
    final delta = expandedHeight - currentHeight;
    return (delta / available).clamp(0.0, 1.0);
  }
}
