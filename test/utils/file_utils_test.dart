import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:research_package/model.dart';

import '../helpers/path_provider.dart';

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

    test('JSON file name for rating entry should be correct', () async {
      final testEntity = JournalEntity.rating(
        meta: testMeta,
        data: const RatingData(
          targetId: 'te-1',
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.8),
          ],
        ),
      );

      final path = entityPath(testEntity, Directory(''));
      expect(path, '/ratings/2021-11-30/test-id.rating.json');
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

    test('JSON file name for project entry should be correct', () async {
      final testEntity = JournalEntity.project(
        meta: testMeta,
        data: ProjectData(
          title: 'Test Project',
          status: ProjectStatus.active(
            id: 'status-1',
            createdAt: dt,
            utcOffset: 60,
          ),
          dateFrom: dt,
          dateTo: dt,
        ),
      );

      final path = entityPath(testEntity, Directory(''));
      expect(path, '/projects/2021-11-30/test-id.project.json');
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

    test(
      'JSON file name for checklist item entry should be correct',
      () async {
        final testEntity = JournalEntity.checklistItem(
          meta: testMeta,
          data: const ChecklistItemData(
            title: 'item',
            isChecked: false,
            linkedChecklists: [],
          ),
        );

        // Goes through relativeEntityPath's orElse branch, exercising both
        // folderForJournalEntity ('checklist_item') and typeSuffix
        // ('checklist_item') for the checklistItem case.
        final path = entityPath(testEntity, Directory(''));
        expect(
          path,
          '/checklist_item/2021-11-30/test-id.checklist_item.json',
        );
      },
    );

    test('JSON file name for day plan entry should be correct', () async {
      final testEntity = JournalEntity.dayPlan(
        meta: testMeta,
        data: DayPlanData(
          planDate: dt,
          status: const DayPlanStatus.draft(),
        ),
      );

      // Exercises folderForJournalEntity ('day_plans') and typeSuffix
      // ('day_plan') for the dayPlan case via the orElse branch.
      final path = entityPath(testEntity, Directory(''));
      expect(path, '/day_plans/2021-11-30/test-id.day_plan.json');
    });

    // folderForJournalEntity / typeSuffix are bypassed by entityPath for
    // audio and image entities (those take dedicated maybeMap branches), so
    // their audio/image cases are covered by calling the helpers directly.
    final audioEntity = JournalEntity.journalAudio(
      meta: testMeta,
      data: AudioData(
        audioDirectory: '/audio/2021-11-29/',
        dateFrom: dt,
        dateTo: dt,
        duration: const Duration(seconds: 1),
        audioFile: '2021-11-29_20-35-12-957.aac',
      ),
    );
    final imageEntity = JournalEntity.journalImage(
      meta: testMeta,
      data: ImageData(
        imageFile: 'some-image-id.IMG_9999.JPG',
        imageId: '',
        capturedAt: dt,
        imageDirectory: '/images/2021-11-29/',
      ),
    );

    for (final (entity, folder, suffix) in <(JournalEntity, String, String)>[
      (audioEntity, 'audio', 'audio'),
      (imageEntity, 'images', 'image'),
    ]) {
      test('folderForJournalEntity/typeSuffix for $folder entity', () {
        expect(folderForJournalEntity(entity), folder);
        expect(typeSuffix(entity), suffix);
      });
    }

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

    test(
      'findDocumentsDirectory returns correct directory based on platform',
      () async {
        // This can't be fully tested without having a way to mock the platform
        // Just testing that it returns a Directory
        expect(await findDocumentsDirectory(), isA<Directory>());
      },
    );

    test(
      'resolveJsonCandidateFile resolves inside docs dir and strips leading /',
      () {
        final file = resolveJsonCandidateFile(
          '/text_entries/2021-11-30/test-id.text.json',
        );
        final file2 = resolveJsonCandidateFile(
          'text_entries/2021-11-30/test-id.text.json',
        );
        final expected =
            '${docDir.path}/text_entries/2021-11-30/test-id.text.json';
        expect(file.path, expected);
        expect(file2.path, expected);
      },
    );

    test('resolveJsonCandidateFile rejects path traversal outside docs', () {
      final escape = Platform.isWindows
          ? r'..\..\..\Windows\System32\drivers\etc\hosts'
          : '../../../etc/passwd';
      expect(
        () => resolveJsonCandidateFile(escape),
        throwsA(isA<FileSystemException>()),
      );
    });

    // Properties: (a) any generated non-traversal relative path resolves to
    // a file inside docDir; (b) any '../'-prefixed path throws.
    glados.Glados2(
      glados.AnyUtils(glados.any).choose(const [
        'text_entries',
        'images',
        'audio',
        'agent_entities',
        'a b',
      ]),
      glados.AnyUtils(glados.any).choose(const [
        'file.json',
        'nested/file.json',
        '2021-11-30/test-id.text.json',
        'weird name.json',
      ]),
      glados.ExploreConfig(numRuns: 80),
    ).test('non-traversal relative paths always resolve inside docDir', (
      folder,
      tail,
    ) {
      for (final prefix in const ['', '/']) {
        final file = resolveJsonCandidateFile('$prefix$folder/$tail');
        expect(
          p.isWithin(p.normalize(docDir.path), p.normalize(file.path)),
          isTrue,
          reason: '$prefix$folder/$tail -> ${file.path}',
        );
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(1, 6),
      glados.AnyUtils(glados.any).choose(const [
        'etc/passwd',
        'secret.json',
        'outside/file.json',
      ]),
      glados.ExploreConfig(numRuns: 80),
    ).test('any ../-prefixed path throws FileSystemException', (
      depth,
      tail,
    ) {
      final escape = '${List.filled(depth, '..').join('/')}/$tail';
      expect(
        () => resolveJsonCandidateFile(escape),
        throwsA(isA<FileSystemException>()),
        reason: escape,
      );
    }, tags: 'glados');
  });
}
