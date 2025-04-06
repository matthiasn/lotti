import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../helpers/path_provider.dart';
import '../test_data/test_data.dart';

class MockDirectory extends Mock implements Directory {}

class MockFile extends Mock implements File {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioUtils Tests - ', () {
    late Directory mockDocDir;
    late JournalAudio testAudioJournal;

    setUpAll(() async {
      setFakeDocumentsPath();

      // Create a test JournalAudio with specific paths for testing
      testAudioJournal = JournalAudio(
        meta: testAudioEntry.meta,
        data: AudioData(
          dateFrom: testAudioEntry.data.dateFrom,
          dateTo: testAudioEntry.data.dateTo,
          duration: testAudioEntry.data.duration,
          audioFile: 'test-audio.aac',
          audioDirectory: '/audio/2023-01-01/',
        ),
      );
    });

    setUp(() async {
      // Reset GetIt before each test and register a fresh mockDocDir
      await getIt.reset();
      mockDocDir = await getApplicationDocumentsDirectory();
      getIt.registerSingleton<Directory>(mockDocDir);
    });

    tearDown(getIt.reset);

    test('getRelativeAudioPath returns correct path', () {
      final expectedPath =
          '${testAudioJournal.data.audioDirectory}${testAudioJournal.data.audioFile}';
      final result = AudioUtils.getRelativeAudioPath(testAudioJournal);

      expect(result, equals(expectedPath));
      expect(result, equals('/audio/2023-01-01/test-audio.aac'));
    });

    test('getAudioPath returns correct full path', () {
      final expectedPath =
          '${mockDocDir.path}${testAudioJournal.data.audioDirectory}${testAudioJournal.data.audioFile}';
      final result = AudioUtils.getAudioPath(testAudioJournal, mockDocDir);

      expect(result, equals(expectedPath));
    });

    test('getFullAudioPath returns correct full path', () async {
      final expectedPath =
          '${mockDocDir.path}${testAudioJournal.data.audioDirectory}${testAudioJournal.data.audioFile}';
      final result = await AudioUtils.getFullAudioPath(testAudioJournal);

      expect(result, equals(expectedPath));
    });
  });
}
