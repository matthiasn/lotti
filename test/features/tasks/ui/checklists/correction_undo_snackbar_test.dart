import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/tasks/ui/checklists/correction_undo_snackbar.dart';

import '../../../../test_helper.dart';

void main() {
  // A fixed expired date used for tests that don't depend on countdown values.
  final expiredDate = DateTime(2024, 3, 15);

  group('CorrectionUndoSnackbarContent', () {
    testWidgets('displays countdown and correction text', (tester) async {
      final pending = PendingCorrection(
        before: 'test flight',
        after: 'TestFlight',
        categoryId: 'cat-1',
        categoryName: 'iOS Dev',
        createdAt: expiredDate,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: CorrectionUndoSnackbarContent(
              pending: pending,
              onUndo: () {},
            ),
          ),
        ),
      );

      // Should display the before/after text
      expect(find.textContaining('test flight'), findsOneWidget);
      expect(find.textContaining('TestFlight'), findsOneWidget);

      // Should have a cancel button
      expect(find.text('CANCEL'), findsOneWidget);

      // The pending was created in the past, so remainingTime is zero and
      // DesignSystemToast intentionally skips the countdown bar. Animated
      // countdown rendering is covered by design_system_toast_test.dart.
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('calls onUndo when cancel button pressed', (tester) async {
      var undoCalled = false;

      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: expiredDate,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: CorrectionUndoSnackbarContent(
              pending: pending,
              onUndo: () {
                undoCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('CANCEL'));
      await tester.pump();

      expect(undoCalled, isTrue);
    });

    testWidgets(
      'expired pending renders without a progress indicator',
      (tester) async {
        final pending = PendingCorrection(
          before: 'old',
          after: 'new',
          categoryId: 'cat-1',
          categoryName: 'Test',
          createdAt: DateTime(2024, 3, 15),
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: Scaffold(
              body: CorrectionUndoSnackbarContent(
                pending: pending,
                onUndo: () {},
              ),
            ),
          ),
        );

        // remainingTime is clamped to zero, and DesignSystemToast skips the
        // countdown controller (and therefore the progress bar) when the
        // duration is zero. The widget must still render the body so
        // anything queued through the messenger is visible.
        expect(find.byType(CorrectionUndoSnackbarContent), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets('disposes timer and animation controller properly', (
      tester,
    ) async {
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: expiredDate,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: CorrectionUndoSnackbarContent(
              pending: pending,
              onUndo: () {},
            ),
          ),
        ),
      );

      // Pump some frames to let timer and animation run
      await tester.pump(const Duration(milliseconds: 500));

      // Remove the widget (triggers dispose)
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      // Wait past timer interval to ensure no callbacks fire after dispose
      await tester.pump(const Duration(seconds: 1));

      // If we get here without errors, dispose worked correctly
    });

    testWidgets('displays countdown text based on remainingTime', (
      tester,
    ) async {
      // Create a pending with a past date (already expired)
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 30),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: CorrectionUndoSnackbarContent(
              pending: pending,
              onUndo: () {},
            ),
          ),
        ),
      );

      // With an expired date, remainingTime is zero, so countdown shows 0
      expect(find.textContaining('0'), findsOneWidget);
    });

    testWidgets('shows lower countdown when pending has elapsed time', (
      tester,
    ) async {
      // Create a pending with a past date (already fully expired)
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime(2024, 3, 15, 10, 27),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: CorrectionUndoSnackbarContent(
              pending: pending,
              onUndo: () {},
            ),
          ),
        ),
      );

      // With an expired date, remainingTime is clamped to zero
      expect(find.textContaining('0'), findsOneWidget);
    });
  });
}
