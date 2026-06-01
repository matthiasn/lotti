import 'dart:io' show Platform;

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

    group('build on non-macOS', () {
      testWidgets('returns child directly without PlatformMenuBar', (
        tester,
      ) async {
        if (Platform.isMacOS) return;

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: DesktopMenuWrapper(child: Text('Direct Child')),
          ),
        );
        await tester.pump();

        expect(find.text('Direct Child'), findsOneWidget);
        expect(find.byType(PlatformMenuBar), findsNothing);
      });
    });
  });
}
