import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// A [WoltSideSheetType] whose width scales with the window.
///
/// Wolt's stock side sheet caps its width at the small breakpoint (~524px),
/// which is too narrow for rich planning content. This subclass keeps
/// Wolt's edge anchoring, full-height layout, and transitions but sizes the
/// panel to [widthFraction] of the window, clamped to
/// [minWidth]..[maxWidth], so the interaction gets a substantial column on
/// desktop without ever swallowing the whole screen.
class SizedWoltSideSheetType extends WoltSideSheetType {
  const SizedWoltSideSheetType({
    this.widthFraction = 0.45,
    this.minWidth = 480,
    this.maxWidth = 720,
  });

  /// Fraction of the available window width the panel aims for.
  final double widthFraction;

  /// Lower clamp for the panel width (narrow desktop windows).
  final double minWidth;

  /// Upper clamp for the panel width (very wide screens).
  final double maxWidth;

  @override
  BoxConstraints layoutModal(Size availableSize) {
    final target = availableSize.width * widthFraction;
    var width = target.clamp(minWidth, maxWidth);
    // Never exceed the window itself (tiny windows on resize).
    width = math.min(width, availableSize.width);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: availableSize.height,
      maxHeight: availableSize.height,
    );
  }
}
