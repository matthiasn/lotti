import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_spotlight.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_check_in_spotlight_host.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final ctaKey = GlobalKey();

  Future<DailyOsOnboardingSessionController> pumpHost(
    WidgetTester tester, {
    required bool withSession,
    bool enabled = true,
    VoidCallback? onCheckIn,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      dailyOsOnboardingSessionControllerProvider.notifier,
    );
    if (withSession) {
      controller.start(origin: DailyOsOnboardingOrigin.auto);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidgetNoScroll(
          Stack(
            children: [
              // Stand-in for the real check-in CTA, near the bottom.
              Positioned(
                left: 40,
                bottom: 40,
                child: SizedBox(key: ctaKey, width: 200, height: 44),
              ),
              Positioned.fill(
                child: DayCheckInSpotlightHost(
                  ctaKey: ctaKey,
                  enabled: enabled,
                  onCheckIn: onCheckIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // First frame renders nothing (rect unmeasured); the post-frame measure +
    // rebuild brings the spotlight in.
    await tester.pump();
    await tester.pump();
    return controller;
  }

  group('DayCheckInSpotlightHost', () {
    testWidgets('shows nothing without an active session', (tester) async {
      await pumpHost(tester, withSession: false);
      expect(find.byType(DailyOsOnboardingSpotlight), findsNothing);
    });

    testWidgets('shows nothing when disabled (day already has a plan)', (
      tester,
    ) async {
      await pumpHost(tester, withSession: true, enabled: false);
      expect(find.byType(DailyOsOnboardingSpotlight), findsNothing);
    });

    testWidgets('measures the CTA and shows the spotlight during a session', (
      tester,
    ) async {
      await pumpHost(tester, withSession: true);
      expect(find.byType(DailyOsOnboardingSpotlight), findsOneWidget);
    });

    testWidgets('the action opens the modal and hides the spotlight', (
      tester,
    ) async {
      var opened = 0;
      await pumpHost(tester, withSession: true, onCheckIn: () => opened++);

      await tester.tap(find.text('Try it'));
      await tester.pump();

      expect(opened, 1);
      // Spotlight steps aside for the modal; the session stays active for the
      // modal's coach strips.
      expect(find.byType(DailyOsOnboardingSpotlight), findsNothing);
    });

    testWidgets('dismissal records the skip and ends the session', (
      tester,
    ) async {
      final controller = await pumpHost(tester, withSession: true);
      final session = controller.state;
      expect(session, isNotNull);

      await tester.tap(find.text('Not now'));
      await tester.pump();

      expect(session!.skipRecorded, isTrue);
      expect(controller.state, isNull);
      expect(find.byType(DailyOsOnboardingSpotlight), findsNothing);
    });
  });
}
