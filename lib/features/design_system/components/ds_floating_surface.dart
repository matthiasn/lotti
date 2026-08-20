import 'package:flutter/material.dart';

/// The one soft shadow every design-system floating surface wears — the
/// context menu and the tooltip both promise to be *the same surface*, so
/// they must share these values rather than each holding a private copy that
/// can drift. The design system has no elevation-shadow token yet; until it
/// does, this constant is the single authority.
const List<BoxShadow> dsFloatingSurfaceShadow = [
  BoxShadow(
    color: Color.fromRGBO(70, 70, 70, 0.25),
    offset: Offset(0, 2),
    blurRadius: 4,
  ),
];
