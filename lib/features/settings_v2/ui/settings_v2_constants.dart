import 'package:flutter/foundation.dart';

/// Shared visual constants for Settings V2.
///
/// Every fixed dp / ms / alpha literal referenced from more than one
/// widget — or pinned by the spec — lives here so widgets stay free of
/// magic numbers and callers can trust a single source of truth. These
/// are not yet promoted into the generated design-token set; that
/// migration happens when Settings V2 graduates from the
/// `enable_settings_tree` flag.
@immutable
class SettingsV2Constants {
  const SettingsV2Constants._();

  /// Header height (spec §2).
  static const double headerHeight = 56;

  /// Row height (spec §3).
  static const double rowHeight = 62;

  /// Icon tile size (spec §3 "Row anatomy").
  static const double iconTileSize = 36;
  static const double iconTileGlyphSize = 20;

  /// Active rail (spec §3: 3 dp teal bar, 30 dp tall when on path).
  static const double activeRailWidth = 3;
  static const double activeRailHeight = 30;
  static const double activeRailCornerRadius = 1.5;

  /// Chevron glyph size.
  static const double chevronSize = 18;

  /// Badge chip.
  static const double badgeHeight = 20;

  /// Nested-children indent rail.
  static const double childrenRailWidth = 1.5;
  static const double childrenRailAlpha = 0.28;

  /// Row fill alpha when on the active path.
  static const double activeRowFillAlpha = 0.08;

  /// Icon tile fill alpha when on the active path.
  static const double activeTileFillAlpha = 0.16;

  /// Badge background alpha (all tones share the same fill-to-text
  /// contrast ratio).
  static const double badgeBackgroundAlpha = 0.16;

  /// Animation durations (spec §3 "Motion").
  static const Duration rowFillTransition = Duration(milliseconds: 180);
  static const Duration railTransition = Duration(milliseconds: 200);
  static const Duration chevronRotation = Duration(milliseconds: 220);
  static const Duration branchSizeAnimation = Duration(milliseconds: 260);
  static const Duration branchOpacityAnimation = Duration(milliseconds: 200);

  /// Resize-handle bar fade duration.
  static const Duration resizeHandleFade = Duration(milliseconds: 150);

  /// Resize-handle bar alpha on hover.
  static const double resizeHandleHoverAlpha = 0.4;

  /// Resize-handle hit-target width (spec §3.1) and the visible bar
  /// width that fades in on hover / drag.
  static const double resizeHandleHitWidth = 6;
  static const double resizeHandleBarWidth = 2;

  /// Icon size for the empty-state / unimplemented-panel glyph in
  /// the detail placeholder.
  static const double placeholderIconSize = 36;

  /// Icon size for the "Disable Settings V2" escape-hatch button.
  static const double placeholderButtonIconSize = 18;
}
