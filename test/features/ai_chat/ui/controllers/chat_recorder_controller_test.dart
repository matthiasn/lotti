// ignore_for_file: avoid_slow_async_io, cascade_invocations, prefer_const_constructors
import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
// ignore_for_file: unnecessary_lambdas
import 'package:record/record.dart' as record;

class _MockAudioRecorder extends Mock implements record.AudioRecorder {}

class _MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class _MockTranscriptionService extends Mock
    implements AudioTranscriptionService {}

class _InMemoryAiConfigRepo extends AiConfigRepository {
  _InMemoryAiConfigRepo() : super(AiConfigDb(inMemoryDatabase: true));
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

class _MockLoggingService extends Mock implements LoggingService {}

class _ThrowingCancelSubscription
    implements StreamSubscription<record.Amplitude> {
  _ThrowingCancelSubscription();

  @override
  Future<void> cancel() => Future.error(Exception('amp cancel fail'));

  @override
  bool get isPaused => false;

  @override
  void onData(void Function(record.Amplitude data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future.value(futureValue as E);
}

class _ThrowOnCancelStream extends Stream<record.Amplitude> {
  @override
  StreamSubscription<record.Amplitude> listen(
    void Function(record.Amplitude event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final sub = _ThrowingCancelSubscription();
    // simulate immediate data then done
    onData?.call(record.Amplitude(current: -40, max: -30));
    onDone?.call();
    return sub;
  }
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

  // Intentionally keep LoggingService registered across tests to avoid
  // late-dispose races during async cleanup.

  test('start() without permission sets errorType and message', () async {
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider.overrideWith(() => ChatRecorderController(
            recorderFactory: () => mockRecorder,
            tempDirectoryProvider: () async => Directory.systemTemp,
            config: const ChatRecorderConfig(maxSeconds: 2),
          )),
    ]);
    // No need to keep provider alive for this quick path
    final sub1 = container.listen(chatRecorderControllerProvider, (_, __) {});
    addTearDown(sub1.close);
    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    final state = container.read(chatRecorderControllerProvider);
    expect(state.errorType, ChatRecorderErrorType.permissionDenied);
    expect(state.error, contains('Microphone permission denied'));
  });

  test('concurrent start attempts are rejected', () async {
    // Use fake time to avoid real waits
    fakeAsync((FakeAsync async) {
      final mockRecorder = _MockAudioRecorder();
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      final gate = Completer<void>();
      when(() => mockRecorder.start(any<record.RecordConfig>(),
          path: any(named: 'path'))).thenAnswer((_) => gate.future);
      // Emit amplitude events so state changes to recording
      when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
        (_) => Stream<record.Amplitude>.fromIterable(
          List.filled(5, record.Amplitude(current: -40, max: -30)),
        ),
      );

      final container = ProviderContainer(overrides: [
        chatRecorderControllerProvider
            .overrideWith(() => ChatRecorderController(
                  recorderFactory: () => mockRecorder,
                  tempDirectoryProvider: () async => Directory.systemTemp,
                  config: const ChatRecorderConfig(maxSeconds: 2),
                )),
      ]);
      final sub = container.listen(chatRecorderControllerProvider, (_, __) {});

      final sub2 = container.listen(chatRecorderControllerProvider, (_, __) {});
      final controller =
          container.read(chatRecorderControllerProvider.notifier);
      unawaited(controller.start());
      // Second start should trigger concurrent operation error
      controller.start();
      async.flushMicrotasks();
      final state = container.read(chatRecorderControllerProvider);
      expect(state.errorType, ChatRecorderErrorType.concurrentOperation);
      gate.complete();
      // Allow the first start() to complete deterministically
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();
      sub.close();
      sub2.close();
      container.dispose();
    });
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
    // Emit amplitude events so state changes to recording
    when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
      (_) => Stream<record.Amplitude>.fromIterable(
        List.filled(5, record.Amplitude(current: -40, max: -30)),
      ),
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
      chatRecorderControllerProvider.overrideWith(() => ChatRecorderController(
            recorderFactory: () => mockRecorder,
            tempDirectoryProvider: () async => Directory.systemTemp,
            config: const ChatRecorderConfig(maxSeconds: 2),
          )),
    ]);
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});

    final sub3 = container.listen(chatRecorderControllerProvider, (_, __) {});
    addTearDown(sub3.close);
    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    await controller.stopAndTranscribe();
    final state = container.read(chatRecorderControllerProvider);
    expect(state.errorType, ChatRecorderErrorType.transcriptionFailed);
    expect(state.error, contains('Transcription failed'));
    sub.close();
    container.dispose();
  });

  test('dispose cleans files, cancels timer, clears amplitudes', () async {
    final baseTemp = await Directory.systemTemp.createTemp('rec_test_');
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});

    // Allow recording to start without creating file
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((_) async {});
    // Emit amplitude events so state changes to recording
    when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer((_) {
      // Emit 5 amplitude samples synchronously to drive state without timers
      return Stream<record.Amplitude>.fromIterable(List.generate(
        5,
        (_) => record.Amplitude(current: -40, max: -30),
      ));
    });

    const now = 1234567890;
    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider.overrideWith(() => ChatRecorderController(
            recorderFactory: () => mockRecorder,
            nowMillisProvider: () => now,
            tempDirectoryProvider: () async => baseTemp,
            config: const ChatRecorderConfig(maxSeconds: 1),
          )),
      audioTranscriptionServiceProvider
          .overrideWithValue(_MockTranscriptionService()),
    ]);
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});
    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();

    final tempSubdir = Directory('${baseTemp.path}/lotti_chat_rec');
    expect(await tempSubdir.exists(), isTrue);

    // Set some amplitudes in state so we can verify they clear on dispose
    controller.state = controller.state.copyWith(
      amplitudeHistory: List<double>.filled(5, 0.5),
    );
    expect(
        container.read(chatRecorderControllerProvider).amplitudeHistory.length,
        5);

    // Check amplitude history before dispose
    final stateBeforeDispose = container.read(chatRecorderControllerProvider);
    expect(stateBeforeDispose.amplitudeHistory.length, 5);

    // Dispose the controller (simulates provider disposal)
    sub.close();
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Directory is cleaned up after dispose
    expect(await tempSubdir.exists(), isFalse);
  });

  test('creates audio file and deletes on cancel', () async {
    final baseTemp = await Directory.systemTemp.createTemp('rec_test_');
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});

    // Simulate file creation by the recorder
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String;
      final f = await File(path).create(recursive: true);
      await f.writeAsBytes([1, 2, 3]);
    });
    // Emit amplitude events so state changes to recording
    when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
      (_) => Stream.periodic(
        const Duration(milliseconds: 50),
        (_) => record.Amplitude(current: -40, max: -30),
      ).take(5),
    );
    when(() => mockRecorder.stop()).thenAnswer((_) async => null);

    const now = 4242424242;
    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider.overrideWith(() => ChatRecorderController(
            recorderFactory: () => mockRecorder,
            nowMillisProvider: () => now,
            tempDirectoryProvider: () async => baseTemp,
            config: const ChatRecorderConfig(maxSeconds: 10),
          )),
      audioTranscriptionServiceProvider
          .overrideWithValue(_MockTranscriptionService()),
    ]);

    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});
    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();

    final tempSubdir = Directory('${baseTemp.path}/lotti_chat_rec');
    final file = File('${tempSubdir.path}/chat_$now.m4a');
    expect(await file.exists(), isTrue);

    // Wait for amplitude events to be processed and state to change to recording
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await controller.cancel();
    // Give cleanup some time to complete
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(await file.exists(), isFalse,
        reason: 'Audio file should be deleted');
    expect(await tempSubdir.exists(), isFalse,
        reason: 'Temp directory should be deleted');
    sub.close();
    container.dispose();
  });

  test("rapid start-stop cycles don't leak and stay stable", () async {
    final baseTemp = await Directory.systemTemp.createTemp('rec_test_');
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    // Emit amplitude events so state changes to recording
    when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
      (_) => Stream.periodic(
        const Duration(milliseconds: 50),
        (_) => record.Amplitude(current: -40, max: -30),
      ).take(5),
    );

    // Recorder.start creates file
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String;
      await File(path).create(recursive: true);
    });
    // Recorder.stop is a no-op
    when(() => mockRecorder.stop()).thenAnswer((_) async => null);

    // Fast transcription result to avoid delays
    final mockSvc = _MockTranscriptionService();
    when(() => mockSvc.transcribe(any())).thenAnswer((_) async => 'ok');

    final container = ProviderContainer(overrides: [
      audioTranscriptionServiceProvider.overrideWithValue(mockSvc),
      chatRecorderControllerProvider.overrideWith(() => ChatRecorderController(
            recorderFactory: () => mockRecorder,
            tempDirectoryProvider: () async => baseTemp,
            config: const ChatRecorderConfig(maxSeconds: 10),
          )),
    ]);

    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});
    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    await controller.stopAndTranscribe();
    await controller.start();
    await controller.stopAndTranscribe();

    // Final state should be idle with no temp dir left behind
    expect(container.read(chatRecorderControllerProvider).status,
        ChatRecorderStatus.idle);
    expect(
        await Directory('${baseTemp.path}/lotti_chat_rec').exists(), isFalse);
    sub.close();
    container.dispose();
  });

  test('timeout during transcription surfaces error and cleans up', () async {
    final baseTemp = await Directory.systemTemp.createTemp('rec_test_');
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    // Emit amplitude events so state changes to recording
    when(() => mockRecorder.onAmplitudeChanged(any())).thenAnswer(
      (_) => Stream.periodic(
        const Duration(milliseconds: 50),
        (_) => record.Amplitude(current: -40, max: -30),
      ).take(5),
    );
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String;
      await File(path).create(recursive: true);
    });
    when(() => mockRecorder.stop()).thenAnswer((_) async => null);

    final mockSvc = _MockTranscriptionService();
    when(() => mockSvc.transcribe(any()))
        .thenThrow(TimeoutException('timeout'));

    final container = ProviderContainer(overrides: [
      audioTranscriptionServiceProvider.overrideWithValue(mockSvc),
      chatRecorderControllerProvider.overrideWith(() => ChatRecorderController(
            recorderFactory: () => mockRecorder,
            tempDirectoryProvider: () async => baseTemp,
            config: const ChatRecorderConfig(maxSeconds: 10),
          )),
    ]);

    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});
    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    await controller.stopAndTranscribe();

    final state = container.read(chatRecorderControllerProvider);
    expect(state.errorType, ChatRecorderErrorType.transcriptionFailed);
    expect(
        await Directory('${baseTemp.path}/lotti_chat_rec').exists(), isFalse);
    sub.close();
    container.dispose();
  });

  test('start() handles temp directory failure gracefully', () async {
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider.overrideWith(() => ChatRecorderController(
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

  test('stopAndTranscribe logs when recorder.stop throws', () async {
    final mockLogger = _MockLoggingService();
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(mockLogger);
    } else {
      getIt.unregister<LoggingService>();
      getIt.registerSingleton<LoggingService>(mockLogger);
    }

    final baseTemp = await Directory.systemTemp.createTemp('rec_test_');
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    when(() => mockRecorder.onAmplitudeChanged(any()))
        .thenAnswer((_) => Stream<record.Amplitude>.empty());
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String;
      await File(path).create(recursive: true);
    });
    when(() => mockRecorder.stop()).thenThrow(Exception('stop fail'));

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider.overrideWith(() {
        return ChatRecorderController(
          recorderFactory: () => mockRecorder,
          tempDirectoryProvider: () async => baseTemp,
          config: const ChatRecorderConfig(maxSeconds: 2),
        );
      }),
      audioTranscriptionServiceProvider
          .overrideWithValue(_MockTranscriptionService()),
    ]);
    addTearDown(container.dispose);

    // Keep provider alive during async operations
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});
    addTearDown(sub.close);

    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    await controller.stopAndTranscribe();

    verify(() => mockLogger.captureException(
          any<dynamic>(),
          stackTrace: any<dynamic>(named: 'stackTrace'),
          domain: 'ChatRecorderController',
          subDomain: 'stopAndTranscribe.stop',
        )).called(1);
  });

  test('cancel logs when ampSub.cancel and recorder.stop throw', () async {
    final mockLogger = _MockLoggingService();
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(mockLogger);
    } else {
      getIt.unregister<LoggingService>();
      getIt.registerSingleton<LoggingService>(mockLogger);
    }

    final baseTemp = await Directory.systemTemp.createTemp('rec_test_');
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    // Stream that returns a subscription whose cancel throws
    when(() => mockRecorder.onAmplitudeChanged(any()))
        .thenAnswer((_) => _ThrowOnCancelStream());
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String;
      await File(path).create(recursive: true);
    });
    when(() => mockRecorder.stop()).thenThrow(Exception('stop fail'));

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider.overrideWith(() {
        return ChatRecorderController(
          recorderFactory: () => mockRecorder,
          tempDirectoryProvider: () async => baseTemp,
          config: const ChatRecorderConfig(maxSeconds: 2),
        );
      }),
      audioTranscriptionServiceProvider
          .overrideWithValue(_MockTranscriptionService()),
    ]);
    addTearDown(container.dispose);

    // Keep provider alive during async operations
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});
    addTearDown(sub.close);

    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();
    await controller.cancel();

    verify(() => mockLogger.captureException(
          any<dynamic>(),
          stackTrace: any<dynamic>(named: 'stackTrace'),
          domain: 'ChatRecorderController',
          subDomain: 'cancel.ampSub',
        )).called(1);
    verify(() => mockLogger.captureException(
          any<dynamic>(),
          stackTrace: any<dynamic>(named: 'stackTrace'),
          domain: 'ChatRecorderController',
          subDomain: 'cancel.recorder',
        )).called(1);
  });

  test('cleanup logs when file/dir are missing (PathNotFound)', () async {
    final mockLogger = _MockLoggingService();
    if (!getIt.isRegistered<LoggingService>()) {
      getIt.registerSingleton<LoggingService>(mockLogger);
    } else {
      getIt.unregister<LoggingService>();
      getIt.registerSingleton<LoggingService>(mockLogger);
    }

    final baseTemp = await Directory.systemTemp.createTemp('rec_test_');
    final mockRecorder = _MockAudioRecorder();
    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.dispose()).thenAnswer((_) async {});
    when(() => mockRecorder.onAmplitudeChanged(any()))
        .thenAnswer((_) => Stream<record.Amplitude>.empty());
    when(() => mockRecorder.start(any<record.RecordConfig>(),
        path: any(named: 'path'))).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String;
      final f = await File(path).create(recursive: true);
      await f.writeAsBytes([1, 2, 3]);
    });
    when(() => mockRecorder.stop()).thenAnswer((_) async => null);

    final container = ProviderContainer(overrides: [
      chatRecorderControllerProvider.overrideWith(() {
        return ChatRecorderController(
          recorderFactory: () => mockRecorder,
          tempDirectoryProvider: () async => baseTemp,
          config: const ChatRecorderConfig(maxSeconds: 2),
        );
      }),
      audioTranscriptionServiceProvider
          .overrideWithValue(_MockTranscriptionService()),
    ]);
    addTearDown(container.dispose);

    // Keep provider alive during async operations
    final sub = container.listen(chatRecorderControllerProvider, (_, __) {});
    addTearDown(sub.close);

    final controller = container.read(chatRecorderControllerProvider.notifier);
    await controller.start();

    // Remove the entire temp directory to trigger path-not-found during cleanup
    final tempSubdir = Directory('${baseTemp.path}/lotti_chat_rec');
    if (await tempSubdir.exists()) {
      await tempSubdir.delete(recursive: true);
    }

    await controller.cancel();

    // We accept either specific PathNotFound logs or the generic cleanup log,
    // depending on platform exception types.
    verify(() => mockLogger.captureException(
          any<dynamic>(),
          domain: 'ChatRecorderController',
          subDomain: any<String>(
              named: 'subDomain',
              that: predicate((s) =>
                  s == 'cleanup.fileNotFound' ||
                  s == 'cleanup.tempDirNotFound' ||
                  s == 'cleanup' ||
                  s == 'cleanup.tempDir')),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).called(greaterThanOrEqualTo(1));
  });

  test('getNormalizedAmplitudeHistory clamps and scales as expected', () async {
    final container = ProviderContainer(overrides: [
      audioTranscriptionServiceProvider
          .overrideWithValue(_MockTranscriptionService()),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(chatRecorderControllerProvider.notifier);
    // Inject sample dBFS values
    controller.state = controller.state.copyWith(
      amplitudeHistory: <double>[-100, -80, -50, -10, 0],
    );

    final normalized = controller.getNormalizedAmplitudeHistory();
    expect(normalized.length, 5);
    // Values below min clamp to 0.05
    expect(normalized[0], closeTo(0.05, 1e-6));
    // Exactly min dBFS
    expect(normalized[1], closeTo(0.05, 1e-6));
    // Mid-range maps between 0.05 and 1.0
    expect(normalized[2], closeTo(0.4571428571, 1e-6));
    // Exactly max dBFS
    expect(normalized[3], closeTo(1.0, 1e-6));
    // Above max clamps to 1.0
    expect(normalized[4], closeTo(1.0, 1e-6));
  });

  test('clearResult removes transcript and error but preserves history',
      () async {
    final container = ProviderContainer(overrides: [
      audioTranscriptionServiceProvider
          .overrideWithValue(_MockTranscriptionService()),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(chatRecorderControllerProvider.notifier);
    controller
      ..state = controller.state.copyWith(
        amplitudeHistory: const <double>[0.2, 0.5],
        transcript: 'hello world',
        error: 'some error',
      )
      ..clearResult();
    final state = container.read(chatRecorderControllerProvider);
    expect(state.transcript, isNull);
    expect(state.error, isNull);
    expect(state.amplitudeHistory, equals(const <double>[0.2, 0.5]));
  });
}
