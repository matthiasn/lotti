import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late MockAudioRecorder mockAudioRecorder;
  late AudioRecorderRepository repository;

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(const Duration(milliseconds: 20));
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockAudioRecorder = MockAudioRecorder();
    getIt.registerSingleton<LoggingService>(mockLoggingService);
    repository = AudioRecorderRepository(mockAudioRecorder);
  });

  tearDown(getIt.reset);

  group('AudioRecorderRepository', () {
    test('hasPermission returns true when permission granted', () async {
      when(() => mockAudioRecorder.hasPermission())
          .thenAnswer((_) async => true);

      final result = await repository.hasPermission();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.hasPermission()).called(1);
      verifyNever(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });

    test('hasPermission returns false and logs exception on error', () async {
      when(() => mockAudioRecorder.hasPermission())
          .thenThrow(Exception('Permission error'));

      final result = await repository.hasPermission();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.hasPermission()).called(1);
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'audio_recorder_repository',
          subDomain: 'hasPermission',
          stackTrace: any<dynamic>(named: 'stackTrace'),
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

    test('isRecording returns true when recording is active', () async {
      when(() => mockAudioRecorder.isRecording()).thenAnswer((_) async => true);

      final result = await repository.isRecording();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test('isRecording returns false when not recording', () async {
      when(() => mockAudioRecorder.isRecording())
          .thenAnswer((_) async => false);

      final result = await repository.isRecording();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test(
        'startRecording returns null due to directory creation in test environment',
        () async {
      // Stub the mock start method to complete successfully
      when(() => mockAudioRecorder.start(any<RecordConfig>(),
          path: any(named: 'path'))).thenAnswer((_) async {});

      // In test environment, directory creation will fail, so we expect null
      final result = await repository.startRecording();

      expect(result, isNull);
      // Verify that exception was logged due to directory creation failure
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'audio_recorder_repository',
          subDomain: 'startRecording',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('startRecording returns null and logs exception on error', () async {
      when(() => mockAudioRecorder.start(any<RecordConfig>(),
          path: any(named: 'path'))).thenThrow(Exception('Recording error'));

      final result = await repository.startRecording();

      expect(result, isNull);
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'audio_recorder_repository',
          subDomain: 'startRecording',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('stopRecording completes successfully', () async {
      when(() => mockAudioRecorder.stop())
          .thenAnswer((_) async => '/test/path.m4a');

      await expectLater(repository.stopRecording(), completes);
      verify(() => mockAudioRecorder.stop()).called(1);
    });

    test('stopRecording completes without throwing on error', () async {
      when(() => mockAudioRecorder.stop()).thenThrow(Exception('Stop error'));

      await expectLater(repository.stopRecording(), completes);
    });

    test('pauseRecording completes successfully', () async {
      when(() => mockAudioRecorder.pause()).thenAnswer((_) async {});

      await expectLater(repository.pauseRecording(), completes);
      verify(() => mockAudioRecorder.pause()).called(1);
    });

    test('pauseRecording completes without throwing on error', () async {
      when(() => mockAudioRecorder.pause()).thenThrow(Exception('Pause error'));

      await expectLater(repository.pauseRecording(), completes);
    });

    test('resumeRecording completes successfully', () async {
      when(() => mockAudioRecorder.resume()).thenAnswer((_) async {});

      await expectLater(repository.resumeRecording(), completes);
      verify(() => mockAudioRecorder.resume()).called(1);
    });

    test('resumeRecording completes without throwing on error', () async {
      when(() => mockAudioRecorder.resume())
          .thenThrow(Exception('Resume error'));

      await expectLater(repository.resumeRecording(), completes);
    });

    test('dispose completes successfully', () async {
      when(() => mockAudioRecorder.dispose()).thenAnswer((_) async {});

      await expectLater(repository.dispose(), completes);
      verify(() => mockAudioRecorder.dispose()).called(1);
    });

    test('dispose completes without throwing on error', () async {
      when(() => mockAudioRecorder.dispose())
          .thenThrow(Exception('Dispose error'));

      await expectLater(repository.dispose(), completes);
    });

    test('amplitudeStream returns a stream', () {
      const mockStream = Stream<Amplitude>.empty();
      when(() => mockAudioRecorder.onAmplitudeChanged(any<Duration>()))
          .thenAnswer((_) => mockStream);

      final stream = repository.amplitudeStream;
      expect(stream, isA<Stream<Amplitude>>());
      verify(() => mockAudioRecorder.onAmplitudeChanged(any<Duration>()))
          .called(1);
    });
  });
}
