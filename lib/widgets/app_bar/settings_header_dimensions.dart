import 'package:lotti/themes/theme.dart';

/// Centralized dimensions and helpers for SettingsPageHeader.
///
/// This groups all spacing constants and layout breakpoints so they can be
/// tuned consistently and referenced across files. Each value is documented
/// with its intended role in the header layout.
class SettingsHeaderDimensions {
  // Cap for title font size to avoid overly large headings on desktop.
  // Use the same maximum as on mobile to keep spacing predictable.
  // Align the header title with other title labels in the app.
  // Use the same maximum as card/list titles to keep visual hierarchy
  // consistent across mobile and desktop.
  static const double mobileMaxTitleSize = AppTheme.titleFontSize;
  // Spacing above the title block inside the flexible space area.
  // Use a touch more space when there is no `bottom` widget (e.g., simple
  // list pages). Pages with a bottom accessory (chips/segments) already feel
  // visually anchored, so we keep them tighter.
  static const double topSpacingWithBottom = 6;
  static const double topSpacingNoBottom = 12;

  // Gap between title and subtitle.
  static const double subtitleGap = 8;

  // Gap between subtitle and a provided bottom widget (e.g., segmented chips).
  static const double subtitleBottomGapWithBottom = 8;

  // Tiny spacer above the bottom widget to separate from the header container.
  static const double bottomShim = 2;

  // Gap between the back button and the title block.
  static const double backButtonGap = 8;

  // Unified paddings when the header is fully collapsed, so the title/back
  // row sits at a consistent vertical position.
  // Different top padding for pages with/without a `bottom` accessory.
  static const double collapsedTopPaddingWithBottom = 0;
  static const double collapsedTopPaddingNoBottom = 4;
  static const double collapsedBottomPaddingWithBottom = 15;
  static const double collapsedBottomPadding = 10;

  // Tiny extra height to counteract fractional pixel rounding differences
  // between computed text metrics and the final render box sizes on desktop.
  // Prevents rare "bottom overflowed by <1px" banners.
  static const double antiOverflowEpsilon = 2;

  // Footer spacing when a subtitle is present but no bottom widget is provided.
  static const double footerWithSubtitle = 12;

  // Footer spacing when neither subtitle nor bottom widget is provided.
  static const double footerNoSubtitle = 10;

  // Minimum collapsed body height when a subtitle exists (excludes top inset).
  // Ensure the toolbar remains comfortably tappable when pinned.
  static const double collapsedMinWithSubtitle = 56;

  // Minimum collapsed body height when no subtitle exists (excludes top inset).
  static const double collapsedMinNoSubtitle = 56;

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
    // Original responsive scale (pre‑cap)
    double size;
    if (width >= 1600) {
      size = 46;
    } else if (width >= 1200) {
      size = 42;
    } else if (width >= 992) {
      size = 38;
    } else if (wide) {
      size = 34;
    } else if (width >= 600) {
      size = 32;
    } else if (width >= 420) {
      size = 30;
    } else {
      size = 28;
    }

    // Cap desktop/tablet sizes to the mobile maximum to prevent
    // overflow and excessive spacing on large screens.
    return size.clamp(0, mobileMaxTitleSize).toDouble();
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
