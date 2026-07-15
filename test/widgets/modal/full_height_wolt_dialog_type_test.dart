import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/full_height_wolt_dialog_type.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

void main() {
  test('uses the available height minus Wolt dialog padding', () {
    const type = FullHeightWoltDialogType();
    const availableSize = Size(1200, 700);

    final constraints = type.layoutModal(availableSize);

    expect(
      constraints.maxHeight,
      availableSize.height - WoltDialogType.minPadding,
    );
    expect(constraints.maxWidth, lessThanOrEqualTo(availableSize.width));
  });
}
