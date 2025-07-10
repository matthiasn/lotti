import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

void main() {
  group('ModalUtils', () {
    testWidgets('modalTypeBuilder returns bottomSheet for small screens',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(300, 600));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final modalType = ModalUtils.modalTypeBuilder(context);
              expect(modalType, isA<WoltModalType>());
              expect(
                modalType.runtimeType.toString(),
                'WoltDialogType',
              );
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('modalTypeBuilder returns dialog for large screens',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final modalType = ModalUtils.modalTypeBuilder(context);
              expect(modalType, isA<WoltModalType>());
              expect(modalType.runtimeType.toString(), 'WoltDialogType');
              return const Scaffold();
            },
          ),
        ),
      );
    });
  });
}
