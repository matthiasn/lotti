import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../mocks/mocks.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

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
      verifyNever(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
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
  });
}
