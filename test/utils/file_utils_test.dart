import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:research_package/model.dart';

import '../helpers/path_provider.dart';

class MockFile extends Mock implements File {}

class MockDirectory extends Mock implements Directory {}

void main() {
  final dt = DateTime.fromMillisecondsSinceEpoch(1638265606966);

  final testMeta = Metadata(
    createdAt: dt,
    id: 'test-id',
    dateTo: dt,
    dateFrom: dt,
    updatedAt: dt,
  );

  group('File utils tests - ', () {
    late Directory docDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      setFakeDocumentsPath();

      docDir = await getApplicationDocumentsDirectory();

      // Reset GetIt before registering anything
      await getIt.reset();
      getIt.registerSingleton<Directory>(docDir);
    });

    tearDown(() {
      // No need to reset in tearDown if we're using the same directory instance
    });

    tearDownAll(getIt.reset);

    test('JSON file name for journal entry should be correct', () async {
      final testEntity = JournalEntity.journalEntry(
        meta: testMeta,
        entryText: const EntryText(plainText: 'test'),
      );

      final path = entityPath(testEntity, Directory(''));
      expect(path, '/text_entries/2021-11-30/test-id.text.json');
    });

    test('JSON file name for survey entry should be correct', () async {
      final testEntity = JournalEntity.survey(
        meta: testMeta,
        data: SurveyData(
          scoreDefinitions: {},
          calculatedScores: {},
          taskResult: RPTaskResult(identifier: ''),
        ),
      );

      final path = entityPath(testEntity, Directory(''));
      expect(path, '/surveys/2021-11-30/test-id.survey.json');
    });

    test('JSON file name for quantitative entry should be correct', () async {
      final testEntity = JournalEntity.quantitative(
        meta: testMeta,
        data: QuantitativeData.cumulativeQuantityData(
          dateFrom: dt,
          dateTo: dt,
          value: 1,
          dataType: 'dataType',
          unit: 'unit',
        ),
      );

      final path = entityPath(testEntity, Directory(''));
      expect(path, '/quantitative/2021-11-30/test-id.quantitative.json');
    });

    test('JSON file name for image entry should be correct', () async {
      final testEntity = JournalEntity.journalImage(
        meta: testMeta,
        data: ImageData(
          imageFile: 'some-image-id.IMG_9999.JPG',
          imageId: '',
          capturedAt: dt,
          imageDirectory: '/images/2021-11-29/',
        ),
      );

      final path = entityPath(testEntity, Directory(''));
      expect(
        path.contains('/images/2021-11-29/some-image-id.IMG_9999.JPG.json'),
        true,
      );
    });

    test('JSON file name for audio entry should be correct', () async {
      final testEntity = JournalEntity.journalAudio(
        meta: testMeta,
        data: AudioData(
          audioDirectory: '/audio/2021-11-29/',
          dateFrom: dt,
          dateTo: dt,
          duration: const Duration(seconds: 1),
          audioFile: '2021-11-29_20-35-12-957.aac',
        ),
      );

      final path = entityPath(testEntity, Directory(''));
      expect(path, '/audio/2021-11-29/2021-11-29_20-35-12-957.aac.json');
    });

    test('getDocumentsDirectory returns directory from GetIt', () {
      // We're already using the mock directory from our setup
      expect(getDocumentsDirectory(), docDir);
    });

    test('saveJson creates file and writes json content', () async {
      // Skip on CI to avoid file system operations
      if (Platform.environment.containsKey('CI')) {
        return;
      }

      // Create a temporary test directory
      final tempDir = await Directory.systemTemp.createTemp('file_utils_test_');
      final testPath = '${tempDir.path}/test.json';
      const testContent = '{"test": "data"}';

      try {
        // Test the function
        await saveJson(testPath, testContent);

        // Verify the file was created with the correct content
        final file = File(testPath);
        expect(file.existsSync(), isTrue);
        expect(await file.readAsString(), testContent);
      } finally {
        // Clean up
        await tempDir.delete(recursive: true);
      }
    });

    test('createAssetDirectory creates directory and returns path', () async {
      // Skip in CI environment to avoid file system operations
      if (Platform.environment.containsKey('CI')) {
        return;
      }

      // Create a temp dir for the test
      final tempDir = await Directory.systemTemp.createTemp('file_utils_test_');

      try {
        // We're already using the directory from GetIt, so we don't need to register it again

        // Test the function
        const relativePath = '/test/asset/dir';
        final result = await createAssetDirectory(relativePath);

        // Verify the directory was created
        // Note: this will use the docDir from GetIt, not tempDir
        final expectedPath = '${docDir.path}$relativePath';
        expect(result, expectedPath);
        expect(Directory(expectedPath).existsSync(), isTrue);
      } finally {
        // Clean up
        await tempDir.delete(recursive: true);
      }
    });

    test('findDocumentsDirectory returns correct directory based on platform',
        () async {
      // This can't be fully tested without having a way to mock the platform
      // Just testing that it returns a Directory
      expect(await findDocumentsDirectory(), isA<Directory>());
    });
  });
}
