import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' show Amplitude;

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late AudioRecorderRepository repository;

  setUp(() {
    mockLoggingService = MockLoggingService();
    getIt.registerSingleton<LoggingService>(mockLoggingService);
    repository = AudioRecorderRepository();
  });

  tearDown(getIt.reset);

  group('AudioRecorderRepository', () {
    test('hasPermission returns false and logs exception on error', () async {
      // In test environment, this will throw MissingPluginException
      final result = await repository.hasPermission();

      expect(result, isFalse);
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'audio_recorder_repository',
          subDomain: 'hasPermission',
        ),
      ).called(1);
    });

    test('isPaused returns false in test environment', () async {
      final result = await repository.isPaused();
      expect(result, isFalse);

      // In test environment, this might not throw an exception
      // so we don't verify exception logging
    });

    test('isRecording returns false in test environment', () async {
      final result = await repository.isRecording();
      expect(result, isFalse);

      // In test environment, this might not throw an exception
      // so we don't verify exception logging
    });

    test('startRecording returns null and logs exception on error', () async {
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
      await expectLater(repository.stopRecording(), completes);
    });

    test('pauseRecording completes without throwing', () async {
      await expectLater(repository.pauseRecording(), completes);
    });

    test('resumeRecording completes without throwing', () async {
      await expectLater(repository.resumeRecording(), completes);
    });

    test('dispose completes without throwing', () async {
      await expectLater(repository.dispose(), completes);
    });

    test('amplitudeStream returns a stream', () {
      final stream = repository.amplitudeStream;
      expect(stream, isA<Stream<Amplitude>>());
    });
  });
}
