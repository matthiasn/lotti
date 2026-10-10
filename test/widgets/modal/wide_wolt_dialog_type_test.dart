import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/full_height_wolt_dialog_type.dart';
import 'package:lotti/widgets/modal/wide_wolt_dialog_type.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

void main() {
  test('takes its share of a wide window, at the standard height', () {
    const type = WideWoltDialogType();
    const availableSize = Size(1600, 900);

    final constraints = type.layoutModal(availableSize);
    final standard = const WoltDialogType().layoutModal(availableSize);

    expect(constraints.minWidth, 1280);
    expect(constraints.maxWidth, 1280);
    expect(constraints.maxHeight, standard.maxHeight);
    expect(constraints.minHeight, standard.minHeight);
  });

  test('another share is honoured', () {
    expect(
      const WideWoltDialogType(
        widthFraction: 0.5,
      ).layoutModal(const Size(1600, 900)).maxWidth,
      800,
    );
  });

  test('never narrower than the standard dialog on a small window', () {
    const availableSize = Size(500, 700);
    final standard = const WoltDialogType().layoutModal(availableSize);

    final constraints = const WideWoltDialogType().layoutModal(availableSize);

    expect(constraints.maxWidth, standard.maxWidth);
    expect(constraints.maxWidth, greaterThan(availableSize.width * 0.8));
  });

  test('is a different choice from the full-height dialog', () {
    const availableSize = Size(1600, 700);
    final wide = const WideWoltDialogType().layoutModal(availableSize);
    final tall = const FullHeightWoltDialogType().layoutModal(availableSize);

    expect(wide.maxWidth, greaterThan(tall.maxWidth));
    expect(wide.maxHeight, lessThan(tall.maxHeight));
  });
}
