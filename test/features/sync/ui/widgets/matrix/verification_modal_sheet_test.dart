import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('showVerificationModalSheet', () {
    testWidgets('renders the title and child inside the modal', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showVerificationModalSheet(
                context: context,
                title: 'Verify Device',
                child: const Text('Modal Content'),
              ),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Both the supplied title (rendered in the modal top bar) and the child
      // are visible once the sheet is open.
      expect(find.text('Verify Device'), findsOneWidget);
      expect(find.text('Modal Content'), findsOneWidget);
    });

    testWidgets('returned future completes when the modal is dismissed', (
      tester,
    ) async {
      var futureCompleted = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await showVerificationModalSheet(
                  context: context,
                  title: 'Verify Device',
                  child: const Text('Modal Content'),
                );
                futureCompleted = true;
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();
      expect(find.text('Modal Content'), findsOneWidget);
      expect(futureCompleted, isFalse);

      // Dismiss the modal by popping its route, mirroring how callers close the
      // verification flow. The wrapper's Future<void> must resolve and the
      // content must leave the tree.
      Navigator.of(tester.element(find.text('Modal Content'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Modal Content'), findsNothing);
      expect(futureCompleted, isTrue);
    });
  });
}
