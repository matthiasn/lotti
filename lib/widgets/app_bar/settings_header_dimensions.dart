/// Responsive page padding retained for the legacy settings layout.
abstract final class SettingsHeaderDimensions {
  /// Returns the responsive horizontal content padding for the given
  /// available `width`. Still used by `SettingsPageLayout` to align the
  /// body content grid across pane widths.
  static double horizontalPadding(double width) {
    if (width >= 1600) return 160;
    if (width >= 1200) return 120;
    if (width >= 992) return 88;
    if (width >= 720) return 56;
    if (width >= 540) return 36;
    if (width >= 420) return 28;
    return 20;
  }
}
