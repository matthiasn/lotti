import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

/// Pumps a [MaterialApp] with a button that invokes [onPressed] inside a
/// [Scaffold], so [ScaffoldMessenger.of] resolves to a real messenger.
Future<void> _pumpHost(
  WidgetTester tester, {
  required VoidCallback Function(BuildContext context) onPressed,
}) {
  return tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: onPressed(context),
            child: const Text('show'),
          );
        },
      ),
      theme: DesignSystemTheme.light(),
    ),
  );
}

void main() {
  group('BuildContext.showToast', () {
    testWidgets('shows a DesignSystemToast inside a SnackBar', (tester) async {
      await _pumpHost(
        tester,
        onPressed: (context) =>
            () => context.showToast(
              tone: DesignSystemToastTone.success,
              title: 'Saved',
              description: 'Your changes are live',
            ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(DesignSystemToast), findsOneWidget);

      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.tone, DesignSystemToastTone.success);
      expect(toast.title, 'Saved');
      expect(toast.description, 'Your changes are live');
    });

    testWidgets('renders the SnackBar with transparent chrome', (tester) async {
      await _pumpHost(
        tester,
        onPressed: (context) =>
            () => context.showToast(
              tone: DesignSystemToastTone.error,
              title: 'Oops',
            ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, Colors.transparent);
      expect(snackBar.elevation, 0);
      expect(snackBar.padding, EdgeInsets.zero);
      expect(snackBar.behavior, SnackBarBehavior.floating);
    });

    testWidgets('default duration is 4 seconds', (tester) async {
      await _pumpHost(
        tester,
        onPressed: (context) =>
            () => context.showToast(
              tone: DesignSystemToastTone.success,
              title: 'Default',
            ),
      );
      await tester.tap(find.text('show'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 4),
      );
    });

    testWidgets('duration override is honored', (tester) async {
      await _pumpHost(
        tester,
        onPressed: (context) =>
            () => context.showToast(
              tone: DesignSystemToastTone.success,
              title: 'Long',
              duration: const Duration(seconds: 12),
            ),
      );
      await tester.tap(find.text('show'));
      await tester.pump();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 12),
      );
    });

    testWidgets(
      'tapping the dismiss action removes the toast immediately',
      (tester) async {
        await _pumpHost(
          tester,
          onPressed: (context) =>
              () => context.showToast(
                tone: DesignSystemToastTone.warning,
                title: 'Heads up',
              ),
        );

        await tester.tap(find.text('show'));
        // Let the SnackBar finish its enter animation before tapping dismiss.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(DesignSystemToast), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        // Pump past the exit animation without waiting for the SnackBar
        // display-duration timer (pumpAndSettle would block on it).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(DesignSystemToast), findsNothing);
      },
    );

    testWidgets(
      'dismissible: false hides the close action and disables swipe',
      (tester) async {
        await _pumpHost(
          tester,
          onPressed: (context) =>
              () => context.showToast(
                tone: DesignSystemToastTone.error,
                title: 'Persistent',
                dismissible: false,
              ),
        );

        await tester.tap(find.text('show'));
        await tester.pump();

        expect(find.byType(DesignSystemToast), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);

        // The SnackBar itself must block swipe-to-dismiss so the toast
        // cannot disappear before its duration elapses.
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.dismissDirection, DismissDirection.none);
      },
    );

    testWidgets('dismissible: true allows swipe-to-dismiss', (tester) async {
      await _pumpHost(
        tester,
        onPressed: (context) =>
            () => context.showToast(
              tone: DesignSystemToastTone.success,
              title: 'Dismissable',
            ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.dismissDirection, DismissDirection.down);
    });

    testWidgets(
      'a second toast queues behind the first — the shared SnackBar queue '
      'is not cleared so other SnackBars (e.g. undo affordances) keep '
      'their full duration',
      (tester) async {
        await _pumpHost(
          tester,
          onPressed: (context) => () {
            context
              ..showToast(
                tone: DesignSystemToastTone.success,
                title: 'First',
              )
              ..showToast(
                tone: DesignSystemToastTone.error,
                title: 'Second',
              );
          },
        );

        await tester.tap(find.text('show'));
        // First snack bar enter animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The first toast remains visible; the second is queued.
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsNothing);
      },
    );

    testWidgets('forwards dismissSemanticsLabel to the toast', (tester) async {
      await _pumpHost(
        tester,
        onPressed: (context) =>
            () => context.showToast(
              tone: DesignSystemToastTone.error,
              title: 'Error',
              dismissSemanticsLabel: 'Close error',
            ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();

      // Verify the helper forwards the label to the toast widget. The
      // end-to-end semantics announcement is covered by the toast's own
      // component tests.
      final toast = tester.widget<DesignSystemToast>(
        find.byType(DesignSystemToast),
      );
      expect(toast.dismissSemanticsLabel, 'Close error');
    });
  });
}
