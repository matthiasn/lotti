import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_spotlight.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_check_in_spotlight_host.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _CountingCadence extends DailyOsOnboardingCadence {
  int recordShownCount = 0;

  @override
  Future<void> recordShown() async => recordShownCount++;
}

void main() {
  final ctaKey = GlobalKey();
  final targetDate = DateTime(2026, 7, 10);

  setUpAll(() {
    registerFallbackValue(OnboardingEventName.dailyOsWalkthroughShown);
  });

  late MockOnboardingMetricsRepository repo;
  late _CountingCadence cadence;

  setUp(() async {
    repo = MockOnboardingMetricsRepository();
    cadence = _CountingCadence();
    when(
      () => repo.recordEvent(
        any(),
        provider: any(named: 'provider'),
        reason: any(named: 'reason'),
        valueBucket: any(named: 'valueBucket'),
      ),
    ).thenAnswer((_) async {});
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<OnboardingMetricsRepository>(repo);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Future<DailyOsOnboardingSessionController> pumpHost(
    WidgetTester tester, {
    required bool withSession,
    bool enabled = true,
    DateTime? hostDate,
    VoidCallback? onCheckIn,
  }) async {
    final container = ProviderContainer(
      overrides: [
        dailyOsOnboardingCadenceProvider.overrideWith(() => cadence),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      dailyOsOnboardingSessionControllerProvider.notifier,
    );
    if (withSession) {
      controller.start(
        origin: DailyOsOnboardingOrigin.auto,
        targetDate: targetDate,
      );
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
                  date: hostDate ?? targetDate,
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
      final controller = await pumpHost(
        tester,
        withSession: true,
        enabled: false,
      );
      expect(find.byType(DailyOsOnboardingSpotlight), findsNothing);
      expect(controller.state, isNull);
    });

    testWidgets('ends a session that belongs to another date', (tester) async {
      final controller = await pumpHost(
        tester,
        withSession: true,
        hostDate: targetDate.add(const Duration(days: 1)),
      );

      expect(find.byType(DailyOsOnboardingSpotlight), findsNothing);
      expect(controller.state, isNull);
    });

    testWidgets('measures the CTA and shows the spotlight during a session', (
      tester,
    ) async {
      await pumpHost(tester, withSession: true);
      expect(find.byType(DailyOsOnboardingSpotlight), findsOneWidget);
    });

    testWidgets('records the Shown funnel event once the spotlight surfaces', (
      tester,
    ) async {
      await pumpHost(tester, withSession: true);
      // Extra frames must not re-record: the session once-guard keeps it to one.
      await tester.pump();
      await tester.pump();

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsWalkthroughShown,
          reason: 'auto',
          valueBucket: any(named: 'valueBucket'),
        ),
      ).called(1);
      expect(cadence.recordShownCount, 1);
    });

    testWidgets('records no Shown event when there is no active session', (
      tester,
    ) async {
      await pumpHost(tester, withSession: false);

      verifyNever(
        () => repo.recordEvent(
          any(),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      );
    });

    testWidgets(
      'a replay session started after dismissal records its own Shown event',
      (tester) async {
        final controller = await pumpHost(tester, withSession: true);

        // Dismiss ends the first session; the host widget stays mounted.
        await tester.tap(find.text('Not now'));
        await tester.pump();
        expect(controller.state, isNull);

        // A replay starts a fresh session on the still-mounted host.
        controller.start(
          origin: DailyOsOnboardingOrigin.replay,
          targetDate: targetDate,
        );
        await tester.pump();
        await tester.pump();

        // Two distinct sessions surfaced, so the funnel records two Shown
        // events — a mount-lifetime bool would have suppressed the second.
        verify(
          () => repo.recordEvent(
            OnboardingEventName.dailyOsWalkthroughShown,
            reason: any(named: 'reason'),
            valueBucket: any(named: 'valueBucket'),
          ),
        ).called(2);
        expect(
          cadence.recordShownCount,
          1,
          reason: 'manual replay must not consume the auto-show budget',
        );
      },
    );

    testWidgets(
      'measures the CTA in host-local space when the host is offset from the '
      'global origin',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            dailyOsOnboardingCadenceProvider.overrideWith(() => cadence),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(dailyOsOnboardingSessionControllerProvider.notifier)
            .start(
              origin: DailyOsOnboardingOrigin.auto,
              targetDate: targetDate,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidgetNoScroll(
              // Push the whole layer off the global origin so a global-space
              // measurement would misplace the cutout.
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 50),
                child: Stack(
                  children: [
                    Positioned(
                      left: 40,
                      top: 60,
                      child: SizedBox(key: ctaKey, width: 200, height: 44),
                    ),
                    Positioned.fill(
                      child: DayCheckInSpotlightHost(
                        ctaKey: ctaKey,
                        date: targetDate,
                        enabled: true,
                        onCheckIn: null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final spotlight = tester.widget<DailyOsOnboardingSpotlight>(
          find.byType(DailyOsOnboardingSpotlight),
        );
        // The CTA's 40/60 offset is measured relative to the host, not shifted
        // by the host's non-zero global origin.
        expect(spotlight.targetRect, const Rect.fromLTWH(40, 60, 200, 44));
      },
    );

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
