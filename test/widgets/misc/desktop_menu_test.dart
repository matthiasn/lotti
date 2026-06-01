import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

/// Pumps a [DesktopMenuWrapper] on macOS with the given zoom callbacks and
/// returns the inflated [PlatformMenuBar] widget so tests can inspect menus.
///
/// Must only be called when [Platform.isMacOS] is true.
Future<PlatformMenuBar> _pumpAndGetMenuBar(
  WidgetTester tester, {
  VoidCallback? onZoomIn,
  VoidCallback? onZoomOut,
  VoidCallback? onZoomReset,
}) async {
  await tester.pumpWidget(
    DesktopMenuWrapper(
      onZoomIn: onZoomIn,
      onZoomOut: onZoomOut,
      onZoomReset: onZoomReset,
      child: const Text('Content'),
    ),
  );
  await tester.pump();
  return tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
}

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
      setUp(() async {
        if (!Platform.isMacOS) return;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await setUpTestGetIt(
          additionalSetup: () {
            final mockNavService = MockNavService();
            when(mockNavService.getSavedRoute).thenAnswer(
              (_) async => null,
            );
            getIt.registerSingleton<NavService>(mockNavService);
          },
        );
      });

      tearDown(() async {
        if (!Platform.isMacOS) return;
        debugDefaultTargetPlatformOverride = null;
        await tearDownTestGetIt();
      });

      testWidgets('renders child inside PlatformMenuBar with zoom items', (
        tester,
      ) async {
        if (!Platform.isMacOS) return;

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

        // Clean up PlatformMenuBar lock
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('zoom menu items accept null callbacks', (tester) async {
        if (!Platform.isMacOS) return;

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
      });

      testWidgets('menu bar has exactly four top-level menus', (tester) async {
        if (!Platform.isMacOS) return;

        final menuBar = await _pumpAndGetMenuBar(tester);

        // Lotti, File, Edit, View
        expect(menuBar.menus.length, equals(4));

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('Lotti menu is the first top-level menu', (tester) async {
        if (!Platform.isMacOS) return;

        final menuBar = await _pumpAndGetMenuBar(tester);
        final lottiMenu = menuBar.menus.first as PlatformMenu;

        expect(lottiMenu.label, equals('Lotti'));
        // The Lotti menu contains standard provided items (about, services,
        // hide, quit).
        final providedItems = lottiMenu.menus
            .whereType<PlatformProvidedMenuItem>()
            .toList();
        final groups = lottiMenu.menus
            .whereType<PlatformMenuItemGroup>()
            .toList();
        expect(
          providedItems.isNotEmpty || groups.isNotEmpty,
          isTrue,
          reason: 'Lotti menu must have at least provided items or groups',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('File menu contains New Entry item with Cmd+N shortcut', (
        tester,
      ) async {
        if (!Platform.isMacOS) return;

        final menuBar = await _pumpAndGetMenuBar(tester);
        // File menu is the second top-level menu (index 1).
        final fileMenu = menuBar.menus[1] as PlatformMenu;

        final newEntryItem = fileMenu.menus
            .whereType<PlatformMenuItem>()
            .firstWhere(
              (item) =>
                  (item.shortcut as SingleActivator?)?.trigger ==
                  LogicalKeyboardKey.keyN,
            );

        // The shortcut must be Cmd+N.
        final shortcut = newEntryItem.shortcut! as SingleActivator;
        expect(shortcut.trigger, equals(LogicalKeyboardKey.keyN));
        expect(shortcut.meta, isTrue);
        // The callback must be wired (not null).
        expect(newEntryItem.onSelected, isNotNull);

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('File menu contains New... submenu', (tester) async {
        if (!Platform.isMacOS) return;

        final menuBar = await _pumpAndGetMenuBar(tester);
        final fileMenu = menuBar.menus[1] as PlatformMenu;

        // "New..." is a PlatformMenu (sub-menu), not a PlatformMenuItem.
        final newSubmenu = fileMenu.menus.whereType<PlatformMenu>().first;

        expect(newSubmenu.menus.length, greaterThanOrEqualTo(2));

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
        'New... submenu contains New Task item with Cmd+T shortcut',
        (tester) async {
          if (!Platform.isMacOS) return;

          final menuBar = await _pumpAndGetMenuBar(tester);
          final fileMenu = menuBar.menus[1] as PlatformMenu;
          final newSubmenu = fileMenu.menus.whereType<PlatformMenu>().first;

          final taskItem = newSubmenu.menus
              .whereType<PlatformMenuItem>()
              .firstWhere(
                (item) =>
                    (item.shortcut as SingleActivator?)?.trigger ==
                    LogicalKeyboardKey.keyT,
              );

          final shortcut = taskItem.shortcut! as SingleActivator;
          expect(shortcut.trigger, equals(LogicalKeyboardKey.keyT));
          expect(shortcut.meta, isTrue);
          expect(taskItem.onSelected, isNotNull);

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        'New... submenu contains New Screenshot item with Cmd+Alt+S shortcut',
        (tester) async {
          if (!Platform.isMacOS) return;

          final menuBar = await _pumpAndGetMenuBar(tester);
          final fileMenu = menuBar.menus[1] as PlatformMenu;
          final newSubmenu = fileMenu.menus.whereType<PlatformMenu>().first;

          final screenshotItem = newSubmenu.menus
              .whereType<PlatformMenuItem>()
              .firstWhere(
                (item) =>
                    (item.shortcut as SingleActivator?)?.trigger ==
                    LogicalKeyboardKey.keyS,
              );

          final shortcut = screenshotItem.shortcut! as SingleActivator;
          expect(shortcut.trigger, equals(LogicalKeyboardKey.keyS));
          expect(shortcut.meta, isTrue);
          expect(shortcut.alt, isTrue);
          expect(screenshotItem.onSelected, isNotNull);

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets('Edit menu is the third top-level menu with no items', (
        tester,
      ) async {
        if (!Platform.isMacOS) return;

        final menuBar = await _pumpAndGetMenuBar(tester);
        final editMenu = menuBar.menus[2] as PlatformMenu;

        expect(editMenu.menus, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('View menu contains PlatformProvidedMenuItems', (
        tester,
      ) async {
        if (!Platform.isMacOS) return;

        final menuBar = await _pumpAndGetMenuBar(tester);
        final viewMenu = menuBar.menus[3] as PlatformMenu;

        final providedItems = viewMenu.menus
            .whereType<PlatformProvidedMenuItem>()
            .toList();
        expect(providedItems.length, greaterThanOrEqualTo(2));

        final types = providedItems.map((i) => i.type).toSet();
        expect(
          types.contains(PlatformProvidedMenuItemType.toggleFullScreen) ||
              types.contains(PlatformProvidedMenuItemType.zoomWindow),
          isTrue,
          reason: 'View menu must include system window controls',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('child widget is rendered inside the menu bar', (
        tester,
      ) async {
        if (!Platform.isMacOS) return;

        await tester.pumpWidget(
          const DesktopMenuWrapper(child: Text('Inner Widget')),
        );
        await tester.pump();

        expect(find.text('Inner Widget'), findsOneWidget);
        expect(find.byType(PlatformMenuBar), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
        'uses locale from enclosing Localizations when available',
        (tester) async {
          if (!Platform.isMacOS) return;

          // Wrap the widget inside a Localizations to provide a locale
          // so the DesktopMenuWrapper picks it up via maybeLocaleOf.
          await tester.pumpWidget(
            Localizations(
              locale: const Locale('de'),
              delegates: const [],
              child: const DesktopMenuWrapper(child: Text('Localized Child')),
            ),
          );
          await tester.pump();

          // The widget must still render via PlatformMenuBar without crashing.
          expect(find.byType(PlatformMenuBar), findsOneWidget);
          expect(find.text('Localized Child'), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
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
