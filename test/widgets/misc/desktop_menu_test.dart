import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    group('build on macOS', () {
      testWidgets('renders child inside PlatformMenuBar with zoom items', (
        tester,
      ) async {
        if (!Platform.isMacOS) return;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        var zoomInCalled = false;
        var zoomOutCalled = false;
        var zoomResetCalled = false;

        await tester.pumpWidget(
          DesktopMenuWrapper(
            onZoomIn: () => zoomInCalled = true,
            onZoomOut: () => zoomOutCalled = true,
            onZoomReset: () => zoomResetCalled = true,
            child: const Text('App Content'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PlatformMenuBar), findsOneWidget);
        expect(find.text('App Content'), findsOneWidget);

        // Inspect the View menu structure
        final menuBar = tester.widget<PlatformMenuBar>(
          find.byType(PlatformMenuBar),
        );

        final viewMenu = menuBar.menus.whereType<PlatformMenu>().lastWhere(
          (m) => m.menus.whereType<PlatformMenuItem>().isNotEmpty,
        );

        final menuItems = viewMenu.menus.whereType<PlatformMenuItem>().toList();
        expect(menuItems.length, greaterThanOrEqualTo(3));

        // Verify zoom shortcuts
        final shortcuts = menuItems
            .map((item) => item.shortcut)
            .whereType<SingleActivator>()
            .toList();
        expect(
          shortcuts.any((s) => s.trigger == LogicalKeyboardKey.add && s.meta),
          isTrue,
          reason: 'Zoom in shortcut should be Cmd++',
        );
        expect(
          shortcuts.any(
            (s) => s.trigger == LogicalKeyboardKey.minus && s.meta,
          ),
          isTrue,
          reason: 'Zoom out shortcut should be Cmd+-',
        );
        expect(
          shortcuts.any(
            (s) => s.trigger == LogicalKeyboardKey.digit0 && s.meta,
          ),
          isTrue,
          reason: 'Zoom reset shortcut should be Cmd+0',
        );

        // Verify callbacks are wired
        menuItems[0].onSelected?.call();
        menuItems[1].onSelected?.call();
        menuItems[2].onSelected?.call();
        expect(zoomInCalled, isTrue);
        expect(zoomOutCalled, isTrue);
        expect(zoomResetCalled, isTrue);

        // Clean up PlatformMenuBar lock and reset platform override
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('zoom menu items accept null callbacks', (tester) async {
        if (!Platform.isMacOS) return;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        await tester.pumpWidget(
          const DesktopMenuWrapper(
            child: Text('No Zoom'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PlatformMenuBar), findsOneWidget);
        expect(find.text('No Zoom'), findsOneWidget);

        final menuBar = tester.widget<PlatformMenuBar>(
          find.byType(PlatformMenuBar),
        );
        final viewMenu = menuBar.menus.whereType<PlatformMenu>().lastWhere(
          (m) => m.menus.whereType<PlatformMenuItem>().isNotEmpty,
        );
        final zoomItems = viewMenu.menus.whereType<PlatformMenuItem>().toList();
        expect(zoomItems[0].onSelected, isNull);
        expect(zoomItems[1].onSelected, isNull);
        expect(zoomItems[2].onSelected, isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      });
    });
  });
}
