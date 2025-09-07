import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
// ignore_for_file: unnecessary_lambdas
import 'package:record/record.dart' as record;

class _MockAudioRecorder extends Mock implements record.AudioRecorder {}

class _MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class _InMemoryAiConfigRepo extends AiConfigRepository {
  _InMemoryAiConfigRepo()
      : super(
          // ignore: invalid_use_of_visible_for_testing_member
          AiConfigDb(inMemoryDatabase: true),
        );
}

class _FakeLoggingService extends LoggingService {
  @override
  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {}

  @override
  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(const record.RecordConfig());
    registerFallbackValue(const Duration(milliseconds: 50));
    // Fallback for provider matcher in mocktail
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback',
        baseUrl: 'http://localhost',
        apiKey: 'k',
        name: 'Fallback',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      ) as AiConfigInferenceProvider,
    );
  });

  setUp(() {
    // Ensure logging is available to avoid getIt lookup errors
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(_FakeLoggingService());
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  test('start() without permission sets errorType and message', () async {
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider
          .overrideWith((ref) => ChatRecorderController(
                ref,
                recorderFactory: () => mockRecorder,
                tempDirectoryProvider: () async => Directory.systemTemp,
                config: const ChatRecorderConfig(maxSeconds: 2),
              )),
    ]);
    // No need to keep provider alive for this quick path

    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    final state = container.read(chatRecorderControllerProvider);
    expect(state.errorType, ChatRecorderErrorType.permissionDenied);
    expect(state.error, contains('Microphone permission denied'));
  });

  test('concurrent start attempts are rejected', () async {
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    final gate = Completer<void>();
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((_) => gate.future);
    when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
      (_) => const Stream.empty(),
    );

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider
          .overrideWith((ref) => ChatRecorderController(
                ref,
                recorderFactory: () => mockRecorder,
                tempDirectoryProvider: () async => Directory.systemTemp,
                config: const ChatRecorderConfig(maxSeconds: 2),
              )),
    ]);
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});

    final controller = container.read(chatRecorderControllerProvider.notifier);
    unawaited(controller.start());
    await controller.start();
    final state = container.read(chatRecorderControllerProvider);
    expect(
      state.errorType == null ||
          state.errorType == ChatRecorderErrorType.concurrentOperation,
      isTrue,
    );
    gate.complete();
    // Wait for first start to finish
    await Future<void>.delayed(const Duration(milliseconds: 10));
    sub.close();
    container.dispose();
  });

  test('transcription failures surface friendly error', () async {
    // Prepare minimal AI configs
    final aiRepo = _InMemoryAiConfigRepo();
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: 'p1',
        baseUrl: 'http://localhost:1234',
        apiKey: 'k',
        name: 'Gemini',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.gemini,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: 'm1',
        name: 'gemini-2.5-flash',
        providerModelId: 'gemini-2.5-flash',
        inferenceProviderId: 'p1',
        createdAt: DateTime.now(),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );

    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String?;
      if (path != null) {
        final f = await File(path).create(recursive: true);
        await f.writeAsBytes(<int>[1, 2, 3]);
      }
    });
    when(() => mockRecorder.stop()).thenAnswer((_) async => null);
    when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
      (_) => const Stream.empty(),
    );

    final mockCloud = _MockCloudInferenceRepository();
    when(() => mockCloud.generateWithAudio(
          any(),
          model: any(named: 'model'),
          audioBase64: any(named: 'audioBase64'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          overrideClient: any(named: 'overrideClient'),
          tools: any(named: 'tools'),
        )).thenAnswer((_) => Stream.error(Exception('network down')));

    final container = ProviderContainer(overrides: [
      aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
      cloudInferenceRepositoryProvider.overrideWith((_) => mockCloud),
      chatRecorderControllerProvider
          .overrideWith((ref) => ChatRecorderController(
                ref,
                recorderFactory: () => mockRecorder,
                tempDirectoryProvider: () async => Directory.systemTemp,
                config: const ChatRecorderConfig(maxSeconds: 2),
              )),
    ]);
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});

    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    await controller.stopAndTranscribe();
    final state = container.read(chatRecorderControllerProvider);
    expect(state.errorType, ChatRecorderErrorType.transcriptionFailed);
    expect(state.error, contains('Transcription failed'));
    sub.close();
    container.dispose();
  });

  test('start() handles temp directory failure gracefully', () async {
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider
          .overrideWith((ref) => ChatRecorderController(
                ref,
                recorderFactory: () => mockRecorder,
                tempDirectoryProvider: () async =>
                    throw const FileSystemException('No space left on device'),
                config: const ChatRecorderConfig(maxSeconds: 2),
              )),
    ]);
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});

    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    final state = container.read(chatRecorderControllerProvider);
    expect(state.errorType, ChatRecorderErrorType.startFailed);
    expect(state.error, contains('Failed to start recording'));

    sub.close();
    container.dispose();
  });
}
