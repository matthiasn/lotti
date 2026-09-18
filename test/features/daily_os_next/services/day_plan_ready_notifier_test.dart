import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/features/daily_os_next/services/day_plan_ready_notifier.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 7, 22, 8);
  const dayId = 'dayplan-2026-07-22';

  setUpAll(registerAllFallbackValues);

  late MockNotificationRepository notifications;

  /// The rows the mocked repository was asked to write, built the way the
  /// real one builds them.
  late List<NotificationEntity> armedRows;

  DayProcessingJob job({
    required DayProcessingPayload payload,
    DayProcessingJobStatus status = DayProcessingJobStatus.succeeded,
    String id = 'job-1',
  }) => DayProcessingJob(
    id: id,
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

  String episodeId({String jobId = 'job-1', String status = 'succeeded'}) =>
      notificationEpisodeId(
        kind: NotificationKinds.dayPlanOutcome,
        subjectId: dayId,
        episodeKey: '$jobId:$status',
      );

  DayPlanReadyNotifier makeNotifier({bool foreground = false}) =>
      DayPlanReadyNotifier(
        notificationRepository: notifications,
        messages: AppLocalizationsEn.new,
        isAppInForeground: () => foreground,
      );

  void stubSuccess() {
    when(
      () => notifications.armEpisode(
        id: any(named: 'id'),
        scheduledFor: any(named: 'scheduledFor'),
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    ).thenAnswer((invocation) async {
      final build =
          invocation.namedArguments[#build]
              as NotificationEntity Function(NotificationMeta);
      final row = build(
        NotificationMeta(
          id: invocation.namedArguments[#id] as String,
          createdAt: now,
          updatedAt: now,
          scheduledFor: invocation.namedArguments[#scheduledFor] as DateTime,
          vectorClock: const VectorClock({}),
          originatingHostId: '',
        ),
      );
      armedRows.add(row);
      return row;
    });
    when(
      () => notifications.retractOpenRows(
        linkedEntityId: any(named: 'linkedEntityId'),
        kind: any(named: 'kind'),
        exceptId: any(named: 'exceptId'),
      ),
    ).thenAnswer((_) async => const []);
  }

  setUp(() {
    notifications = MockNotificationRepository();
    armedRows = [];
    stubSuccess();
  });

  void verifyNothingWritten() {
    verifyNever(
      () => notifications.armEpisode(
        id: any(named: 'id'),
        scheduledFor: any(named: 'scheduledFor'),
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    );
    verifyNever(
      () => notifications.retractOpenRows(
        linkedEntityId: any(named: 'linkedEntityId'),
        kind: any(named: 'kind'),
        exceptId: any(named: 'exceptId'),
      ),
    );
  }

  test(
    'a succeeded draft job while backgrounded writes the plan-ready row, '
    'due at once, keyed by the job and its outcome',
    () async {
      await makeNotifier().onJobOutcome(job(payload: const DraftPlanPayload()));

      verify(
        () => notifications.armEpisode(
          id: episodeId(),
          scheduledFor: now,
          build: any(named: 'build'),
          category: any(named: 'category'),
        ),
      ).called(1);
      final row = armedRows.single as DayPlanOutcomeNotification;
      expect(row.dayId, dayId);
      expect(row.succeeded, isTrue);
      expect(row.title, 'Your day plan is ready');
      expect(row.body, 'The draft is waiting for your review.');
      // Never syncs: the job ledger it reports on is this device's.
      expect(row.isDeviceLocal, isTrue);
    },
  );

  test(
    'outcomes are recorded one at a time, so the later one survives',
    () async {
      // Two outcomes side by side would each arm a row and retract the other's.
      final firstArm = Completer<NotificationEntity?>();
      var arms = 0;
      when(
        () => notifications.armEpisode(
          id: any(named: 'id'),
          scheduledFor: any(named: 'scheduledFor'),
          build: any(named: 'build'),
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) => ++arms == 1 ? firstArm.future : Future.value());
      final notifier = makeNotifier();

      final first = notifier.onJobOutcome(
        job(
          payload: const DraftPlanPayload(),
          status: DayProcessingJobStatus.failed,
        ),
      );
      final second = notifier.onJobOutcome(
        job(payload: const DraftPlanPayload(), id: 'job-2'),
      );
      await pumpEventQueue();

      expect(arms, 1, reason: 'the second outcome waits for the first');

      firstArm.complete(null);
      await Future.wait([first, second]);

      expect(arms, 2);
      final spared = verify(
        () => notifications.retractOpenRows(
          linkedEntityId: dayId,
          kind: NotificationKinds.dayPlanOutcome,
          exceptId: captureAny(named: 'exceptId'),
        ),
      ).captured;
      expect(spared, [
        episodeId(status: 'failed'),
        episodeId(jobId: 'job-2'),
      ]);
    },
  );

  test('a later outcome for the same day retracts the earlier one', () async {
    await makeNotifier().onJobOutcome(job(payload: const DraftPlanPayload()));

    verify(
      () => notifications.retractOpenRows(
        linkedEntityId: dayId,
        kind: NotificationKinds.dayPlanOutcome,
        exceptId: episodeId(),
      ),
    ).called(1);
  });

  test('a job that failed and then succeeded is two episodes', () async {
    // `failed` is not terminal; the retry's success must not be swallowed by
    // the idempotent create the failure row already claimed.
    final notifier = makeNotifier();
    await notifier.onJobOutcome(
      job(
        payload: const DraftPlanPayload(),
        status: DayProcessingJobStatus.failed,
      ),
    );
    await notifier.onJobOutcome(job(payload: const DraftPlanPayload()));

    expect(armedRows.map((row) => row.meta.id), [
      episodeId(status: 'failed'),
      episodeId(),
    ]);
  });

  test('a succeeded refine job uses the plan-changes copy', () async {
    await makeNotifier().onJobOutcome(
      job(payload: const RefinePlanPayload(transcriptCaptureId: 'cap-1')),
    );

    expect(armedRows.single.title, 'Your plan changes are ready');
    expect(
      armedRows.single.body,
      'The proposed changes are waiting for your review.',
    );
  });

  test('no row while the app is in the foreground', () async {
    await makeNotifier(foreground: true).onJobOutcome(
      job(payload: const DraftPlanPayload()),
    );

    verifyNothingWritten();
  });

  test('a cancelled job writes nothing', () async {
    // Cancellation is the user's own doing — telling them about it would be
    // reporting their own action back at them.
    await makeNotifier().onJobOutcome(
      job(
        payload: const DraftPlanPayload(),
        status: DayProcessingJobStatus.cancelled,
      ),
    );

    verifyNothingWritten();
  });

  test(
    'a failed draft job while backgrounded says so rather than staying silent',
    () async {
      await makeNotifier().onJobOutcome(
        job(
          payload: const DraftPlanPayload(),
          status: DayProcessingJobStatus.failed,
        ),
      );

      final row = armedRows.single as DayPlanOutcomeNotification;
      expect(row.succeeded, isFalse);
      expect(row.title, "Your day plan didn't finish");
      expect(row.body, 'Open Lotti to see what happened and try again.');
    },
  );

  test('a failed refine job uses the plan-changes failure copy', () async {
    await makeNotifier().onJobOutcome(
      job(
        payload: const RefinePlanPayload(transcriptCaptureId: 'cap-1'),
        status: DayProcessingJobStatus.failed,
      ),
    );

    expect(armedRows.single.title, "Your plan changes didn't finish");
  });

  test('a failure while the app is in the foreground stays quiet', () async {
    // The user is looking at the app; the Activity surface is where a
    // foreground failure belongs, not a row and a banner over the top of it.
    await makeNotifier(foreground: true).onJobOutcome(
      job(
        payload: const DraftPlanPayload(),
        status: DayProcessingJobStatus.failed,
      ),
    );

    verifyNothingWritten();
  });

  test('a still-retrying job writes nothing', () async {
    // waitingForNetwork and queued are not outcomes — the pipeline has not
    // given up, so there is nothing to report yet.
    for (final status in const [
      DayProcessingJobStatus.queued,
      DayProcessingJobStatus.waitingForNetwork,
      DayProcessingJobStatus.waitingForUser,
      DayProcessingJobStatus.running,
    ]) {
      await makeNotifier().onJobOutcome(
        job(payload: const DraftPlanPayload(), status: status),
      );
    }

    verifyNothingWritten();
  });

  test('transcription and parse jobs write nothing', () async {
    await makeNotifier().onJobOutcome(
      job(
        payload: const TranscribeAudioPayload(
          activityEntryId: 'entry-1',
          recordingSessionId: 'rec-1',
          audioId: 'audio-1',
          audioPath: '/tmp/rec-1.m4a',
        ),
      ),
    );
    await makeNotifier().onJobOutcome(
      job(payload: const ParseCapturePayload(captureId: 'cap-1')),
    );

    verifyNothingWritten();
  });

  group('default collaborators (no injected overrides)', () {
    DayPlanReadyNotifier defaultNotifier() =>
        DayPlanReadyNotifier(notificationRepository: notifications);

    tearDown(() {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      binding.platformDispatcher.clearLocaleTestValue();
    });

    test(
      'a paused app counts as backgrounded and the copy resolves from the '
      'device locale',
      () async {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        binding.platformDispatcher.localeTestValue = const Locale('en', 'US');

        await defaultNotifier().onJobOutcome(
          job(payload: const DraftPlanPayload()),
        );

        expect(armedRows.single.title, 'Your day plan is ready');
      },
    );

    test('an unsupported device locale falls back to English copy', () async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.platformDispatcher.localeTestValue = const Locale('xx');

      await defaultNotifier().onJobOutcome(
        job(payload: const DraftPlanPayload()),
      );

      expect(armedRows.single.title, 'Your day plan is ready');
    });

    test('a resumed app counts as foreground — no row', () async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await defaultNotifier().onJobOutcome(
        job(payload: const DraftPlanPayload()),
      );

      verifyNothingWritten();
    });

    test('the repository resolves lazily from getIt', () async {
      await setUpTestGetIt(
        additionalSetup: () =>
            getIt.registerSingleton<NotificationRepository>(notifications),
      );
      addTearDown(tearDownTestGetIt);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await DayPlanReadyNotifier(
        messages: AppLocalizationsEn.new,
      ).onJobOutcome(job(payload: const DraftPlanPayload()));

      expect(armedRows, hasLength(1));
    });
  });

  group('write failures are contained (fire-and-forget contract)', () {
    void stubWriteFailure() {
      when(
        () => notifications.armEpisode(
          id: any(named: 'id'),
          scheduledFor: any(named: 'scheduledFor'),
          build: any(named: 'build'),
          category: any(named: 'category'),
        ),
      ).thenThrow(StateError('notifications.sqlite unavailable'));
    }

    test('a throwing repository does not escape onJobOutcome', () async {
      stubWriteFailure();

      // Must complete normally: the hook runs unawaited from the outbox
      // processor's completion path, so a throw here would surface as an
      // unhandled async error on job completion.
      await expectLater(
        makeNotifier().onJobOutcome(job(payload: const DraftPlanPayload())),
        completes,
      );
    });

    test('with a DomainLogger registered the failure is logged', () async {
      final logger = MockDomainLogger();
      await setUpTestGetIt(
        additionalSetup: () => getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(logger),
      );
      addTearDown(tearDownTestGetIt);
      stubWriteFailure();

      await expectLater(
        makeNotifier().onJobOutcome(job(payload: const DraftPlanPayload())),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any<Object>(),
          message: 'failed to record plan-outcome notification',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
