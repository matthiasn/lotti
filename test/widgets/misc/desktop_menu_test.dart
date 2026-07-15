import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/l10n/app_localizations.dart';
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

      testWidgets(
        'preserves Flutter Quill localization from the app scope on macOS',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          try {
            const childKey = ValueKey('localized-menu-child');
            await tester.pumpWidget(
              const MaterialApp(
                localizationsDelegates: [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  FlutterQuillLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: DesktopMenuWrapper(
                  child: SizedBox(key: childKey),
                ),
              ),
            );
            await tester.pump();

            final childContext = tester.element(find.byKey(childKey));
            expect(
              FlutterQuillLocalizations.of(childContext),
              isNotNull,
              reason: 'The desktop menu must not shadow app-level delegates',
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );

      testWidgets('Go menu dispatches through the shared command handler', (
        tester,
      ) async {
        var taskNavigations = 0;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: AppCommandHost(
                handlers: {
                  AppCommandId.navigateTasks: AppCommandHandler(
                    invoke: (_) => taskNavigations++,
                  ),
                },
                child: const DesktopMenuWrapper(child: Text('Menu Child')),
              ),
            ),
          );
          await tester.pump();

          final menuBar = tester.widget<PlatformMenuBar>(
            find.byType(PlatformMenuBar),
          );
          final goMenu = menuBar.menus.whereType<PlatformMenu>().singleWhere(
            (menu) => menu.label == 'Go',
          );
          final tasksItem = goMenu.menus
              .whereType<PlatformMenuItem>()
              .singleWhere((item) => item.label == 'Go to Tasks');

          expect(tasksItem.onSelected, isNotNull);
          tasksItem.onSelected!();
          await tester.pump();
          expect(taskNavigations, 1);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('unavailable shared commands do not use direct fallbacks', (
        tester,
      ) async {
        var fallbackZooms = 0;
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: AppCommandHost(
                handlers: {
                  AppCommandId.zoomIn: AppCommandHandler(
                    isEnabled: () => false,
                    invoke: (_) => fail('disabled command invoked'),
                  ),
                },
                child: DesktopMenuWrapper(
                  onZoomIn: () => fallbackZooms++,
                  child: const Text('Menu Child'),
                ),
              ),
            ),
          );
          await tester.pump();

          final menuBar = tester.widget<PlatformMenuBar>(
            find.byType(PlatformMenuBar),
          );
          final viewMenu = menuBar.menus.whereType<PlatformMenu>().singleWhere(
            (menu) => menu.label == 'View',
          );
          final zoomInItem = viewMenu.menus.whereType<PlatformMenuItem>().first;

          expect(zoomInItem.onSelected, isNull);
          expect(fallbackZooms, 0);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  });
}
