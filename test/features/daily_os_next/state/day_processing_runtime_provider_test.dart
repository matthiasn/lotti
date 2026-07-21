import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_transcript_writer.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

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
    outbox = DayProcessingOutboxRepository(rootDirectory: root);
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

  test('constructs every local-first runtime dependency', () async {
    final transcriber = MockAudioTranscriptionService();
    final container = ProviderContainer(
      overrides: [
        audioTranscriptionServiceProvider.overrideWithValue(transcriber),
      ],
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
        overrides: [
          audioTranscriptionServiceProvider.overrideWithValue(
            MockAudioTranscriptionService(),
          ),
        ],
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
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer((_) async => 'Recovered transcript');
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: [
        audioTranscriptionServiceProvider.overrideWithValue(transcriber),
      ],
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
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
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
        overrides: [
          audioTranscriptionServiceProvider.overrideWithValue(transcriber),
          dailyOsTranscriptionTargetProvider.overrideWith(
            (ref) async => (provider: provider, model: model),
          ),
        ],
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
}
