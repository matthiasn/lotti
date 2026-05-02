import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/widgets/sync_activity_indicator.dart';

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

    testWidgets('renders both tx and rx rows with their counts', (
      tester,
    ) async {
      await pumpIndicator(tester, outbox: 289, inbox: 14);

      expect(find.text('tx'), findsOneWidget);
      expect(find.text('rx'), findsOneWidget);
      expect(find.text('289'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('hides numeric values when both queues are empty', (
      tester,
    ) async {
      await pumpIndicator(tester);

      // Rows still render so the affordance stays clickable, but the
      // numeric "0" is suppressed — the LEDs alone carry the idle state.
      expect(find.text('tx'), findsOneWidget);
      expect(find.text('rx'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('hides only the zero row when one channel is non-zero', (
      tester,
    ) async {
      await pumpIndicator(tester, outbox: 12);

      expect(find.text('12'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('exposes a button-role semantics label with both counts', (
      tester,
    ) async {
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

    testWidgets('TX pulse turns the LED on, then off after the hold window', (
      tester,
    ) async {
      await pumpIndicator(tester, outbox: 1);

      // Idle: neither LED is amber.
      expect(ledColors(tester).first, isNot(equals(kSyncActivityTxColor)));

      txCtl.add(DateTime(2026, 5, 2, 10));
      await tester.pump();
      await tester.pump();

      expect(ledColors(tester).first, equals(kSyncActivityTxColor));

      await tester.pump(
        kSyncActivityLedHold + const Duration(milliseconds: 5),
      );

      expect(ledColors(tester).first, isNot(equals(kSyncActivityTxColor)));
    });

    testWidgets('RX pulse only lights the RX LED, leaving TX dark', (
      tester,
    ) async {
      await pumpIndicator(tester, inbox: 3);

      rxCtl.add(DateTime(2026, 5, 2, 10));
      await tester.pump();
      await tester.pump();

      final colors = ledColors(tester);
      // First LED is TX, second is RX (column order).
      expect(colors[0], isNot(equals(kSyncActivityTxColor)));
      expect(colors[1], equals(kSyncActivityRxColor));

      await tester.pump(
        kSyncActivityLedHold + const Duration(milliseconds: 5),
      );
    });

    testWidgets('rapid pulses extend the LED hold window', (tester) async {
      await pumpIndicator(tester, outbox: 5);

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
      expect(ledColors(tester).first, equals(kSyncActivityTxColor));

      // Drain the timer so the test exits clean.
      await tester.pump(
        kSyncActivityLedHold + const Duration(milliseconds: 5),
      );
    });
  });
}
