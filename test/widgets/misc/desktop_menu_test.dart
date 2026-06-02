import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';

void main() {
  group('DesktopMenuWrapper', () {
    test('stores zoom callbacks', () {
      var zoomInCalled = false;
      var zoomOutCalled = false;
      var zoomResetCalled = false;

      final wrapper = DesktopMenuWrapper(
        onZoomIn: () => zoomInCalled = true,
        onZoomOut: () => zoomOutCalled = true,
        onZoomReset: () => zoomResetCalled = true,
        child: const SizedBox.shrink(),
      );

      expect(wrapper.onZoomIn, isNotNull);
      expect(wrapper.onZoomOut, isNotNull);
      expect(wrapper.onZoomReset, isNotNull);

      wrapper.onZoomIn!();
      wrapper.onZoomOut!();
      wrapper.onZoomReset!();

      expect(zoomInCalled, isTrue);
      expect(zoomOutCalled, isTrue);
      expect(zoomResetCalled, isTrue);
    });

    test('zoom callbacks default to null', () {
      const wrapper = DesktopMenuWrapper(child: SizedBox.shrink());

      expect(wrapper.onZoomIn, isNull);
      expect(wrapper.onZoomOut, isNull);
      expect(wrapper.onZoomReset, isNull);
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
