import 'package:flutter/widgets.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// A Wolt dialog that takes most of the window's width.
///
/// The standard dialog is a fixed, narrow column — right for a form, wrong
/// for content whose width is the point: a pull request's description lays
/// its screenshots side by side in a table, and in the narrow column they
/// stack, each clipped, with the table scrolling sideways. This dialog takes
/// [widthFraction] of the window, never less than the standard dialog's
/// width, so what was written for a wide page reads as one.
class WideWoltDialogType extends WoltDialogType {
  const WideWoltDialogType({this.widthFraction = 0.8});

  /// The share of the available width the dialog takes.
  final double widthFraction;

  @override
  BoxConstraints layoutModal(Size availableSize) {
    final base = super.layoutModal(availableSize);
    final width = (availableSize.width * widthFraction).clamp(
      base.minWidth,
      availableSize.width,
    );
    return base.copyWith(minWidth: width, maxWidth: width);
  }
}
