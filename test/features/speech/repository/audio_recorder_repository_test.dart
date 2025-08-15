import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioRecorder extends Mock implements AudioRecorder {}

class MockAmplitude extends Mock implements Amplitude {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late MockAudioRecorder mockAudioRecorder;
  late AudioRecorderRepository repository;
  late Directory testDirectory;

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(StackTrace.current);
  });

  setUp(() async {
    mockLoggingService = MockLoggingService();
    mockAudioRecorder = MockAudioRecorder();

    // Create a temporary directory for testing
    testDirectory = await Directory.systemTemp.createTemp('audio_test');

    // Register mocks in GetIt
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<Directory>(testDirectory);

    // Create repository with mocked AudioRecorder
    repository = AudioRecorderRepository(mockAudioRecorder);
  });

  tearDown(() async {
    await getIt.reset();
    // Clean up temporary directory
    if (testDirectory.existsSync()) {
      await testDirectory.delete(recursive: true);
    }
  });

  group('AudioRecorderRepository', () {
    test('hasPermission returns true when permission granted', () async {
      // Mock successful permission check
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
      // Mock exception
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
        ),
      ).called(1);
    });

    test('isPaused returns true when recording is paused', () async {
      when(() => mockAudioRecorder.isPaused()).thenAnswer((_) async => true);

      final result = await repository.isPaused();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.isPaused()).called(1);
    });

    test('isPaused returns false on error', () async {
      when(() => mockAudioRecorder.isPaused())
          .thenThrow(Exception('Check error'));

      final result = await repository.isPaused();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isPaused()).called(1);
    });

    test('isRecording returns true when recording', () async {
      when(() => mockAudioRecorder.isRecording()).thenAnswer((_) async => true);

      final result = await repository.isRecording();

      expect(result, isTrue);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test('isRecording returns false on error', () async {
      when(() => mockAudioRecorder.isRecording())
          .thenThrow(Exception('Check error'));

      final result = await repository.isRecording();

      expect(result, isFalse);
      verify(() => mockAudioRecorder.isRecording()).called(1);
    });

    test('startRecording returns AudioNote on success', () async {
      // Mock successful recording start
      when(() => mockAudioRecorder.start(
            any(),
            path: any(named: 'path'),
          )).thenAnswer((_) async {});

      final result = await repository.startRecording();

      expect(result, isNotNull);
      expect(result!.audioFile, endsWith('.m4a'));
      expect(result.audioDirectory, contains('audio'));
      verify(() => mockAudioRecorder.start(
            any(),
            path: any(named: 'path'),
          )).called(1);
    });

    test('startRecording returns null and logs exception on error', () async {
      when(() => mockAudioRecorder.start(
            any(),
            path: any(named: 'path'),
          )).thenThrow(Exception('Start error'));

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

    test('stopRecording completes without throwing', () async {
      when(() => mockAudioRecorder.stop()).thenAnswer((_) async => null);

      await expectLater(repository.stopRecording(), completes);

      verify(() => mockAudioRecorder.stop()).called(1);
    });

    test('pauseRecording completes without throwing', () async {
      when(() => mockAudioRecorder.pause()).thenAnswer((_) async {});

      await expectLater(repository.pauseRecording(), completes);

      verify(() => mockAudioRecorder.pause()).called(1);
    });

    test('resumeRecording completes without throwing', () async {
      when(() => mockAudioRecorder.resume()).thenAnswer((_) async {});

      await expectLater(repository.resumeRecording(), completes);

      verify(() => mockAudioRecorder.resume()).called(1);
    });

    test('dispose completes without throwing', () async {
      when(() => mockAudioRecorder.dispose()).thenAnswer((_) async {});

      await expectLater(repository.dispose(), completes);

      verify(() => mockAudioRecorder.dispose()).called(1);
    });

    test('amplitudeStream returns a stream', () {
      const mockStream = Stream<Amplitude>.empty();
      when(() => mockAudioRecorder.onAmplitudeChanged(any()))
          .thenAnswer((_) => mockStream);

      final stream = repository.amplitudeStream;

      expect(stream, isA<Stream<Amplitude>>());
      verify(() => mockAudioRecorder.onAmplitudeChanged(any())).called(1);
    });
  });
}
