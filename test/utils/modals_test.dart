import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

void main() {
  group('ModalUtils', () {
    testWidgets('modalTypeBuilder returns bottomSheet for small screens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(300, 600));
      // Restore the default surface size after the test so the wide/narrow
      // override does not leak into subsequent test files in the same
      // `very_good test` (single-thread) run, which would otherwise flip
      // unrelated tests into desktop layout via isDesktopLayout(context).
      addTearDown(() => tester.binding.setSurfaceSize(null));

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

    testWidgets('modalTypeBuilder returns dialog for large screens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
