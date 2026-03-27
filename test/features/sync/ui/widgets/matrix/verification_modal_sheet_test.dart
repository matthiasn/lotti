import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_modal_sheet.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('showVerificationModalSheet', () {
    testWidgets('shows modal with title and child', (tester) async {
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

      expect(find.text('Modal Content'), findsOneWidget);
    });
  });
}
