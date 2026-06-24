import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/settings_v2/ui/tree/outbox_count_indicator.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required OutboxConnectionState connectionState,
    int pendingCount = 0,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: OutboxCountIndicator()),
        overrides: [
          outboxConnectionStateProvider.overrideWith(
            (ref) => Stream.value(connectionState),
          ),
          outboxPendingCountProvider.overrideWith(
            (ref) => Stream.value(pendingCount),
          ),
        ],
      ),
    );
    // The indicator subscribes its providers lazily — `online` is read before
    // `count`, so let the chain settle over a few frames.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  group('OutboxCountIndicator', () {
    testWidgets('renders just a count badge when items are queued (online)', (
      tester,
    ) async {
      await pump(
        tester,
        connectionState: OutboxConnectionState.online,
        pendingCount: 7,
      );
      expect(find.byType(DesignSystemBadge), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders nothing when the outbox is empty', (tester) async {
      await pump(tester, connectionState: OutboxConnectionState.online);
      expect(find.byType(DesignSystemBadge), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders nothing while sync is offline', (tester) async {
      await pump(
        tester,
        connectionState: OutboxConnectionState.disabled,
        pendingCount: 12,
      );
      expect(find.byType(DesignSystemBadge), findsNothing);
      expect(find.text('12'), findsNothing);
    });

    testWidgets('shows the backlog count whenever the outbox is online', (
      tester,
    ) async {
      await pump(
        tester,
        connectionState: OutboxConnectionState.online,
        pendingCount: 3,
      );
      expect(find.byType(DesignSystemBadge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
