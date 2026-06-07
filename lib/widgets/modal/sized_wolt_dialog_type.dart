import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// A [WoltDialogType] whose target width is configurable.
///
/// Wolt's default [WoltDialogType] hard-codes the dialog width to the small
/// breakpoint (~524px), which is too narrow for rich content such as the
/// day-planning modal's two-column Reconcile and Drafting layouts. This
/// subclass keeps Wolt's centering, shape, and transitions but renders the
/// dialog at [preferredWidth] on screens large enough to host it, shrinking
/// to fit (less the standard dialog padding) on narrower screens.
class SizedWoltDialogType extends WoltDialogType {
  const SizedWoltDialogType({required this.preferredWidth});

  /// Target dialog width on screens with room for it.
  final double preferredWidth;

  @override
  BoxConstraints layoutModal(Size availableSize) {
    final available = availableSize.width - WoltDialogType.minPadding;
    var width = available < preferredWidth ? available : preferredWidth;
    if (width < 0) width = 0;
    var maxHeight = availableSize.height * 0.8;
    if (maxHeight < 360) maxHeight = 360;
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: maxHeight,
    );
  }
}
