import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/modals.dart';
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

    testWidgets('modalSheetPage creates page with title and close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final page = ModalUtils.modalSheetPage(
                context: context,
                title: 'Test Title',
                child: const Text('Test Content'),
              );

              expect(page, isA<WoltModalSheetPage>());
              expect(page.topBarTitle, isA<Text>());
              expect(page.trailingNavBarWidget, isA<IconButton>());
              expect(page.child, isA<Padding>());
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('modalSheetPage creates page without title and close button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final page = ModalUtils.modalSheetPage(
                context: context,
                child: const Text('Test Content'),
                showCloseButton: false,
              );

              expect(page, isA<WoltModalSheetPage>());
              expect(page.topBarTitle, isNull);
              expect(page.trailingNavBarWidget, isNull);
              expect(page.child, isA<Padding>());
              return const Scaffold();
            },
          ),
        ),
      );
    });

    testWidgets('showSinglePageModal shows modal and can be closed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ModalUtils.showSinglePageModal<void>(
                      context: context,
                      title: 'Test Modal',
                      builder: (context) => const Text('Modal Content'),
                    );
                  },
                  child: const Text('Show Modal'),
                );
              },
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify modal content is visible
      expect(find.text('Modal Content'), findsOneWidget);
      expect(find.text('Test Modal'), findsOneWidget);

      // Close modal using close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(find.text('Modal Content'), findsNothing);
      expect(find.text('Test Modal'), findsNothing);
    });
  });
}
