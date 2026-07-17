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

    // Resolve colors from the rendered theme so token changes do not silently
    // break the interaction assertions.
    DsTokens tokensOf(WidgetTester tester) =>
        tester.element(find.byType(SyncActivityIndicator)).designTokens;
    Color accentOf(WidgetTester tester) =>
        tokensOf(tester).colors.interactive.enabled;

    Future<void> pumpIndicator(
      WidgetTester tester, {
      int outbox = 0,
      int inbox = 0,
      double textScale = 1,
    }) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncActivityIndicator(),
          mediaQueryData: textScale == 1
              ? null
              : phoneMediaQueryData.copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
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

    testWidgets(
      'rows grow with larger text scale instead of clipping '
      '(min-height, not a fixed height)',
      (tester) async {
        await pumpIndicator(tester, outbox: 1573);
        final height1x = tester
            .getSize(find.byType(SyncActivityIndicator))
            .height;
        expect(height1x, greaterThanOrEqualTo(48));

        await pumpIndicator(tester, outbox: 1573, textScale: 2);
        final height2x = tester
            .getSize(find.byType(SyncActivityIndicator))
            .height;

        // The footer grows with the text scale rather than clamping to a
        // fixed row height, so the label/count never clip.
        expect(height2x, greaterThan(height1x));
        expect(find.text('Syncing'), findsOneWidget);
        expect(find.text('999+'), findsOneWidget);
      },
    );

    testWidgets('renders compact directional metrics for active queues', (
      tester,
    ) async {
      await pumpIndicator(tester, outbox: 1573, inbox: 14);

      expect(find.text('Syncing'), findsOneWidget);
      expect(find.text('999+'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('healthy sync stays quiet and omits transport telemetry', (
      tester,
    ) async {
      await pumpIndicator(tester);

      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Outbox'), findsNothing);
      expect(find.text('Inbox'), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('keeps a non-zero outbox visible while inbox is idle', (
      tester,
    ) async {
      await pumpIndicator(tester, outbox: 12);

      expect(find.text('Syncing'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets(
      'summary growth keeps the title anchored as queue counts grow',
      (tester) async {
        // Measure the title offset relative to the indicator's own left edge:
        // that internal offset (border + padding + icon + gap) is the real
        // invariant. The summary can grow below it without shifting the title.
        double titleOffset() =>
            tester.getTopLeft(find.text('Syncing')).dx -
            tester.getTopLeft(find.byType(SyncActivityIndicator)).dx;

        await pumpIndicator(tester, outbox: 1, inbox: 1);
        final offsetSmall = titleOffset();

        await pumpIndicator(tester, outbox: 9999, inbox: 9999);
        final offsetLarge = titleOffset();

        expect(offsetLarge, equals(offsetSmall));
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

    Color? syncIconColor(WidgetTester tester) {
      return tester.widget<Icon>(find.byIcon(Icons.sync_rounded)).color;
    }

    testWidgets(
      'Outbox pulse temporarily promotes healthy sync to active',
      (tester) async {
        await pumpIndicator(tester);
        final accent = accentOf(tester);

        expect(find.text('Sync'), findsOneWidget);
        expect(syncIconColor(tester), isNot(equals(accent)));

        txCtl.add(DateTime(2026, 5, 2, 10));
        await tester.pump();
        await tester.pump();

        expect(find.text('Syncing'), findsOneWidget);
        expect(syncIconColor(tester), equals(accent));

        await tester.pump(
          kSyncActivityLedHold + const Duration(milliseconds: 5),
        );

        expect(find.text('Sync'), findsOneWidget);
        expect(syncIconColor(tester), isNot(equals(accent)));
      },
    );

    testWidgets('Inbox pulse uses the same compact active treatment', (
      tester,
    ) async {
      await pumpIndicator(tester);
      final accent = accentOf(tester);

      rxCtl.add(DateTime(2026, 5, 2, 10));
      await tester.pump();
      await tester.pump();

      expect(find.text('Syncing'), findsOneWidget);
      expect(syncIconColor(tester), equals(accent));

      await tester.pump(
        kSyncActivityLedHold + const Duration(milliseconds: 5),
      );
      expect(find.text('Sync'), findsOneWidget);
    });

    testWidgets('rapid pulses extend the active status window', (tester) async {
      await pumpIndicator(tester);

      txCtl.add(DateTime(2026, 5, 2, 10));
      await tester.pump();
      await tester.pump();
      // Halfway through the hold window, fire another pulse.
      await tester.pump(const Duration(milliseconds: 70));
      txCtl.add(DateTime(2026, 5, 2, 10, 0, 0, 100));
      await tester.pump();
      await tester.pump();

      // After the original hold window would have expired, the status is still
      // active because the second pulse re-armed the timer.
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Syncing'), findsOneWidget);

      // Drain the timer so the test exits clean.
      await tester.pump(
        kSyncActivityLedHold + const Duration(milliseconds: 5),
      );
    });

    AnimatedContainer outerContainer(WidgetTester tester) {
      return tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .firstWhere(
            (c) {
              final decoration = c.decoration;
              return decoration is BoxDecoration &&
                  decoration.shape != BoxShape.circle;
            },
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
