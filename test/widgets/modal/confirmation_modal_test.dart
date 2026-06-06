import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

import '../../widget_test_utils.dart';

void main() {
  Future<bool?> showModalAndGetResult(
    WidgetTester tester, {
    String message = 'Are you sure?',
    String? confirmLabel,
    String? cancelLabel,
    bool? isDestructive,
  }) async {
    bool? result;
    await tester.pumpWidget(
      makeTestableWidget2(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showConfirmationModal(
                  context: context,
                  message: message,
                  confirmLabel: confirmLabel ?? 'YES, DELETE DATABASE',
                  cancelLabel: cancelLabel ?? 'CANCEL',
                  isDestructive: isDestructive ?? true,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // Modal route transition — settle is genuinely needed here.
    await tester.pumpAndSettle();
    return result;
  }

  group('showConfirmationModal', () {
    testWidgets('confirm button resolves to true and closes the modal', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        makeTestableWidget2(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showConfirmationModal(
                    context: context,
                    message: 'Delete everything?',
                    confirmLabel: 'Yes, delete',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete everything?'), findsOneWidget);
      // confirmLabel is upper-cased by the modal.
      await tester.tap(find.text('YES, DELETE'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Delete everything?'), findsNothing);
    });

    testWidgets('cancel button resolves to false and closes the modal', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        makeTestableWidget2(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showConfirmationModal(
                    context: context,
                    message: 'Discard changes?',
                    cancelLabel: 'Keep editing',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('shows warning icon only when destructive', (tester) async {
      await showModalAndGetResult(tester);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Dismiss before re-opening with isDestructive: false.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await showModalAndGetResult(tester, isDestructive: false);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('dismissing without choosing resolves to false', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        makeTestableWidget2(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showConfirmationModal(
                    context: context,
                    message: 'Sure?',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the barrier to dismiss without picking either action.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
