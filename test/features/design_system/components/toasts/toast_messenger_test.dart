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
  MediaQueryData? mediaQueryData,
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
      mediaQueryData: mediaQueryData,
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

        // The first toast is visible; the second sits in the queue.
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsNothing);

        // Let the first toast's display duration elapse plus the exit/enter
        // animations so the queued toast actually drains. Without this leg
        // the test would still pass even if the second toast were dropped.
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('First'), findsNothing);
        expect(find.text('Second'), findsOneWidget);
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

    group('action', () {
      testWidgets('forwards a ToastAction to the toast', (tester) async {
        var taps = 0;
        await _pumpHost(
          tester,
          onPressed: (context) =>
              () => context.showToast(
                tone: DesignSystemToastTone.warning,
                title: 'Item deleted',
                action: ToastAction(
                  label: 'UNDO',
                  onPressed: () => taps++,
                ),
              ),
        );

        await tester.tap(find.text('show'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('UNDO'), findsOneWidget);
        await tester.tap(find.text('UNDO'));
        await tester.pump();
        expect(taps, 1);
      });
    });

    group('countdown', () {
      testWidgets(
        'countdown: true paints a LinearProgressIndicator and extends the '
        'SnackBar duration so the bar reaches zero before fade',
        (tester) async {
          await _pumpHost(
            tester,
            onPressed: (context) =>
                () => context.showToast(
                  tone: DesignSystemToastTone.warning,
                  title: 'Deleting',
                  duration: const Duration(seconds: 5),
                  countdown: true,
                ),
          );

          await tester.tap(find.text('show'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(LinearProgressIndicator), findsOneWidget);

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          // SnackBar holds the toast for 1s longer than the countdown so the
          // bar visibly drains to zero before the SnackBar fades out.
          expect(snackBar.duration, const Duration(seconds: 6));

          await tester.pump(const Duration(seconds: 7));
        },
      );

      testWidgets(
        'countdown: false leaves the SnackBar duration as-is and skips the bar',
        (tester) async {
          await _pumpHost(
            tester,
            onPressed: (context) =>
                () => context.showToast(
                  tone: DesignSystemToastTone.success,
                  title: 'Saved',
                  duration: const Duration(seconds: 5),
                ),
          );

          await tester.tap(find.text('show'));
          await tester.pump();

          expect(find.byType(LinearProgressIndicator), findsNothing);
          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(snackBar.duration, const Duration(seconds: 5));
        },
      );
    });

    group('replaceCurrent', () {
      testWidgets(
        'replaceCurrent: true hides the in-flight toast so the new one is '
        'visible immediately',
        (tester) async {
          // First toast on its own.
          await _pumpHost(
            tester,
            onPressed: (context) => () {
              context.showToast(
                tone: DesignSystemToastTone.success,
                title: 'First',
              );
            },
          );
          await tester.tap(find.text('show'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('First'), findsOneWidget);

          // Second pump, this time replaying with replaceCurrent.
          await _pumpHost(
            tester,
            onPressed: (context) => () {
              context.showToast(
                tone: DesignSystemToastTone.error,
                title: 'Second',
                replaceCurrent: true,
              );
            },
          );
          await tester.tap(find.text('show'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // The earlier toast was hidden; only the new one is on screen.
          expect(find.text('First'), findsNothing);
          expect(find.text('Second'), findsOneWidget);
        },
      );
    });

    group('desktop sizing', () {
      testWidgets(
        'mobile-width viewport leaves the SnackBar at default full width',
        (tester) async {
          await _pumpHost(
            tester,
            onPressed: (context) =>
                () => context.showToast(
                  tone: DesignSystemToastTone.success,
                  title: 'Phone',
                ),
            // 390-wide is the default phone surface — well under the 720
            // desktop breakpoint, so the messenger should leave width null
            // and let the theme margin govern the SnackBar layout.
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          );

          await tester.tap(find.text('show'));
          await tester.pump();

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(snackBar.width, isNull);
        },
      );

      testWidgets(
        'desktop-width viewport gives the SnackBar roughly 75% of viewport',
        (tester) async {
          await _pumpHost(
            tester,
            onPressed: (context) =>
                () => context.showToast(
                  tone: DesignSystemToastTone.success,
                  title: 'Desktop',
                ),
            mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
          );

          await tester.tap(find.text('show'));
          await tester.pump();

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          // 1280 * 0.75 = 960, inside the clamp range so no clamping.
          expect(snackBar.width, 960);
        },
      );

      testWidgets(
        'breakpoint viewport gets the bare desktop fraction (no clamping)',
        (tester) async {
          await _pumpHost(
            tester,
            onPressed: (context) =>
                () => context.showToast(
                  tone: DesignSystemToastTone.success,
                  title: 'Narrow desktop',
                ),
            // 720 is exactly the breakpoint; 720 * 0.75 = 540, comfortably
            // above the 360 lower clamp.
            mediaQueryData: const MediaQueryData(size: Size(720, 800)),
          );

          await tester.tap(find.text('show'));
          await tester.pump();

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(snackBar.width, 540);
        },
      );

      testWidgets(
        'ultrawide desktop viewport clamps to the maximum desktop width',
        (tester) async {
          await _pumpHost(
            tester,
            onPressed: (context) =>
                () => context.showToast(
                  tone: DesignSystemToastTone.success,
                  title: 'Ultrawide',
                ),
            // 1920 * 0.75 = 1440, clamped down to the 1200 upper bound so
            // the toast doesn't sprawl across an ultrawide bottom edge.
            mediaQueryData: const MediaQueryData(size: Size(1920, 1080)),
          );

          await tester.tap(find.text('show'));
          await tester.pump();

          final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
          expect(snackBar.width, 1200);
        },
      );
    });
  });
}
