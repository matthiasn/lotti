import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_coach_slot.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_onboarding_coach_strip.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final targetDate = DateTime(2026, 7, 10);

  setUpAll(() {
    registerFallbackValue(OnboardingEventName.dailyOsWalkthroughShown);
  });

  late MockOnboardingMetricsRepository repo;

  setUp(() async {
    repo = MockOnboardingMetricsRepository();
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

  Future<void> pumpSlot(
    WidgetTester tester, {
    required bool withSession,
    OnboardingEventName? recordStage,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    if (withSession) {
      container
          .read(dailyOsOnboardingSessionControllerProvider.notifier)
          .start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          );
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: makeTestableWidgetWithScaffold(
          DailyOsOnboardingCoachSlot(
            message: 'Coaching line',
            recordStage: recordStage,
          ),
        ),
      ),
    );
    // Let the post-frame stage-recording callback run.
    await tester.pump();
  }

  group('DailyOsOnboardingCoachSlot', () {
    testWidgets('renders nothing when no session is active', (tester) async {
      await pumpSlot(tester, withSession: false);

      expect(find.byType(DailyOsOnboardingCoachStrip), findsNothing);
      expect(find.text('Coaching line'), findsNothing);
    });

    testWidgets('renders the coach strip while a session is active', (
      tester,
    ) async {
      await pumpSlot(tester, withSession: true);

      expect(find.byType(DailyOsOnboardingCoachStrip), findsOneWidget);
      expect(find.text('Coaching line'), findsOneWidget);
    });

    testWidgets('records its stage exactly once on mount', (tester) async {
      await pumpSlot(
        tester,
        withSession: true,
        recordStage: OnboardingEventName.dailyOsReconcileReached,
      );

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsReconcileReached,
          reason: 'auto',
          valueBucket: any(named: 'valueBucket'),
        ),
      ).called(1);
    });

    testWidgets('records no stage for the capture beat (null stage)', (
      tester,
    ) async {
      await pumpSlot(tester, withSession: true);

      expect(find.byType(DailyOsOnboardingCoachStrip), findsOneWidget);
      verifyNever(
        () => repo.recordEvent(
          any(),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      );
    });

    testWidgets('records nothing when there is no session, even with a stage', (
      tester,
    ) async {
      await pumpSlot(
        tester,
        withSession: false,
        recordStage: OnboardingEventName.dailyOsReconcileReached,
      );

      verifyNever(
        () => repo.recordEvent(
          any(),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      );
    });
  });
}
