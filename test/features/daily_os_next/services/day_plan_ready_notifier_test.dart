import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/services/day_plan_ready_notifier.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 7, 22, 8);
  const dayId = 'dayplan-2026-07-22';

  late MockNotificationService notifications;

  DayProcessingJob job({
    required DayProcessingPayload payload,
    DayProcessingJobStatus status = DayProcessingJobStatus.succeeded,
  }) => DayProcessingJob(
    id: 'job-1',
    status: status,
    dayId: dayId,
    payload: payload,
    createdAt: now,
    updatedAt: now,
    requestedAt: now,
    nextAttemptAt: now,
    attempts: 1,
    generation: 1,
  );

  DayPlanReadyNotifier makeNotifier({bool foreground = false}) =>
      DayPlanReadyNotifier(
        notificationService: notifications,
        messages: AppLocalizationsEn.new,
        isAppInForeground: () => foreground,
      );

  setUp(() {
    notifications = MockNotificationService();
    when(
      () => notifications.showNotificationNow(
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationId: any(named: 'notificationId'),
        showOnMobile: any(named: 'showOnMobile'),
        showOnDesktop: any(named: 'showOnDesktop'),
        deepLink: any(named: 'deepLink'),
      ),
    ).thenAnswer((_) async {});
  });

  test(
    'a succeeded draft job while backgrounded raises the localized '
    'plan-ready banner with the day deep link',
    () async {
      await makeNotifier().onJobFinished(
        job(payload: const DraftPlanPayload()),
      );

      verify(
        () => notifications.showNotificationNow(
          title: 'Your day plan is ready',
          body: 'The draft is waiting for your review.',
          notificationId: DayPlanReadyNotifier.notificationId,
          showOnMobile: true,
          showOnDesktop: true,
          deepLink: DayPlanReadyNotifier.deepLink,
        ),
      ).called(1);
    },
  );

  test(
    'a succeeded refine job uses the plan-changes copy',
    () async {
      await makeNotifier().onJobFinished(
        job(payload: const RefinePlanPayload(transcriptCaptureId: 'cap-1')),
      );

      verify(
        () => notifications.showNotificationNow(
          title: 'Your plan changes are ready',
          body: 'The proposed changes are waiting for your review.',
          notificationId: DayPlanReadyNotifier.notificationId,
          showOnMobile: true,
          showOnDesktop: true,
          deepLink: DayPlanReadyNotifier.deepLink,
        ),
      ).called(1);
    },
  );

  test('no banner while the app is in the foreground', () async {
    await makeNotifier(foreground: true).onJobFinished(
      job(payload: const DraftPlanPayload()),
    );

    verifyZeroInteractions(notifications);
  });

  test('a cancelled job raises no banner', () async {
    // Cancellation is the user's own doing — telling them about it would be
    // reporting their own action back at them.
    await makeNotifier().onJobFinished(
      job(
        payload: const DraftPlanPayload(),
        status: DayProcessingJobStatus.cancelled,
      ),
    );

    verifyZeroInteractions(notifications);
  });

  test(
    'a failed draft job while backgrounded says so rather than staying silent',
    () async {
      await makeNotifier().onJobFinished(
        job(
          payload: const DraftPlanPayload(),
          status: DayProcessingJobStatus.failed,
        ),
      );

      verify(
        () => notifications.showNotificationNow(
          title: "Your day plan didn't finish",
          body: 'Open Lotti to see what happened and try again.',
          // Same id as the success banner, so a later outcome replaces an
          // earlier one instead of stacking two notices for one day.
          notificationId: DayPlanReadyNotifier.notificationId,
          showOnMobile: true,
          showOnDesktop: true,
          deepLink: DayPlanReadyNotifier.deepLink,
        ),
      ).called(1);
    },
  );

  test('a failed refine job uses the plan-changes failure copy', () async {
    await makeNotifier().onJobFinished(
      job(
        payload: const RefinePlanPayload(transcriptCaptureId: 'cap-1'),
        status: DayProcessingJobStatus.failed,
      ),
    );

    verify(
      () => notifications.showNotificationNow(
        title: "Your plan changes didn't finish",
        body: 'Open Lotti to see what happened and try again.',
        notificationId: DayPlanReadyNotifier.notificationId,
        showOnMobile: true,
        showOnDesktop: true,
        deepLink: DayPlanReadyNotifier.deepLink,
      ),
    ).called(1);
  });

  test('a failure while the app is in the foreground stays quiet', () async {
    // The user is looking at the app; the Activity surface is where a
    // foreground failure belongs, not an OS banner over the top of it.
    await makeNotifier(foreground: true).onJobFinished(
      job(
        payload: const DraftPlanPayload(),
        status: DayProcessingJobStatus.failed,
      ),
    );

    verifyZeroInteractions(notifications);
  });

  test('a still-retrying job raises nothing', () async {
    // waitingForNetwork and queued are not outcomes — the pipeline has not
    // given up, so there is nothing to report yet.
    for (final status in const [
      DayProcessingJobStatus.queued,
      DayProcessingJobStatus.waitingForNetwork,
      DayProcessingJobStatus.waitingForUser,
      DayProcessingJobStatus.running,
    ]) {
      await makeNotifier().onJobFinished(
        job(payload: const DraftPlanPayload(), status: status),
      );
    }

    verifyZeroInteractions(notifications);
  });

  group('default collaborators (no injected overrides)', () {
    DayPlanReadyNotifier defaultNotifier() =>
        DayPlanReadyNotifier(notificationService: notifications);

    tearDown(() {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      binding.platformDispatcher.clearLocaleTestValue();
    });

    test(
      'a paused app counts as backgrounded and the banner copy resolves '
      'from the device locale',
      () async {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        binding.platformDispatcher.localeTestValue = const Locale('en', 'US');

        await defaultNotifier().onJobFinished(
          job(payload: const DraftPlanPayload()),
        );

        verify(
          () => notifications.showNotificationNow(
            title: 'Your day plan is ready',
            body: 'The draft is waiting for your review.',
            notificationId: DayPlanReadyNotifier.notificationId,
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: DayPlanReadyNotifier.deepLink,
          ),
        ).called(1);
      },
    );

    test(
      'an unsupported device locale falls back to English banner copy',
      () async {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        binding.platformDispatcher.localeTestValue = const Locale('xx');

        await defaultNotifier().onJobFinished(
          job(payload: const DraftPlanPayload()),
        );

        verify(
          () => notifications.showNotificationNow(
            title: 'Your day plan is ready',
            body: 'The draft is waiting for your review.',
            notificationId: DayPlanReadyNotifier.notificationId,
            showOnMobile: true,
            showOnDesktop: true,
            deepLink: DayPlanReadyNotifier.deepLink,
          ),
        ).called(1);
      },
    );

    test('a resumed app counts as foreground — no banner', () async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await defaultNotifier().onJobFinished(
        job(payload: const DraftPlanPayload()),
      );

      verifyZeroInteractions(notifications);
    });
  });

  group('delivery failures are contained (fire-and-forget contract)', () {
    test(
      'a throwing notification service does not escape onJobFinished',
      () async {
        when(
          () => notifications.showNotificationNow(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        ).thenThrow(StateError('notification plugin unavailable'));

        // Must complete normally: the hook runs unawaited from the outbox
        // processor's completion path, so a throw here would surface as an
        // unhandled async error on job completion.
        await makeNotifier().onJobFinished(
          job(payload: const DraftPlanPayload()),
        );
      },
    );

    test(
      'the error-log path itself cannot escape either (DomainLogger '
      'registered)',
      () async {
        await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);
        when(
          () => notifications.showNotificationNow(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
            deepLink: any(named: 'deepLink'),
          ),
        ).thenThrow(StateError('notification plugin unavailable'));

        // With a registered DomainLogger the catch block takes the logging
        // branch; the call must still complete normally.
        await makeNotifier().onJobFinished(
          job(payload: const DraftPlanPayload()),
        );
      },
    );
  });

  test('transcription and parse jobs raise no banner', () async {
    await makeNotifier().onJobFinished(
      job(
        payload: const TranscribeAudioPayload(
          activityEntryId: 'entry-1',
          recordingSessionId: 'rec-1',
          audioId: 'audio-1',
          audioPath: '/tmp/rec-1.m4a',
        ),
      ),
    );
    await makeNotifier().onJobFinished(
      job(payload: const ParseCapturePayload(captureId: 'cap-1')),
    );

    verifyZeroInteractions(notifications);
  });
}
