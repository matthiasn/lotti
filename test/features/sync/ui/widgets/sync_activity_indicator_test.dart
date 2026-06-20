import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/widgets/sync_activity_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('SyncActivityIndicator', () {
    late StreamController<DateTime> txCtl;
    late StreamController<DateTime> rxCtl;

    setUp(() {
      txCtl = StreamController<DateTime>.broadcast();
      rxCtl = StreamController<DateTime>.broadcast();
      SyncActivityIndicatorTestHooks.navigatorOverride = null;
    });

    tearDown(() async {
      SyncActivityIndicatorTestHooks.navigatorOverride = null;
      await txCtl.close();
      await rxCtl.close();
    });

    // Both channels now flash on the brand teal accent (interactive.enabled);
    // the idle dot is decorative.level01 and the hover wash is surface.enabled.
    // Resolve them from the rendered theme so a token tweak doesn't silently
    // break these assertions.
    DsTokens tokensOf(WidgetTester tester) =>
        tester.element(find.byType(SyncActivityIndicator)).designTokens;
    Color accentOf(WidgetTester tester) =>
        tokensOf(tester).colors.interactive.enabled;
    Color ledIdleOf(WidgetTester tester) =>
        tokensOf(tester).colors.decorative.level01;

    Future<void> pumpIndicator(
      WidgetTester tester, {
      int outbox = 0,
      int inbox = 0,
    }) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncActivityIndicator(),
          overrides: [
            syncActivityTxPulsesProvider.overrideWith((_) => txCtl.stream),
            syncActivityRxPulsesProvider.overrideWith((_) => rxCtl.stream),
            outboxPendingCountProvider.overrideWith(
              (_) => Stream<int>.value(outbox),
            ),
            inboundQueueDepthProvider.overrideWith(
              (_) => Stream<int>.value(inbox),
            ),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets('renders both Outbox and Inbox channels with their counts', (
      tester,
    ) async {
      // A 4-digit outbox count proves it renders in full (the inline count
      // has no fixed-width column to clip against).
      await pumpIndicator(tester, outbox: 1573, inbox: 14);

      expect(find.text('Outbox'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('1573'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('hides numeric values when both queues are empty', (
      tester,
    ) async {
      await pumpIndicator(tester);

      // Channels still render so the affordance stays clickable, but the
      // numeric "0" is suppressed — the LEDs alone carry the idle state.
      expect(find.text('Outbox'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('hides only the zero numeric when one channel is non-zero', (
      tester,
    ) async {
      await pumpIndicator(tester, outbox: 12);

      expect(find.text('12'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets(
      'inline count keeps the LED + label anchored as the count grows '
      '(the count is the last element, so it never shifts the label)',
      (tester) async {
        // Measure the label offset relative to the indicator's own left edge:
        // that internal offset (border + padding + LED + gap) is the real
        // invariant. The test harness centres the widget, so absolute x shifts
        // as the content widens — but in the sidebar the footer is left-aligned.
        double labelOffset(String label) =>
            tester.getTopLeft(find.text(label)).dx -
            tester.getTopLeft(find.byType(SyncActivityIndicator)).dx;

        await pumpIndicator(tester, outbox: 1, inbox: 1);
        final txOffsetSmall = labelOffset('Outbox');
        final rxOffsetSmall = labelOffset('Inbox');

        await pumpIndicator(tester, outbox: 9999, inbox: 9999);
        final txOffsetLarge = labelOffset('Outbox');
        final rxOffsetLarge = labelOffset('Inbox');

        expect(txOffsetLarge, equals(txOffsetSmall));
        expect(rxOffsetLarge, equals(rxOffsetSmall));
      },
    );

    testWidgets('exposes a button-role semantics label with both counts', (
      tester,
    ) async {
      // Semantics are off by default in widget tests; opt them in so
      // `tester.getSemantics(...)` does not throw a StateError on a
      // strict Flutter version. The handle must be disposed inline
      // (not via addTearDown) — the tester verifies that all handles
      // are released before the test body finishes.
      final semanticsHandle = tester.ensureSemantics();

      await pumpIndicator(tester, outbox: 289, inbox: 14);

      final semantics = tester.getSemantics(
        find.byType(SyncActivityIndicator),
      );
      // Walk the semantics subtree looking for a button node whose
      // label mentions both counts.
      final nodes = <String>[];
      semantics.visitChildren((child) {
        nodes.add(child.label);
        return true;
      });
      final label = [semantics.label, ...nodes].firstWhere(
        (l) => l.contains('289') && l.contains('14'),
        orElse: () => '',
      );
      expect(label, isNotEmpty);
      expect(label.toLowerCase(), contains('outbox'));
      expect(label.toLowerCase(), contains('inbox'));

      semanticsHandle.dispose();
    });

    testWidgets('tapping invokes navigator override with sync outbox route', (
      tester,
    ) async {
      final navigated = <String>[];
      SyncActivityIndicatorTestHooks.navigatorOverride = navigated.add;

      await pumpIndicator(tester, outbox: 5);
      await tester.tap(find.byType(SyncActivityIndicator));
      await tester.pump();

      expect(navigated, [kSyncOutboxRoute]);
    });

    testWidgets(
      'tapping with no override switches the Settings tab and beams the '
      'settings delegate to the sync sub-route — covers the production '
      'NavService path in `_handleTap`',
      (tester) async {
        // Production path: no test override registered, so `_handleTap`
        // resolves the real NavService via getIt. Register a mock that
        // records the call sequence; we don't need a real beamer.
        SyncActivityIndicatorTestHooks.navigatorOverride = null;

        final mockNav = MockNavService();
        final mockDelegate = _RecordingBeamerDelegate();
        when(() => mockNav.settingsIndex).thenReturn(6);
        when(() => mockNav.tapIndex(any())).thenReturn(null);
        when(() => mockNav.settingsDelegate).thenReturn(mockDelegate);
        when(
          () => mockNav.persistNamedRoute(any()),
        ).thenAnswer((_) async {});
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
        getIt.registerSingleton<NavService>(mockNav);
        addTearDown(() {
          if (getIt.isRegistered<NavService>()) {
            getIt.unregister<NavService>();
          }
        });

        await pumpIndicator(tester, outbox: 5);
        await tester.tap(find.byType(SyncActivityIndicator));
        await tester.pump();

        verify(() => mockNav.tapIndex(6)).called(1);
        verify(() => mockNav.persistNamedRoute(kSyncOutboxRoute)).called(1);
        expect(mockDelegate.beamed, [kSyncOutboxRoute]);
      },
    );

    /// Returns every LED background colour in widget tree order
    /// (tx first, rx second). LEDs are the only `AnimatedContainer`s
    /// whose decoration uses `BoxShape.circle`, so we filter on that.
    List<Color?> ledColors(WidgetTester tester) {
      return tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .where((c) {
            final decoration = c.decoration;
            return decoration is BoxDecoration &&
                decoration.shape == BoxShape.circle;
          })
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
    }

    testWidgets(
      'Outbox pulse turns the LED on, then off after the hold window',
      (tester) async {
        await pumpIndicator(tester, outbox: 1);
        final accent = accentOf(tester);

        // Idle: the LED is not lit with the accent.
        expect(ledColors(tester).first, isNot(equals(accent)));

        txCtl.add(DateTime(2026, 5, 2, 10));
        await tester.pump();
        await tester.pump();

        expect(ledColors(tester).first, equals(accent));

        await tester.pump(
          kSyncActivityLedHold + const Duration(milliseconds: 5),
        );

        expect(ledColors(tester).first, isNot(equals(accent)));
      },
    );

    testWidgets('Inbox pulse only lights the Inbox LED, leaving Outbox dark', (
      tester,
    ) async {
      await pumpIndicator(tester, inbox: 3);
      final accent = accentOf(tester);
      final idle = ledIdleOf(tester);

      rxCtl.add(DateTime(2026, 5, 2, 10));
      await tester.pump();
      await tester.pump();

      final colors = ledColors(tester);
      // First LED is Outbox (stays idle), second is Inbox (lit on the brand
      // teal accent). Both channels share one accent now — direction is
      // carried by which LED lights, not by a second hue.
      expect(colors[0], equals(idle));
      expect(colors[1], equals(accent));

      await tester.pump(
        kSyncActivityLedHold + const Duration(milliseconds: 5),
      );
    });

    testWidgets('rapid pulses extend the LED hold window', (tester) async {
      await pumpIndicator(tester, outbox: 5);
      final accent = accentOf(tester);

      txCtl.add(DateTime(2026, 5, 2, 10));
      await tester.pump();
      await tester.pump();
      // Halfway through the hold window, fire another pulse.
      await tester.pump(const Duration(milliseconds: 70));
      txCtl.add(DateTime(2026, 5, 2, 10, 0, 0, 100));
      await tester.pump();
      await tester.pump();

      // After the original hold window would have expired (140 ms), the
      // LED is still on because the second pulse re-armed the timer.
      await tester.pump(const Duration(milliseconds: 80));
      expect(ledColors(tester).first, equals(accent));

      // Drain the timer so the test exits clean.
      await tester.pump(
        kSyncActivityLedHold + const Duration(milliseconds: 5),
      );
    });

    AnimatedContainer outerContainer(WidgetTester tester) {
      return tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .firstWhere(
            (c) =>
                c.padding ==
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          );
    }

    testWidgets('idle background is transparent', (tester) async {
      await pumpIndicator(tester, outbox: 1);

      expect(
        (outerContainer(tester).decoration! as BoxDecoration).color,
        Colors.transparent,
      );
    });

    testWidgets(
      'hover toggle paints the hover wash and clears it back to '
      'transparent — covers the `onShowHoverHighlight` callback',
      (tester) async {
        await pumpIndicator(tester, outbox: 1);
        final wash = tokensOf(tester).colors.surface.enabled;

        // Pull the hover callback off the FocusableActionDetector
        // widget directly. The flutter_test mouse pointer simulation
        // is flaky with FocusableActionDetector's MouseRegion under
        // some host configurations (the underlying Flutter issue is
        // tracked separately); calling the callback the same way the
        // detector would on a real `onEnter` exercises the production
        // `setState(() => _hovered = …)` path and the
        // AnimatedContainer's hover-wash branch.
        final detector = tester.widget<FocusableActionDetector>(
          find.byType(FocusableActionDetector),
        );
        detector.onShowHoverHighlight!(true);
        await tester.pump();

        expect(
          (outerContainer(tester).decoration! as BoxDecoration).color,
          equals(wash),
          reason: 'hovered state paints the surface.enabled hover wash',
        );

        detector.onShowHoverHighlight!(false);
        await tester.pump();

        expect(
          (outerContainer(tester).decoration! as BoxDecoration).color,
          Colors.transparent,
        );
      },
    );

    testWidgets(
      'invoking ActivateIntent on a descendant context forwards to the '
      'navigator override — covers the keyboard-activation action',
      (tester) async {
        final navigated = <String>[];
        SyncActivityIndicatorTestHooks.navigatorOverride = navigated.add;

        await pumpIndicator(tester, outbox: 1);

        // The Actions widget that registers ActivateIntent is built
        // *inside* the FocusableActionDetector — `Actions.invoke` only
        // sees it from a descendant context. The inner GestureDetector
        // is a descendant, so its element gives us a context that
        // resolves the action map.
        final descendantContext = tester.element(find.byType(GestureDetector));
        Actions.invoke(descendantContext, const ActivateIntent());
        await tester.pump();

        expect(navigated, [kSyncOutboxRoute]);
      },
    );
  });
}

/// Captures `beamToNamed` calls without spinning up a real Beamer
/// router. Used to verify the production `_handleTap` path forwards
/// the sync outbox route to the Settings delegate.
class _RecordingBeamerDelegate extends BeamerDelegate {
  _RecordingBeamerDelegate()
    : super(
        locationBuilder: RoutesLocationBuilder(
          routes: {'*': (_, _, _) => const SizedBox.shrink()},
        ).call,
      );

  final List<String> beamed = <String>[];

  @override
  void beamToNamed(
    String uri, {
    Object? data,
    Object? routeState,
    bool beamBackOnPop = false,
    bool popBeamLocationOnPop = false,
    bool stacked = true,
    bool replaceRouteInformation = false,
    TransitionDelegate<dynamic>? transitionDelegate,
    String? popToNamed,
  }) {
    beamed.add(uri);
  }
}
