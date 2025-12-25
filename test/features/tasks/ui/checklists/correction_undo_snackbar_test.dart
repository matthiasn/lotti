import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/tasks/ui/checklists/correction_undo_snackbar.dart';

import '../../../../test_helper.dart';

void main() {
  group('CorrectionUndoSnackbarContent', () {
    testWidgets('displays countdown and correction text', (tester) async {
      final pending = PendingCorrection(
        before: 'test flight',
        after: 'TestFlight',
        categoryId: 'cat-1',
        categoryName: 'iOS Dev',
        createdAt: DateTime.now(),
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

      // Should have a progress indicator
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('calls onUndo when cancel button pressed', (tester) async {
      var undoCalled = false;

      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime.now(),
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

    testWidgets('progress indicator animates over time', (tester) async {
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime.now(),
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

      // Get initial progress value
      final progressFinder = find.byType(LinearProgressIndicator);
      expect(progressFinder, findsOneWidget);
      final initialProgress =
          tester.widget<LinearProgressIndicator>(progressFinder).value;
      expect(initialProgress, isNotNull);

      // Advance time and check that progress value has decreased
      await tester.pump(const Duration(milliseconds: 500));
      final laterProgress =
          tester.widget<LinearProgressIndicator>(progressFinder).value;
      expect(laterProgress, isNotNull);
      expect(laterProgress, lessThan(initialProgress!));
    });

    testWidgets('handles expired pending correction gracefully',
        (tester) async {
      // Create a pending that has already expired
      final expiredPending = PendingCorrection(
        before: 'old',
        after: 'new',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: CorrectionUndoSnackbarContent(
              pending: expiredPending,
              onUndo: () {},
            ),
          ),
        ),
      );

      // Should still render without crashing
      expect(find.byType(CorrectionUndoSnackbarContent), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('disposes timer and animation controller properly',
        (tester) async {
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime.now(),
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

    testWidgets('displays countdown text based on remainingTime',
        (tester) async {
      // Create a pending that was just created
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime.now(),
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

      // Should show initial countdown (5s)
      expect(find.textContaining('5'), findsOneWidget);
    });

    testWidgets('shows lower countdown when pending has elapsed time',
        (tester) async {
      // Create a pending that's already 3 seconds old
      final pending = PendingCorrection(
        before: 'before',
        after: 'after',
        categoryId: 'cat-1',
        categoryName: 'Test',
        createdAt: DateTime.now().subtract(const Duration(seconds: 3)),
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

      // Should show 2s remaining (5 - 3 = 2)
      expect(find.textContaining('2'), findsOneWidget);
    });
  });
}
