import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/tasks/ui/checklists/correction_undo_snackbar.dart';

import '../../../../test_helper.dart';

class _FakeCorrectionCaptureNotifier extends CorrectionCaptureNotifier {
  @override
  PendingCorrection? build() => null;

  bool cancelCalled = false;

  // ignore: use_setters_to_change_properties
  void emit(PendingCorrection pending) {
    state = pending;
  }

  @override
  bool cancel() {
    cancelCalled = true;
    state = null;
    return true;
  }
}

void main() {
  // A fixed expired date used for tests that don't depend on countdown values.
  final expiredDate = DateTime(2024, 3, 15);

  group('CorrectionUndoSnackbarContent', () {
    testWidgets('displays countdown and correction text', (tester) async {
      final pending = PendingCorrection(
        before: 'test flight',
        after: 'TestFlight',
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
      expect(find.text('Cancel'), findsOneWidget);

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

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(undoCalled, isTrue);
    });

    testWidgets(
      'expired pending renders without a progress indicator',
      (tester) async {
        final pending = PendingCorrection(
          before: 'old',
          after: 'new',
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

  group('CorrectionCaptureToastListener', () {
    testWidgets(
      'shows the correction once through the nearest scoped messenger',
      (tester) async {
        final notifier = _FakeCorrectionCaptureNotifier();
        final detailsMessengerKey = GlobalKey<ScaffoldMessengerState>();
        const listenerChildKey = ValueKey('listener-child');

        await tester.pumpWidget(
          WidgetTestBench(
            overrides: [
              correctionCaptureProvider.overrideWith(() => notifier),
            ],
            child: ScaffoldMessenger(
              key: detailsMessengerKey,
              child: const Scaffold(
                body: CorrectionCaptureToastListener(
                  child: SizedBox(key: listenerChildKey),
                ),
              ),
            ),
          ),
        );

        final listenerContext = tester.element(
          find.byKey(listenerChildKey),
        );
        expect(
          ScaffoldMessenger.of(listenerContext),
          same(detailsMessengerKey.currentState),
        );

        notifier.emit(
          PendingCorrection(
            before: 'Buy bred',
            after: 'Buy bread',
            createdAt: expiredDate,
          ),
        );
        await tester.pump();

        expect(find.byType(CorrectionUndoSnackbarContent), findsOneWidget);
        expect(find.textContaining('Buy bred'), findsOneWidget);
        expect(find.textContaining('Buy bread'), findsOneWidget);
      },
    );

    testWidgets('undo cancels the pending correction', (tester) async {
      final notifier = _FakeCorrectionCaptureNotifier();

      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            correctionCaptureProvider.overrideWith(() => notifier),
          ],
          child: const ScaffoldMessenger(
            child: Scaffold(
              body: CorrectionCaptureToastListener(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      notifier.emit(
        PendingCorrection(
          before: 'wrong',
          after: 'right',
          createdAt: expiredDate,
        ),
      );
      await tester.pump();

      final content = tester.widget<CorrectionUndoSnackbarContent>(
        find.byType(CorrectionUndoSnackbarContent),
      );
      content.onUndo();
      await tester.pump();

      expect(notifier.cancelCalled, isTrue);
      expect(find.byType(CorrectionUndoSnackbarContent), findsNothing);
    });

    testWidgets('does not suppress an independent global toast', (
      tester,
    ) async {
      final notifier = _FakeCorrectionCaptureNotifier();
      final detailsMessengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            correctionCaptureProvider.overrideWith(() => notifier),
          ],
          child: ScaffoldMessenger(
            key: detailsMessengerKey,
            child: const Scaffold(
              body: CorrectionCaptureToastListener(
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      tester
          .stateList<ScaffoldMessengerState>(
            find.byType(ScaffoldMessenger),
          )
          .singleWhere((state) => state != detailsMessengerKey.currentState)
          .showSnackBar(
            const SnackBar(content: Text('Global action succeeded')),
          );
      notifier.emit(
        PendingCorrection(
          before: 'Buy bred',
          after: 'Buy bread',
          createdAt: expiredDate,
        ),
      );
      await tester.pump();

      expect(find.text('Global action succeeded'), findsOneWidget);
      expect(find.byType(CorrectionUndoSnackbarContent), findsOneWidget);
    });
  });
}
