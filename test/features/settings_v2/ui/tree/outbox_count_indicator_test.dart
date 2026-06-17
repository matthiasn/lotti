import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/ui/tree/outbox_count_indicator.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:matrix/matrix.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required OutboxConnectionState connectionState,
    LoginState? loginState,
    int pendingCount = 0,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: OutboxCountIndicator()),
        overrides: [
          outboxConnectionStateProvider.overrideWith(
            (ref) => Stream.value(connectionState),
          ),
          loginStateStreamProvider.overrideWith(
            (ref) => loginState == null
                ? const Stream.empty()
                : Stream.value(loginState),
          ),
          outboxPendingCountProvider.overrideWith(
            (ref) => Stream.value(pendingCount),
          ),
        ],
      ),
    );
    // The indicator subscribes its providers lazily — each guard
    // (`online` → `count` → `loggedIn`) only watches the next provider
    // after it passes, so the full chain needs one frame per stage to
    // settle before the logged-in branch is reached.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  group('OutboxCountIndicator', () {
    testWidgets('shows the pending count when online and items are queued', (
      tester,
    ) async {
      await pump(
        tester,
        connectionState: OutboxConnectionState.online,
        loginState: LoginState.loggedIn,
        pendingCount: 7,
      );
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders nothing when the outbox is empty', (tester) async {
      await pump(
        tester,
        connectionState: OutboxConnectionState.online,
        loginState: LoginState.loggedIn,
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders nothing while sync is offline, even with a backlog', (
      tester,
    ) async {
      await pump(
        tester,
        connectionState: OutboxConnectionState.disabled,
        loginState: LoginState.loggedIn,
        pendingCount: 12,
      );
      expect(find.text('12'), findsNothing);
    });

    testWidgets('still shows the backlog when online but not logged in', (
      tester,
    ) async {
      // Distinct from the offline case: a logged-out-but-online device
      // keeps surfacing the pending count (just visually muted), rather
      // than hiding it the way an offline outbox does.
      await pump(
        tester,
        connectionState: OutboxConnectionState.online,
        loginState: LoginState.loggedOut,
        pendingCount: 3,
      );
      expect(find.text('3'), findsOneWidget);
    });
  });
}
