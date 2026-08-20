import 'package:flutter/material.dart';

/// Elevation design tokens: the shadows floating surfaces wear.
///
/// Hand-authored rather than generated, for the same reasons as
/// `sizing_tokens.dart`: elevation is not a Figma *variable* in this repo's
/// export — the generator reads exactly `color` / `typography` / `spacing` /
/// `borderRadius`, and fabricating variable entries in `tokens.json` would
/// misrepresent the export. A small named `const` set is the honest
/// representation and the single source of truth.
abstract final class DsShadows {
  /// The one soft shadow every floating surface wears. The context menu and
  /// the tooltip both promise to be *the same surface*, so they must share
  /// this token rather than each holding a private copy that can drift.
  static const List<BoxShadow> floatingSurface = [
    BoxShadow(
      color: Color.fromRGBO(70, 70, 70, 0.25),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];
}
