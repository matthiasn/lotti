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

enum _GeneratedPathSegmentShape {
  alpha,
  numeric,
  dashed,
  underscored,
  dotted,
}

enum _GeneratedPathSeparator {
  slash,
  backslash,
}

class _GeneratedPathSegment {
  const _GeneratedPathSegment({
    required this.seed,
    required this.shape,
  });

  final int seed;
  final _GeneratedPathSegmentShape shape;

  String get text => switch (shape) {
    _GeneratedPathSegmentShape.alpha => 'segment$seed',
    _GeneratedPathSegmentShape.numeric => '42$seed',
    _GeneratedPathSegmentShape.dashed => 'segment-$seed',
    _GeneratedPathSegmentShape.underscored => 'segment_$seed',
    _GeneratedPathSegmentShape.dotted => 'segment.$seed.json',
  };

  @override
  String toString() {
    return '_GeneratedPathSegment(seed: $seed, shape: $shape)';
  }
}

class _GeneratedAttachmentIndexKey {
  const _GeneratedAttachmentIndexKey({
    required this.segments,
    required this.leadingSeparatorCount,
    required this.leadingSeparator,
    required this.innerSeparator,
  });

  final List<_GeneratedPathSegment> segments;
  final int leadingSeparatorCount;
  final _GeneratedPathSeparator leadingSeparator;
  final _GeneratedPathSeparator innerSeparator;

  String get rawPath {
    final leading = _separatorText(leadingSeparator) * leadingSeparatorCount;
    return '$leading${segments.map((segment) => segment.text).join(
      _separatorText(innerSeparator),
    )}';
  }

  String get expectedKey =>
      '/${segments.map((segment) => segment.text).join('/')}';

  @override
  String toString() {
    return '_GeneratedAttachmentIndexKey('
        'segments: $segments, '
        'leadingSeparatorCount: $leadingSeparatorCount, '
        'leadingSeparator: $leadingSeparator, '
        'innerSeparator: $innerSeparator)';
  }
}

class _GeneratedPayloadId {
  const _GeneratedPayloadId({
    required this.parts,
    required this.separator,
    required this.prefix,
    required this.suffix,
  });

  final List<_GeneratedPathSegment> parts;
  final String separator;
  final String prefix;
  final String suffix;

  String get text =>
      '$prefix${parts.map((part) => part.text).join(separator)}'
      '$suffix';

  String get encoded => Uri.encodeComponent(text);

  @override
  String toString() {
    return '_GeneratedPayloadId('
        'parts: $parts, '
        'separator: $separator, '
        'prefix: $prefix, '
        'suffix: $suffix)';
  }
}

String _separatorText(_GeneratedPathSeparator separator) {
  return switch (separator) {
    _GeneratedPathSeparator.slash => '/',
    _GeneratedPathSeparator.backslash => r'\',
  };
}

extension _AnyFileUtilsPath on glados.Any {
  glados.Generator<_GeneratedPathSegmentShape> get pathSegmentShape =>
      glados.AnyUtils(this).choose(_GeneratedPathSegmentShape.values);

  glados.Generator<_GeneratedPathSeparator> get pathSeparator =>
      glados.AnyUtils(this).choose(_GeneratedPathSeparator.values);

  glados.Generator<String> get payloadAffix =>
      glados.AnyUtils(this).choose(const ['', 'id ', '#', '%']);

  glados.Generator<String> get payloadSeparator =>
      glados.AnyUtils(this).choose(const ['', '-', '_', ' ', '/', '?']);

  glados.Generator<_GeneratedPathSegment> get pathSegment =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 10000),
        pathSegmentShape,
        (int seed, _GeneratedPathSegmentShape shape) =>
            _GeneratedPathSegment(seed: seed, shape: shape),
      );

  glados.Generator<_GeneratedAttachmentIndexKey> get attachmentIndexKey =>
      glados.CombinableAny(this).combine4(
        glados.ListAnys(this).listWithLengthInRange(1, 7, pathSegment),
        glados.IntAnys(this).intInRange(0, 5),
        pathSeparator,
        pathSeparator,
        (
          List<_GeneratedPathSegment> segments,
          int leadingSeparatorCount,
          _GeneratedPathSeparator leadingSeparator,
          _GeneratedPathSeparator innerSeparator,
        ) => _GeneratedAttachmentIndexKey(
          segments: segments,
          leadingSeparatorCount: leadingSeparatorCount,
          leadingSeparator: leadingSeparator,
          innerSeparator: innerSeparator,
        ),
      );

  glados.Generator<_GeneratedPayloadId> get payloadId =>
      glados.CombinableAny(this).combine4(
        glados.ListAnys(this).listWithLengthInRange(0, 5, pathSegment),
        payloadSeparator,
        payloadAffix,
        payloadAffix,
        (
          List<_GeneratedPathSegment> parts,
          String separator,
          String prefix,
          String suffix,
        ) => _GeneratedPayloadId(
          parts: parts,
          separator: separator,
          prefix: prefix,
          suffix: suffix,
        ),
      );
}

