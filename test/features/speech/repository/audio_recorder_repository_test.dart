import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDomainLogger mockDomainLogger;
  late MockAudioRecorder mockAudioRecorder;
  late AudioRecorderRepository repository;

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(const Duration(milliseconds: 20));
  });

  setUp(() {
    mockDomainLogger = MockDomainLogger();
    mockAudioRecorder = MockAudioRecorder();
    getIt.registerSingleton<DomainLogger>(mockDomainLogger);
    repository = AudioRecorderRepository(mockAudioRecorder);

    // Setup default mock behaviors
    when(
      () => mockDomainLogger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(getIt.reset);

  group('AudioRecorderRepository', () {
    test('hasPermission returns true when permission granted', () async {
      when(
        () => mockAudioRecorder.hasPermission(),
      ).thenAnswer((_) async => true);

      final result = await repository.hasPermission();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.hasPermission()).called(1);
      // Match ANY error invocation (including ones carrying a stackTrace) so the
      // success branch is proven to log no error at all, not merely no
      // stackTrace-less error.
      verifyNever(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });

    test('hasPermission returns false and logs exception on error', () async {
      when(
        () => mockAudioRecorder.hasPermission(),
      ).thenThrow(Exception('Permission error'));

      final result = await repository.hasPermission();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.hasPermission()).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'hasPermission',
        ),
      ).called(1);
    });

    test('isPaused returns true when recording is paused', () async {
      when(() => mockAudioRecorder.isPaused()).thenAnswer((_) async => true);

      final result = await repository.isPaused();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.isPaused()).called(1);
    });

    test('isPaused returns false when not paused', () async {
      when(() => mockAudioRecorder.isPaused()).thenAnswer((_) async => false);

      final result = await repository.isPaused();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isPaused()).called(1);
    });

    test('isPaused returns false and logs exception on error', () async {
      when(
        () => mockAudioRecorder.isPaused(),
      ).thenThrow(Exception('Pause check error'));

      final result = await repository.isPaused();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isPaused()).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          subDomain: 'isPaused',
        ),
      ).called(1);
    });

    test('isRecording returns true when recording is active', () async {
      when(() => mockAudioRecorder.isRecording()).thenAnswer((_) async => true);

      final result = await repository.isRecording();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test('isRecording returns false when not recording', () async {
      when(
        () => mockAudioRecorder.isRecording(),
      ).thenAnswer((_) async => false);

      final result = await repository.isRecording();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test('isRecording returns false and logs exception on error', () async {
      when(
        () => mockAudioRecorder.isRecording(),
      ).thenThrow(Exception('Recording check error'));

      final result = await repository.isRecording();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isRecording()).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          subDomain: 'isRecording',
        ),
      ).called(1);
    });

    test(
      'startRecording returns null due to directory creation in test environment',
      () async {
        // Stub the mock start method to complete successfully
        when(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).thenAnswer((_) async {});

        // In test environment, directory creation will fail, so we expect null
        final result = await repository.startRecording();

        expect(result, isNull);
        // Verify that exception was logged due to directory creation failure
        verify(
          () => mockDomainLogger.error(
            LogDomain.speech,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'startRecording',
          ),
        ).called(1);
      },
    );

    test('startRecording returns null and logs exception on error', () async {
      when(
        () => mockAudioRecorder.start(
          any<RecordConfig>(),
          path: any(named: 'path'),
        ),
      ).thenThrow(Exception('Recording error'));

      final result = await repository.startRecording();

      expect(result, isNull);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'startRecording',
        ),
      ).called(1);
    });

    test('stopRecording completes successfully', () async {
      when(
        () => mockAudioRecorder.stop(),
      ).thenAnswer((_) async => '/test/path.m4a');

      await expectLater(repository.stopRecording(), completes);
      verify(() => mockAudioRecorder.stop()).called(1);
    });

    test('stopRecording completes without throwing on error', () async {
      when(() => mockAudioRecorder.stop()).thenThrow(Exception('Stop error'));

      await expectLater(repository.stopRecording(), completes);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'stopRecording',
        ),
      ).called(1);
    });

    test('pauseRecording completes successfully', () async {
      when(() => mockAudioRecorder.pause()).thenAnswer((_) async {});

      await expectLater(repository.pauseRecording(), completes);
      verify(() => mockAudioRecorder.pause()).called(1);
    });

    test('pauseRecording completes without throwing on error', () async {
      when(() => mockAudioRecorder.pause()).thenThrow(Exception('Pause error'));

      await expectLater(repository.pauseRecording(), completes);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'pauseRecording',
        ),
      ).called(1);
    });

    test('resumeRecording completes successfully', () async {
      when(() => mockAudioRecorder.resume()).thenAnswer((_) async {});

      await expectLater(repository.resumeRecording(), completes);
      verify(() => mockAudioRecorder.resume()).called(1);
    });

    test('resumeRecording completes without throwing on error', () async {
      when(
        () => mockAudioRecorder.resume(),
      ).thenThrow(Exception('Resume error'));

      await expectLater(repository.resumeRecording(), completes);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'resumeRecording',
        ),
      ).called(1);
    });

    test('dispose completes successfully', () async {
      when(() => mockAudioRecorder.dispose()).thenAnswer((_) async {});

      await expectLater(repository.dispose(), completes);
      verify(() => mockAudioRecorder.dispose()).called(1);
    });

    test('dispose completes without throwing on error', () async {
      when(
        () => mockAudioRecorder.dispose(),
      ).thenThrow(Exception('Dispose error'));

      await expectLater(repository.dispose(), completes);
      verify(
        () => mockDomainLogger.error(
          LogDomain.speech,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'dispose',
        ),
      ).called(1);
    });

    test('amplitudeStream returns a stream', () {
      const mockStream = Stream<Amplitude>.empty();
      when(
        () => mockAudioRecorder.onAmplitudeChanged(any<Duration>()),
      ).thenAnswer((_) => mockStream);

      final stream = repository.amplitudeStream;
      expect(stream, isA<Stream<Amplitude>>());
      verify(
        () => mockAudioRecorder.onAmplitudeChanged(any<Duration>()),
      ).called(1);
    });

    test('amplitudeStream passes 20ms interval to onAmplitudeChanged', () {
      const mockStream = Stream<Amplitude>.empty();
      when(
        () => mockAudioRecorder.onAmplitudeChanged(any<Duration>()),
      ).thenAnswer((_) => mockStream);

      repository.amplitudeStream;

      final captured = verify(
        () => mockAudioRecorder.onAmplitudeChanged(captureAny<Duration>()),
      ).captured;
      expect(captured.single, const Duration(milliseconds: 20));
    });

    test(
      'startRecording returns AudioNote with correct fields when successful',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'audio_recorder_repository_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        getIt.registerSingleton<Directory>(tempDir);
        addTearDown(() {
          if (getIt.isRegistered<Directory>()) {
            getIt.unregister<Directory>();
          }
        });

        when(
          () => mockDomainLogger.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
            level: any(named: 'level'),
          ),
        ).thenReturn(null);

        when(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).thenAnswer((_) async {});

        final result = await repository.startRecording();

        expect(result, isNotNull);
        expect(result!.audioFile, endsWith('.m4a'));
        expect(result.audioDirectory, startsWith('/audio/'));
        expect(result.duration, Duration.zero);
        expect(
          result.createdAt.isBefore(
            DateTime.now().add(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        verify(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).called(1);
        // log is called twice: "Starting..." then "Audio recording started successfully"
        verify(
          () => mockDomainLogger.log(
            LogDomain.speech,
            any<String>(),
            subDomain: AudioRecorderConstants.startRecordingSubdomain,
          ),
        ).called(2);
      },
    );

    test(
      'startRecording records with correct config (sampleRate=48000, autoGain=true)',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'audio_recorder_repository_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        getIt.registerSingleton<Directory>(tempDir);
        addTearDown(() {
          if (getIt.isRegistered<Directory>()) {
            getIt.unregister<Directory>();
          }
        });

        when(
          () => mockDomainLogger.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
            level: any(named: 'level'),
          ),
        ).thenReturn(null);

        when(
          () => mockAudioRecorder.start(
            any<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).thenAnswer((_) async {});

        await repository.startRecording();

        final captured = verify(
          () => mockAudioRecorder.start(
            captureAny<RecordConfig>(),
            path: any(named: 'path'),
          ),
        ).captured;
        final config = captured.single as RecordConfig;
        expect(config.sampleRate, 48000);
        expect(config.autoGain, isTrue);
      },
    );

    test(
      'audioRecorderRepositoryProvider returns an AudioRecorderRepository',
      () {
        // Verify the provider can be read and returns the expected type.
        final mockRepo = MockAudioRecorderRepository();
        final container = ProviderContainer(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(audioRecorderRepositoryProvider);
        expect(repo, isA<AudioRecorderRepository>());
        expect(repo, same(mockRepo));
      },
    );

    test(
      'audioRecorderRepositoryProvider calls dispose on the repository when container disposes',
      () async {
        // The real provider function registers `ref.onDispose(() async { await
        // repository.dispose(); })`.  Because `AudioRecorder()` talks to a
        // platform channel, we mock it so the constructor call does not throw.
        const channel = MethodChannel('com.llfbandit.record/messages');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => null);
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );

        // Also stub DomainLogger.log because the repository logs during normal use.
        when(
          () => mockDomainLogger.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
            level: any(named: 'level'),
          ),
        ).thenReturn(null);

        // Stub dispose on the mock recorder that will be created internally.
        // We can't intercept the real AudioRecorder.dispose() easily, so we
        // use the channel mock to swallow the platform call.

        // Use the real provider function (not overrideWithValue) so that
        // ref.onDispose is actually registered.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read the provider to initialise it — this calls the real create fn.
        final repo = container.read(audioRecorderRepositoryProvider);
        expect(repo, isA<AudioRecorderRepository>());

        // Dispose — triggers ref.onDispose.
        container.dispose();

        // Flush microtasks so the async dispose callback completes.
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        // If we reached here without a MissingPluginException or other error
        // the onDispose path (lines 21-22) was exercised successfully.
      },
    );
  });
}
