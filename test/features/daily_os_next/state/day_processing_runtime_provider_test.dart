import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/services/audio_transcription_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/services/day_agent_job_executor.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_transcript_writer.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../services/day_processing_test_db.dart';

/// Overrides for the agent-service providers `dayProcessingOutboxProcessorProvider`
/// pulls in to build its `DayAgentJobExecutor` (ADR 0032 phase 1). None of
/// this file's tests execute an agent job — they exercise the transcription
/// lane only — so plain unstubbed mocks are enough to satisfy construction.
List<Override> _agentJobExecutorOverrides() {
  final orchestrator = MockWakeOrchestrator();
  when(
    () => orchestrator.runCompletions,
  ).thenAnswer((_) => const Stream.empty());
  return withServiceOverrides([
    dayAgentServiceProvider.overrideWithValue(MockDayAgentService()),
    dayAgentPlanServiceProvider.overrideWithValue(MockDayAgentPlanService()),
    dayAgentCaptureServiceProvider.overrideWithValue(
      MockDayAgentCaptureService(),
    ),
    wakeOrchestratorProvider.overrideWithValue(orchestrator),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late DayProcessingOutboxRepository outbox;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late MockPersistenceLogic persistenceLogic;
  late MockVectorClockService vectorClock;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-runtime-provider-test-');
    outbox = DayProcessingOutboxRepository(db: createTestDayProcessingDb());
    persistenceLogic = MockPersistenceLogic();
    vectorClock = MockVectorClockService();
    when(vectorClock.getHost).thenAnswer((_) async => 'host-1');
    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(root)
          ..registerSingleton<PersistenceLogic>(persistenceLogic)
          ..registerSingleton<VectorClockService>(vectorClock)
          ..registerSingleton<DayProcessingOutboxRepository>(outbox);
      },
    );
    journalDb = mocks.journalDb;
    updateNotifications = mocks.updateNotifications;
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalAudio'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: const [1, 0],
        ids: null,
        limit: 64,
      ),
    ).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await outbox.dispose();
    await tearDownTestGetIt();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'wires the plan-ready notifier as the processor completion hook '
    '(ADR 0032 §5)',
    () async {
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          audioTranscriptionServiceProvider.overrideWithValue(
            MockAudioTranscriptionService(),
          ),
          ..._agentJobExecutorOverrides(),
        ]),
      );
      addTearDown(container.dispose);

      final processor = container.read(dayProcessingOutboxProcessorProvider);

      expect(
        processor.onJobOutcome,
        isNotNull,
        reason:
            'The "your plan is ready" notification hangs off this hook — '
            'unwired, background completions are silent.',
      );
      // Invoke the wired closure with a non-succeeded job: it must absorb
      // the call without side effects (the notifier reacts to successes
      // only), proving the hook is callable as wired in production.
      processor.onJobOutcome!(
        DayProcessingJob(
          id: 'draft_dayplan-2026-07-21',
          status: DayProcessingJobStatus.cancelled,
          dayId: 'dayplan-2026-07-21',
          payload: const DraftPlanPayload(),
          createdAt: DateTime.utc(2026, 7, 21),
          updatedAt: DateTime.utc(2026, 7, 21),
          requestedAt: DateTime.utc(2026, 7, 21),
          nextAttemptAt: DateTime.utc(2026, 7, 21),
          attempts: 0,
          generation: 0,
        ),
      );
    },
  );

  DayProcessingJob draftJob({
    DayProcessingJobStatus status = DayProcessingJobStatus.queued,
    DayProcessingPayload payload = const DraftPlanPayload(),
    DayProcessingFailureClass? failureClass = DayProcessingFailureClass.timeout,
    int attempts = 1,
  }) => DayProcessingJob(
    id: 'draft_dayplan-2026-07-21',
    status: status,
    dayId: 'dayplan-2026-07-21',
    payload: payload,
    createdAt: DateTime.utc(2026, 7, 21),
    updatedAt: DateTime.utc(2026, 7, 21, 9),
    requestedAt: DateTime.utc(2026, 7, 21),
    nextAttemptAt: DateTime.utc(2026, 7, 21, 9, 0, 10),
    attempts: attempts,
    generation: 1,
    lastFailureClass: failureClass,
    lastError: 'draft inference exceeded its 30s deadline',
  );

  test('a draft outcome reaches the drafting screen through the bus', () {
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        audioTranscriptionServiceProvider.overrideWithValue(
          MockAudioTranscriptionService(),
        ),
        ..._agentJobExecutorOverrides(),
      ]),
    );
    addTearDown(container.dispose);

    container.read(dayProcessingOutboxProcessorProvider).onJobOutcome!(
      draftJob(),
    );

    final attempt = container
        .read(dayAgentWakeProgressBusProvider)
        .statusFor('dayplan-2026-07-21')
        .lastAttempt;
    expect(attempt, isNotNull);
    expect(attempt!.attempts, 1);
    expect(attempt.maxAttempts, DayAgentJobExecutor.defaultMaxAttempts);
    expect(attempt.willRetry, isTrue);
    expect(attempt.nextAttemptAt, DateTime.utc(2026, 7, 21, 9, 0, 10));
    expect(attempt.lastError, 'draft inference exceeded its 30s deadline');
  });

  group('dayAgentJobAttemptOf', () {
    test('settled statuses are not retries', () {
      for (final status in [
        DayProcessingJobStatus.failed,
        DayProcessingJobStatus.waitingForUser,
        DayProcessingJobStatus.succeeded,
      ]) {
        expect(
          dayAgentJobAttemptOf(draftJob(status: status))!.willRetry,
          isFalse,
          reason: status.name,
        );
      }
      expect(
        dayAgentJobAttemptOf(
          draftJob(status: DayProcessingJobStatus.waitingForNetwork),
        )!.willRetry,
        isTrue,
      );
    });

    test('ignores other job kinds and local deferrals', () {
      expect(
        dayAgentJobAttemptOf(
          draftJob(payload: const ParseCapturePayload(captureId: 'cap-1')),
        ),
        isNull,
      );
      expect(
        dayAgentJobAttemptOf(
          draftJob(failureClass: DayProcessingFailureClass.local),
        ),
        isNull,
        reason: 'a still-running wake is not a failed attempt',
      );
    });
  });

  test('constructs every local-first runtime dependency', () async {
    final transcriber = MockAudioTranscriptionService();
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        audioTranscriptionServiceProvider.overrideWithValue(transcriber),
        ..._agentJobExecutorOverrides(),
      ]),
    );
    addTearDown(container.dispose);

    expect(
      container.read(dayProcessingOutboxRepositoryProvider),
      same(outbox),
    );
    final writer = container.read(dayAudioTranscriptWriterProvider);
    expect(writer, isA<DayAudioTranscriptWriter>());
    expect(writer.journalDb, same(journalDb));
    expect(writer.persistenceLogic, same(persistenceLogic));

    expect(
      container.read(dayProcessingOutboxProcessorProvider),
      isA<DayProcessingOutboxProcessor>(),
    );
    final runtime = container.read(dayProcessingRuntimeProvider);
    expect(runtime, isA<DayProcessingRuntime>());
    await runtime.nudge();
    verify(vectorClock.getHost).called(1);
  });

  test('wires maintenance: failures reach the domain log, pruning keeps '
      'terminal rows inside the retention window, and agent work for days '
      'before yesterday is cancelled', () async {
    final logger = MockDomainLogger();
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        audioTranscriptionServiceProvider.overrideWithValue(
          MockAudioTranscriptionService(),
        ),
        domainLoggerProvider.overrideWithValue(logger),
        ..._agentJobExecutorOverrides(),
      ]),
    );
    addTearDown(container.dispose);
    final runtime = container.read(dayProcessingRuntimeProvider);
    // Let the startup pass settle, then stop the live runtime so no drain can
    // claim the jobs seeded below: only the wired closures are under test.
    await runtime.nudge();
    await runtime.dispose();

    final error = StateError('intent conflict');
    final stackTrace = StackTrace.current;
    runtime.onRepairFailed!(error, stackTrace);
    verify(
      () => logger.error(
        LogDomain.agentRuntime,
        error,
        stackTrace: stackTrace,
        message: any(named: 'message'),
        subDomain: 'dayProcessingRepair',
      ),
    ).called(1);

    // A job finished today is well inside the 90-day window.
    final claim = await outbox.enqueueAndClaimTranscription(
      dayId: 'dayplan-2026-07-21',
      activityEntryId: 'activity-1',
      recordingSessionId: 'session-recent',
      audioId: 'audio-1',
      audioPath: '${root.path}/recent.m4a',
      capturedAt: DateTime.now(),
    );
    await outbox.markSucceeded(jobId: claim!.job.id, claimToken: claim.token);

    // Waiting drafts for the day before yesterday and for yesterday.
    final stale = await outbox.enqueueDraftPlan(
      dayId: 'dayplan-2026-11-04',
      payload: const DraftPlanPayload(),
    );
    final yesterday = await outbox.enqueueDraftPlan(
      dayId: 'dayplan-2026-11-05',
      payload: const DraftPlanPayload(),
    );

    await withClock(Clock.fixed(DateTime(2026, 11, 6, 9)), runtime.prune!);

    expect(await outbox.getById(claim.job.id), isNotNull);
    expect(
      (await outbox.getById(stale.id))!.status,
      DayProcessingJobStatus.cancelled,
    );
    expect(
      (await outbox.getById(yesterday.id))!.status,
      DayProcessingJobStatus.queued,
      reason:
          'yesterday is kept, so a refine made just before midnight survives',
    );
  });

  test(
    'runtime activation starts the review fence over journal updates',
    () async {
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'check' ? ['none'] : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final capturedAt = DateTime.utc(2026, 7, 21, 8);
      final audioFile = File('${root.path}/fence.m4a')
        ..writeAsBytesSync([1, 2]);
      await outbox.enqueueTranscription(
        dayId: 'dayplan-2026-07-21',
        activityEntryId: 'activity-fence',
        recordingSessionId: 'session-fence',
        audioId: 'audio-fence',
        audioPath: audioFile.path,
        capturedAt: capturedAt,
      );
      when(() => journalDb.journalEntityById('audio-fence')).thenAnswer(
        (_) async => JournalAudio(
          meta: Metadata(
            id: 'audio-fence',
            createdAt: capturedAt,
            updatedAt: capturedAt,
            dateFrom: capturedAt,
            dateTo: capturedAt.add(const Duration(minutes: 1)),
          ),
          data: AudioData(
            dateFrom: capturedAt,
            dateTo: capturedAt.add(const Duration(minutes: 1)),
            audioFile: 'fence.m4a',
            audioDirectory: '/audio/',
            duration: const Duration(minutes: 1),
            dayContext: DayAudioContext(
              dayId: 'dayplan-2026-07-21',
              planDate: DateTime.utc(2026, 7, 21),
              recordingSessionId: 'session-fence',
              activityEntryId: 'activity-fence',
              processingJobId: 'transcribe_session-fence',
              capturedAt: capturedAt,
              intent: 'dayPlan',
            ),
          ),
          entryText: const EntryText(
            plainText: 'Reviewed wording',
            markdown: 'Reviewed wording',
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          audioTranscriptionServiceProvider.overrideWithValue(
            MockAudioTranscriptionService(),
          ),
          ..._agentJobExecutorOverrides(),
        ]),
      );
      addTearDown(container.dispose);

      container.read(dayProcessingRuntimeProvider);
      final fence = container.read(dayAudioReviewFenceProvider);
      // The startup sweep runs unawaited; chaining a sweep through the
      // serialized tail deterministically waits for it.
      await fence.checkNow();

      final saved = await outbox.getById('transcribe_session-fence');
      expect(saved!.status, DayProcessingJobStatus.succeeded);
      expect(saved.resultTranscript, 'Reviewed wording');
      // The fence is subscribed to the app-wide journal update stream.
      verify(() => updateNotifications.updateStream).called(1);
    },
  );

  test('classifies supported interfaces as online before inference', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    var platformResult = 'none';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'check' ? [platformResult] : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final transcriber = MockAudioTranscriptionService();
    when(
      () => transcriber.transcribe(
        any(),
        knownTerms: any(named: 'knownTerms'),
        dictionaryCategoryId: any(named: 'dictionaryCategoryId'),
      ),
    ).thenAnswer((_) async => 'Recovered transcript');
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        audioTranscriptionServiceProvider.overrideWithValue(transcriber),
        ..._agentJobExecutorOverrides(),
      ]),
    );
    addTearDown(container.dispose);
    final processor = container.read(dayProcessingOutboxProcessorProvider);

    for (final result in [
      ConnectivityResult.wifi,
      ConnectivityResult.mobile,
      ConnectivityResult.ethernet,
      ConnectivityResult.vpn,
      ConnectivityResult.none,
    ]) {
      platformResult = result.name;
      final suffix = result.name;
      final audio = File('${root.path}/$suffix.wav')..writeAsBytesSync([1, 2]);
      await outbox.enqueueTranscription(
        dayId: 'dayplan-2026-07-18',
        activityEntryId: 'activity-$suffix',
        recordingSessionId: suffix,
        audioId: 'audio-$suffix',
        audioPath: audio.path,
        capturedAt: DateTime.utc(2026, 7, 18, 8),
      );

      expect(await processor.processNext(), DayProcessingRunResult.deferred);
      final saved = await outbox.getById('transcribe_$suffix');
      expect(
        saved!.lastFailureClass,
        result == ConnectivityResult.none
            ? DayProcessingFailureClass.network
            : DayProcessingFailureClass.local,
      );
    }
    verify(
      () => transcriber.transcribe(
        any(),
        knownTerms: any(named: 'knownTerms'),
        dictionaryCategoryId: any(named: 'dictionaryCategoryId'),
      ),
    ).called(4);
  });

  test(
    'the planner profile transcription target reaches the transcriber',
    () async {
      final transcriber = MockAudioTranscriptionService();
      final provider =
          AiConfig.inferenceProvider(
                id: 'p-profile',
                baseUrl: 'http://localhost',
                apiKey: 'k',
                name: 'Profile Provider',
                createdAt: DateTime(2026, 7, 21),
                inferenceProviderType: InferenceProviderType.genericOpenAi,
              )
              as AiConfigInferenceProvider;
      final model =
          AiConfig.model(
                id: 'm-profile',
                name: 'Profile Model',
                providerModelId: 'profile-model',
                inferenceProviderId: 'p-profile',
                createdAt: DateTime(2026, 7, 21),
                inputModalities: const [Modality.audio],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
              )
              as AiConfigModel;
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'check' ? ['wifi'] : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      when(
        () => transcriber.transcribe(any(), target: any(named: 'target')),
      ).thenAnswer((_) async => 'profile transcript');
      when(
        () => journalDb.journalEntityById(any()),
      ).thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          audioTranscriptionServiceProvider.overrideWithValue(transcriber),
          dailyOsTranscriptionTargetProvider.overrideWith(
            (ref) async => (provider: provider, model: model),
          ),
          ..._agentJobExecutorOverrides(),
        ]),
      );
      addTearDown(container.dispose);
      final processor = container.read(dayProcessingOutboxProcessorProvider);
      final audio = File('${root.path}/profile.m4a')..writeAsBytesSync([1, 2]);
      await outbox.enqueueTranscription(
        dayId: 'dayplan-2026-07-21',
        activityEntryId: 'activity-profile',
        recordingSessionId: 'session-profile',
        audioId: 'audio-profile',
        audioPath: audio.path,
        capturedAt: DateTime.utc(2026, 7, 21, 8),
      );

      await processor.processNext();

      final captured =
          verify(
                () => transcriber.transcribe(
                  any(),
                  target: captureAny(named: 'target'),
                ),
              ).captured.single
              as DailyOsTranscriptionTarget?;
      expect(captured?.model.providerModelId, 'profile-model');
      expect(captured?.provider.id, 'p-profile');
    },
  );

  test(
    'a retried capture a speech-to-text engine heard is corrected on the '
    "planner profile's post-processing model before it is stored",
    () async {
      final transcriber = MockAudioTranscriptionService();
      AiConfigInferenceProvider provider(InferenceProviderType type) =>
          AiConfig.inferenceProvider(
                id: 'p-${type.name}',
                baseUrl: 'http://localhost',
                apiKey: 'k',
                name: type.name,
                createdAt: DateTime(2026, 7, 21),
                inferenceProviderType: type,
              )
              as AiConfigInferenceProvider;
      AiConfigModel model(String id) =>
          AiConfig.model(
                id: 'm-$id',
                name: id,
                providerModelId: id,
                inferenceProviderId: 'p',
                createdAt: DateTime(2026, 7, 21),
                inputModalities: const [Modality.audio],
                outputModalities: const [Modality.text],
                isReasoningModel: false,
              )
              as AiConfigModel;
      final whisper = (
        provider: provider(InferenceProviderType.whisper),
        model: model('whisper-large-v3'),
      );
      final editor = (
        provider: provider(InferenceProviderType.genericOpenAi),
        model: model('editor'),
      );
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'check' ? ['wifi'] : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      when(
        () => transcriber.transcribe(any(), target: any(named: 'target')),
      ).thenAnswer((_) async => 'Moved the build to Cuban Eddies.');
      when(
        () => transcriber.correctTranscript(
          'Moved the build to Cuban Eddies.',
          target: editor,
        ),
      ).thenAnswer((_) async => 'Moved the build to Kubernetes.');
      when(
        () => journalDb.journalEntityById(any()),
      ).thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          audioTranscriptionServiceProvider.overrideWithValue(transcriber),
          dailyOsTranscriptionTargetProvider.overrideWith(
            (ref) async => whisper,
          ),
          dailyOsTranscriptCorrectionTargetProvider.overrideWith(
            (ref) async => editor,
          ),
          ..._agentJobExecutorOverrides(),
        ]),
      );
      addTearDown(container.dispose);
      final processor = container.read(dayProcessingOutboxProcessorProvider);
      final audio = File('${root.path}/retry.m4a')..writeAsBytesSync([1, 2]);
      await outbox.enqueueTranscription(
        dayId: 'dayplan-2026-07-21',
        activityEntryId: 'activity-retry',
        recordingSessionId: 'session-retry',
        audioId: 'audio-retry',
        audioPath: audio.path,
        capturedAt: DateTime.utc(2026, 7, 21, 8),
      );

      await processor.processNext();

      final saved = await outbox.getById('transcribe_session-retry');
      expect(saved!.resultTranscript, 'Moved the build to Kubernetes.');
    },
  );

  test('the drain prioritises the day the user is looking at', () async {
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        audioTranscriptionServiceProvider.overrideWithValue(
          MockAudioTranscriptionService(),
        ),
        ..._agentJobExecutorOverrides(),
      ]),
    );
    addTearDown(container.dispose);

    // Enqueued first, so plain FIFO order would claim the unviewed day.
    await outbox.enqueueParseCapture(
      dayId: 'dayplan-2026-09-09',
      captureId: 'cap-elsewhere',
    );
    await outbox.enqueueParseCapture(
      dayId: dayAgentIdForDate(DateTime(2026, 7, 18)),
      captureId: 'cap-viewed',
    );
    container
        .read(dailyOsNextSelectedDateProvider.notifier)
        .select(DateTime(2026, 7, 18));

    final processor = container.read(dayProcessingOutboxProcessorProvider);
    final priority = processor.priority!();

    expect(
      priority.dayIds.first,
      dayAgentIdForDate(DateTime(2026, 7, 18)),
      reason: 'the selected date leads the ordering',
    );

    // And the ordering it produces really does reach the repository.
    final claim = await outbox.claimNext(priority: priority);
    expect(claim!.job.id, 'parse_cap-viewed');
  });

  test('re-reads the selection per claim rather than at build time', () async {
    // On a day of its own: on the real clock, the day selected below is
    // today once the calendar reaches it, and nothing changes.
    await withClock(Clock.fixed(DateTime(2026, 10, 28, 9)), () async {
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          audioTranscriptionServiceProvider.overrideWithValue(
            MockAudioTranscriptionService(),
          ),
          ..._agentJobExecutorOverrides(),
        ]),
      );
      addTearDown(container.dispose);

      final processor = container.read(dayProcessingOutboxProcessorProvider);
      final before = processor.priority!().dayIds.first;

      container
          .read(dailyOsNextSelectedDateProvider.notifier)
          .select(DateTime(2026, 11, 3));

      // Same processor instance: navigating must not require rebuilding the
      // long-lived runtime for the new day to win.
      expect(
        processor.priority!().dayIds.first,
        isNot(before),
      );
      expect(
        processor.priority!().dayIds.first,
        dayAgentIdForDate(DateTime(2026, 11, 3)),
      );
    });
  });

  test('drains the transcription and agent lanes as separate passes and '
      'sums what they processed', () async {
    final processor = MockDayProcessingOutboxProcessor();
    final drainedLanes = <Set<DayProcessingJobKind>?>[];
    when(
      () => processor.drain(kinds: any(named: 'kinds')),
    ).thenAnswer((invocation) async {
      final kinds =
          invocation.namedArguments[#kinds] as Set<DayProcessingJobKind>?;
      drainedLanes.add(kinds);
      return kinds!.contains(DayProcessingJobKind.transcribeAudio) ? 2 : 3;
    });

    when(() => processor.repository).thenReturn(outbox);

    final processed = await drainDayProcessingLanes(processor);

    expect(drainedLanes, [
      {DayProcessingJobKind.transcribeAudio},
      dayAgentJobKinds,
    ]);
    expect(processed, 5);
  });

  test('a draft enqueued while a transcription is running does not wait for '
      'it', () async {
    final releaseTranscript = Completer<String>();
    final transcribing = Completer<void>();
    final executed = <String>[];
    final processor = DayProcessingOutboxProcessor(
      repository: outbox,
      transcribe: (_) {
        transcribing.complete();
        return releaseTranscript.future;
      },
      attachTranscript: (_, _) async => true,
      agentJobExecutor: (job) async {
        executed.add(job.id);
        return const DayAgentJobSucceeded();
      },
    );
    final audio = File('${root.path}/check-in.m4a')..writeAsStringSync('x');
    await outbox.enqueueTranscription(
      dayId: 'dayplan-2026-07-21',
      activityEntryId: 'entry-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-1',
      audioPath: audio.path,
      capturedAt: DateTime(2026, 7, 21, 8),
    );

    final pass = drainDayProcessingLanes(processor);
    await transcribing.future;
    await outbox.enqueueDraftPlan(
      dayId: 'dayplan-2026-07-21',
      payload: const DraftPlanPayload(),
    );
    await pumpEventQueue();

    expect(
      executed,
      ['draft_dayplan-2026-07-21'],
      reason:
          'the agent lane was idle; a slow transcription in the other lane '
          'must not hold the draft until the whole pass ends',
    );

    releaseTranscript.complete('transcript');
    expect(await pass, 2);
  });

  test('a lane whose drain throws ends the pass with its error instead of '
      'leaving the idle sibling waiting', () async {
    final processor = MockDayProcessingOutboxProcessor();
    when(() => processor.repository).thenReturn(outbox);
    when(
      () => processor.drain(kinds: any(named: 'kinds')),
    ).thenAnswer((invocation) async {
      final kinds =
          invocation.namedArguments[#kinds] as Set<DayProcessingJobKind>?;
      if (kinds!.contains(DayProcessingJobKind.transcribeAudio)) return 0;
      await pumpEventQueue();
      throw StateError('claimNext failed');
    });

    await expectLater(drainDayProcessingLanes(processor), throwsStateError);
    // A hang here is the regression: the test times out instead of failing.
  }, timeout: const Timeout(Duration(seconds: 10)));

  group('dayProcessingIsOnline', () {
    test('an unnamed link counts as online; none does not', () async {
      expect(
        await dayProcessingIsOnline(() async => [ConnectivityResult.other]),
        isTrue,
        reason: 'WireGuard and Tailscale report `other`',
      );
      expect(
        await dayProcessingIsOnline(() async => [ConnectivityResult.none]),
        isFalse,
      );
    });

    test('fails open when the platform check throws', () async {
      // What Linux without NetworkManager does on every call.
      expect(
        await dayProcessingIsOnline(
          () async => throw StateError('NetworkManager was not provided'),
        ),
        isTrue,
      );
    });

    test('fails open when the platform check never answers', () {
      fakeAsync((async) {
        bool? online;
        unawaited(
          dayProcessingIsOnline(
            () => Completer<List<ConnectivityResult>>().future,
          ).then((value) => online = value),
        );

        async.elapse(
          dayProcessingConnectivityTimeout - const Duration(milliseconds: 1),
        );
        expect(online, isNull, reason: 'still within the bound');

        async.elapse(const Duration(milliseconds: 1));
        expect(online, isTrue);
      });
    });
  });

  group('runDayProcessingMaintenance', () {
    final now = DateTime(2026, 11, 6, 9);
    final cutoff = now.subtract(dayProcessingLedgerRetention);
    late MockDayProcessingOutboxRepository repository;

    setUp(() => repository = MockDayProcessingOutboxRepository());

    void stubCancel(Future<int> Function() answer) => when(
      () => repository.cancelAgentJobsBefore('dayplan-2026-11-05'),
    ).thenAnswer((_) => answer());
    void stubPrune(Future<int> Function() answer) => when(
      () => repository.pruneTerminalBefore(cutoff),
    ).thenAnswer((_) => answer());

    test('cancels before yesterday and prunes past retention', () async {
      stubCancel(() async => 2);
      stubPrune(() async => 1);

      await runDayProcessingMaintenance(repository, now: now);

      verifyInOrder([
        () => repository.cancelAgentJobsBefore('dayplan-2026-11-05'),
        () => repository.pruneTerminalBefore(cutoff),
      ]);
    });

    test('a failing prune still cancels, then reports the failure', () async {
      stubCancel(() async => 2);
      stubPrune(() async => throw StateError('database is locked'));

      await expectLater(
        runDayProcessingMaintenance(repository, now: now),
        throwsA(isA<StateError>()),
      );
      verify(
        () => repository.cancelAgentJobsBefore('dayplan-2026-11-05'),
      ).called(1);
    });

    test(
      'a failing cancel still prunes, and its error is the one reported',
      () async {
        stubCancel(() async => throw StateError('cancel failed'));
        stubPrune(() async => throw ArgumentError('prune failed'));

        await expectLater(
          runDayProcessingMaintenance(repository, now: now),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'cancel failed',
            ),
          ),
        );
        verify(() => repository.pruneTerminalBefore(cutoff)).called(1);
      },
    );
  });
}
