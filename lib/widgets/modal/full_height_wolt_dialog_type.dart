import 'package:flutter/widgets.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// A Wolt dialog that uses the available vertical space for dense editors.
///
/// The standard dialog type caps its height more aggressively. Calendar and
/// time-wheel flows need the remaining screen height so their scrollable
/// content can clear a sticky action footer on shorter desktop windows.
class FullHeightWoltDialogType extends WoltDialogType {
  const FullHeightWoltDialogType();

  @override
  BoxConstraints layoutModal(Size availableSize) {
    final base = super.layoutModal(availableSize);
    final maxHeight = (availableSize.height - WoltDialogType.minPadding).clamp(
      base.minHeight,
      availableSize.height,
    );
    return base.copyWith(maxHeight: maxHeight);
  }
}
