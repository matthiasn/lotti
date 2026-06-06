import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:matrix/matrix.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  const inner = Icon(Icons.sync, key: Key('inner-icon'));

  Future<void> pumpBadge(
    WidgetTester tester, {
    required OutboxConnectionState connectionState,
    LoginState? loginState,
    int pendingCount = 0,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: OutboxBadgeIcon(icon: inner)),
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
    // Stream providers deliver on the next frames.
    await tester.pump();
    await tester.pump();
  }

  group('OutboxBadgeIcon', () {
    testWidgets('renders the bare icon when sync is offline', (tester) async {
      await pumpBadge(
        tester,
        connectionState: OutboxConnectionState.disabled,
        loginState: LoginState.loggedIn,
        pendingCount: 3,
      );

      expect(find.byKey(const Key('inner-icon')), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('logged in: normal icon with error-colored count badge', (
      tester,
    ) async {
      await pumpBadge(
        tester,
        connectionState: OutboxConnectionState.online,
        loginState: LoginState.loggedIn,
        pendingCount: 3,
      );

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(ColorFiltered), findsNothing);

      final context = tester.element(find.byType(Badge));
      expect(badge.backgroundColor, Theme.of(context).colorScheme.error);
    });

    testWidgets('logged out: grayscale-dimmed icon and muted badge color', (
      tester,
    ) async {
      await pumpBadge(
        tester,
        connectionState: OutboxConnectionState.online,
        loginState: LoginState.loggedOut,
        pendingCount: 2,
      );

      // The dimmed branch wraps the icon in the grayscale filter + opacity.
      final filtered = tester.widget<ColorFiltered>(
        find.byType(ColorFiltered),
      );
      expect(filtered.colorFilter, grayscaleColorMatrix);
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('inner-icon')),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);

      final badge = tester.widget<Badge>(find.byType(Badge));
      final context = tester.element(find.byType(Badge));
      expect(
        badge.backgroundColor,
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
    });

    testWidgets('badge label hidden at zero pending items', (tester) async {
      await pumpBadge(
        tester,
        connectionState: OutboxConnectionState.online,
        loginState: LoginState.loggedIn,
      );

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });
  });
}
