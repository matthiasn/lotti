import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';

void main() {
  group('DesktopMenuWrapper', () {
    // The zoom callbacks the wrapper holds are the closures that get wired
    // into the macOS View-menu `onSelected` handlers. PlatformMenuBar items
    // are dispatched to the platform channel and are not tappable widgets in
    // tests, so we verify the wiring by exercising the closures the widget
    // exposes — invoking each one fires its distinct side effect, proving the
    // wrapper forwards the exact callbacks it was given (not a shared/dropped
    // reference).
    test('exposes the three zoom callbacks and invokes each independently', () {
      var zoomInCalled = 0;
      var zoomOutCalled = 0;
      var zoomResetCalled = 0;

      final wrapper = DesktopMenuWrapper(
        onZoomIn: () => zoomInCalled++,
        onZoomOut: () => zoomOutCalled++,
        onZoomReset: () => zoomResetCalled++,
        child: const SizedBox.shrink(),
      );

      wrapper.onZoomIn!();
      expect((zoomInCalled, zoomOutCalled, zoomResetCalled), (1, 0, 0));

      wrapper.onZoomOut!();
      expect((zoomInCalled, zoomOutCalled, zoomResetCalled), (1, 1, 0));

      wrapper.onZoomReset!();
      expect((zoomInCalled, zoomOutCalled, zoomResetCalled), (1, 1, 1));
    });

    // The wrapper gates on `defaultTargetPlatform`, not the host OS, so both
    // branches are exercised deterministically on every runner by overriding
    // the target platform. The override is reset in a `finally` so it is
    // cleared before the test body returns (Flutter's
    // `debugAssertAllFoundationVarsUnset` invariant runs before tearDowns) and
    // even if an expectation throws.
    group('build', () {
      testWidgets(
        'returns the child directly without a PlatformMenuBar off macOS',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            await tester.pumpWidget(
              const Directionality(
                textDirection: TextDirection.ltr,
                child: DesktopMenuWrapper(child: Text('Direct Child')),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Direct Child'), findsOneWidget);
            expect(find.byType(PlatformMenuBar), findsNothing);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );

      testWidgets(
        'wraps the child in a PlatformMenuBar on macOS',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          try {
            await tester.pumpWidget(
              const Directionality(
                textDirection: TextDirection.ltr,
                child: DesktopMenuWrapper(child: Text('Menu Child')),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.byType(PlatformMenuBar), findsOneWidget);
            expect(find.text('Menu Child'), findsOneWidget);
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    });
  });
}