// ---------------------------------------------------------------------------
// Extra generators for the relativeEntityPath and resolveJsonCandidateFile
// Glados property tests added below main().
// ---------------------------------------------------------------------------

class _GeneratedEntityScenario {
  const _GeneratedEntityScenario({required this.meta});

  final Metadata meta;

  @override
  String toString() =>
      '_GeneratedEntityScenario(id=${meta.id}, createdAt=${meta.createdAt})';
}

extension _AnyEntityScenario on glados.Any {
  /// Generates a valid calendar date in the range [2000, 2030].
  /// Day is capped at 28 to sidestep month-end edge cases.
  glados.Generator<DateTime> get _entityDate =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(2000, 2030),
        glados.IntAnys(this).intInRange(1, 12),
        glados.IntAnys(this).intInRange(1, 28),
        DateTime.new,
      );

  /// Produces an entity scenario with a generated non-empty alphanumeric id
  /// and a generated creation date.
  glados.Generator<_GeneratedEntityScenario> get generatedEntityScenario =>
      glados.CombinableAny(this).combine2(
        glados.StringAnys(this).nonEmptyLetterOrDigits,
        _entityDate,
        (String id, DateTime createdAt) => _GeneratedEntityScenario(
          meta: Metadata(
            id: id,
            createdAt: createdAt,
            dateTo: createdAt,
            dateFrom: createdAt,
            updatedAt: createdAt,
          ),
        ),
      );

  /// Generates a "safe" relative path from two segment tokens joined by `/`.
  /// The [pathSegment] generator (from [_AnyFileUtilsPath]) never produces
  /// `..`, so the result is always a sandbox-safe relative path.
  glados.Generator<String> get safeRelativePath =>
      glados.CombinableAny(this).combine2(
        pathSegment,
        pathSegment,
        (_GeneratedPathSegment a, _GeneratedPathSegment b) =>
            '${a.text}/${b.text}',
      );
}

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

  group('normalizeAttachmentIndexKey', () {
    test('adds leading slash to bare path', () {
      expect(
        normalizeAttachmentIndexKey('agent_entities/a.json'),
        '/agent_entities/a.json',
      );
    });

    test('preserves single leading slash', () {
      expect(
        normalizeAttachmentIndexKey('/agent_entities/a.json'),
        '/agent_entities/a.json',
      );
    });

    test('collapses multiple leading slashes', () {
      expect(
        normalizeAttachmentIndexKey('///agent_entities/a.json'),
        '/agent_entities/a.json',
      );
    });

    test('converts backslashes to forward slashes', () {
      expect(
        normalizeAttachmentIndexKey(r'\agent_entities\a.json'),
        '/agent_entities/a.json',
      );
    });

    glados.Glados(
      glados.any.attachmentIndexKey,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'canonicalizes generated relative paths to one slash-prefixed key',
      (scenario) {
        final normalized = normalizeAttachmentIndexKey(scenario.rawPath);

        expect(normalized, scenario.expectedKey, reason: '$scenario');
        expect(normalized.startsWith('/'), isTrue, reason: '$scenario');
        expect(normalized.startsWith('//'), isFalse, reason: '$scenario');
        expect(normalized.contains(r'\'), isFalse, reason: '$scenario');
      },
      tags: 'glados',
    );
  });

  group('outbox bundle payload paths', () {
    test('builds encoded outbox bundle paths under /outbox_bundles/', () {
      expect(
        relativeOutboxBundlePath('abc-123'),
        '/outbox_bundles/abc-123.json',
      );
    });

    test('URI-encodes special characters in the bundle id', () {
      expect(
        relativeOutboxBundlePath('with/slash and space'),
        '/outbox_bundles/with%2Fslash%20and%20space.json',
      );
    });

    glados.Glados(
      glados.any.payloadId,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'URI-encodes generated outbox bundle ids under the bundle segment',
      (payloadId) {
        final path = relativeOutboxBundlePath(payloadId.text);

        expect(
          path,
          '$outboxBundlesSegment${payloadId.encoded}.json',
          reason: '$payloadId',
        );
        expect(isAgentPayloadPath(path), isFalse, reason: '$payloadId');
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.payloadId,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'URI-encodes generated notification ids under the notification segment',
      (payloadId) {
        final path = relativeNotificationPath(payloadId.text);

        expect(
          path,
          '$notificationsSegment${payloadId.encoded}.json',
          reason: '$payloadId',
        );
        expect(isAgentPayloadPath(path), isFalse, reason: '$payloadId');
      },
      tags: 'glados',
    );

    test(
      'outbox bundle paths are NOT classified as agent payload paths — '
      'agent payloads share a VC-dominance re-download skip optimization '
      'that does not apply to outbox bundles (each bundle has a fresh uuid '
      'so the local file never pre-exists)',
      () {
        expect(isAgentPayloadPath('/outbox_bundles/abc.json'), isFalse);
      },
    );

    glados.Glados(
      glados.any.payloadId,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'classifies generated agent entity and link paths as agent payloads',
      (payloadId) {
        expect(
          isAgentPayloadPath(relativeAgentEntityPath(payloadId.encoded)),
          isTrue,
          reason: '$payloadId',
        );
        expect(
          isAgentPayloadPath(relativeAgentLinkPath(payloadId.encoded)),
          isTrue,
          reason: '$payloadId',
        );
      },
      tags: 'glados',
    );
  });

  // ---------------------------------------------------------------------------
  // relativeEntityPath — Glados properties
  //
  // Tests the `orElse` branch (non-image, non-audio entity types) where the
  // path is built from folderForJournalEntity / typeSuffix / createdAt / id.
  // We parameterise over generated ids and creation dates and verify the
  // structural invariants without re-implementing DateFormat.
  // ---------------------------------------------------------------------------
  group('relativeEntityPath — properties', () {
    // Shared generator that produces (year, month, day, id) tuples.
    // Day is capped at 28 to avoid dealing with month-end edge cases.

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry path ends with .json and contains the entity id',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);

        expect(
          path.endsWith('.json'),
          isTrue,
          reason: 'path=$path, scenario=$scenario',
        );
        expect(
          path.contains(scenario.meta.id),
          isTrue,
          reason: 'path=$path, scenario=$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry path folder matches folderForJournalEntity',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);
        final expected = folderForJournalEntity(entity);

        // Path format: /$folder/$date/$id.$suffix.json
        expect(
          path.startsWith('/$expected/'),
          isTrue,
          reason: 'path=$path, folder=$expected, scenario=$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry path type-suffix matches typeSuffix helper',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);
        final suffix = typeSuffix(entity);

        // The filename portion is: $id.$suffix.json
        expect(
          path.contains('.$suffix.json'),
          isTrue,
          reason: 'path=$path, suffix=$suffix, scenario=$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.generatedEntityScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'journalEntry date subfolder matches yyyy-MM-dd of createdAt',
      (scenario) {
        final entity = JournalEntity.journalEntry(
          meta: scenario.meta,
        );
        final path = relativeEntityPath(entity);
        final createdAt = scenario.meta.createdAt;

        // Build expected date string without importing intl.
        final yyyy = createdAt.year.toString().padLeft(4, '0');
        final mm = createdAt.month.toString().padLeft(2, '0');
        final dd = createdAt.day.toString().padLeft(2, '0');
        final expectedDate = '$yyyy-$mm-$dd';

        expect(
          path.contains('/$expectedDate/'),
          isTrue,
          reason: 'path=$path, expectedDate=$expectedDate, scenario=$scenario',
        );
      },
      tags: 'glados',
    );
  });

  // ---------------------------------------------------------------------------
  // resolveJsonCandidateFile — Glados properties
  //
  // Verifies the sandbox invariant: any safe relative path resolves inside
  // the documents directory, and any path-traversal attempt throws.
  // ---------------------------------------------------------------------------
  group('resolveJsonCandidateFile — properties', () {
    late Directory propDocDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      setFakeDocumentsPath();
      propDocDir = await getApplicationDocumentsDirectory();
      await getIt.reset();
      getIt.registerSingleton<Directory>(propDocDir);
    });

    tearDownAll(getIt.reset);

    glados.Glados(
      glados.any.safeRelativePath,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'safe relative paths always resolve inside the documents directory',
      (relativePath) {
        final result = resolveJsonCandidateFile(relativePath);
        expect(
          result.path.startsWith(propDocDir.path),
          isTrue,
          reason: 'relativePath="$relativePath", resolved="${result.path}"',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.pathSegment,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'path-traversal prefix causes FileSystemException',
      (segment) {
        // Prepend enough ../ to escape any realistic nesting.
        final escapingPath = '../../../${segment.text}';
        expect(
          () => resolveJsonCandidateFile(escapingPath),
          throwsA(isA<FileSystemException>()),
          reason: 'escapingPath="$escapingPath"',
        );
      },
      tags: 'glados',
    );
  });
}
