import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/service/image_path_migration_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

const _failingEntryId = 'dfb5db6b-215c-5d1f-b05a-53830b125fad';

JournalImage _image({
  String id = _failingEntryId,
  String imageDirectory = 'images/2026-08-15/',
  String imageFile = 'capture.screenshot.jpg',
}) {
  final createdAt = DateTime(2026, 8, 15, 12);
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
    ),
    data: ImageData(
      imageId: id,
      imageFile: imageFile,
      imageDirectory: imageDirectory,
      capturedAt: createdAt,
    ),
  );
}

void main() {
  late Directory sandbox;
  late Directory documentsDirectory;
  late MockJournalDb journalDb;
  late MockPersistenceLogic persistenceLogic;
  late MockDomainLogger logger;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'image_path_migration_test_',
    );
    documentsDirectory = Directory('${sandbox.path}/Documents');
    await documentsDirectory.create();
    journalDb = MockJournalDb();
    persistenceLogic = MockPersistenceLogic();
    logger = MockDomainLogger();
  });

  tearDown(() async {
    await sandbox.delete(recursive: true);
  });

  ImagePathMigrationService makeService() => ImagePathMigrationService(
    documentsDirectory: documentsDirectory,
    journalDb: journalDb,
    persistenceLogic: persistenceLogic,
    logger: logger,
  );

  void stubPage(JournalImage Function() current) {
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalImage'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: [for (final flag in EntryFlag.values) flag.index],
        ids: null,
        limit: 200,
        // ignore: avoid_redundant_argument_values
        offset: 0,
      ),
    ).thenAnswer((_) async => [current()]);
  }

  test(
    'bulk migration repairs the real-world failing screenshot and is idempotent',
    () async {
      var current = _image();
      final corrected = current.copyWith(
        data: current.data.copyWith(imageDirectory: '/images/2026-08-15/'),
      );
      stubPage(() => current);
      when(
        () => persistenceLogic.updateJournalEntity(corrected, current.meta),
      ).thenAnswer((_) async {
        current = corrected;
        return true;
      });

      final legacyFile = File(
        getLegacyMalformedImagePath(
          current,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      await legacyFile.parent.create(recursive: true);
      await legacyFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
      await File('${legacyFile.path}.json').writeAsString('legacy sidecar');

      final service = makeService();
      final first = await service.migrateAll();

      final canonicalFile = File(
        getCanonicalImagePath(
          corrected,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      expect(first.affected, 1);
      expect(first.count(ImagePathMigrationStatus.migrated), 1);
      expect(canonicalFile.readAsBytesSync(), [0xFF, 0xD8, 0xFF, 0xE0]);
      expect(legacyFile.existsSync(), isFalse);
      expect(current.data.imageDirectory, '/images/2026-08-15/');

      final second = await service.migrateAll();

      expect(second.affected, 0);
      expect(second.count(ImagePathMigrationStatus.alreadyCorrect), 1);
      verify(
        () => persistenceLogic.updateJournalEntity(corrected, corrected.meta),
      ).called(1);
    },
  );

  test('bulk migration preserves non-identical target conflicts', () async {
    final image = _image();
    stubPage(() => image);
    final legacyFile = File(
      getLegacyMalformedImagePath(
        image,
        documentsDirectory: documentsDirectory.path,
      ),
    );
    final canonicalFile = File(
      getCanonicalImagePath(
        image,
        documentsDirectory: documentsDirectory.path,
      ),
    );
    await legacyFile.parent.create(recursive: true);
    await canonicalFile.parent.create(recursive: true);
    await legacyFile.writeAsBytes([1, 2, 3]);
    await canonicalFile.writeAsBytes([9, 8, 7]);

    final report = await makeService().migrateAll();

    expect(report.count(ImagePathMigrationStatus.conflict), 1);
    expect(await legacyFile.readAsBytes(), [1, 2, 3]);
    expect(await canonicalFile.readAsBytes(), [9, 8, 7]);
    verifyZeroInteractions(persistenceLogic);
  });

  test(
    'bulk migration retains both copies when metadata persistence fails',
    () async {
      final image = _image();
      final corrected = image.copyWith(
        data: image.data.copyWith(imageDirectory: '/images/2026-08-15/'),
      );
      stubPage(() => image);
      when(
        () => persistenceLogic.updateJournalEntity(corrected, image.meta),
      ).thenAnswer((_) async => false);
      final legacyFile = File(
        getLegacyMalformedImagePath(
          image,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      final canonicalFile = File(
        getCanonicalImagePath(
          image,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync([4, 3, 2, 1]);

      final report = await makeService().migrateAll();

      expect(report.count(ImagePathMigrationStatus.failed), 1);
      expect(legacyFile.readAsBytesSync(), [4, 3, 2, 1]);
      expect(canonicalFile.readAsBytesSync(), [4, 3, 2, 1]);
      expect(image.data.imageDirectory, 'images/2026-08-15/');
    },
  );

  test(
    'bulk migration reports genuinely missing files without updating metadata',
    () async {
      final image = _image();
      stubPage(() => image);

      final report = await makeService().migrateAll();

      expect(report.count(ImagePathMigrationStatus.missing), 1);
      expect(report.affected, 0);
      verifyZeroInteractions(persistenceLogic);
    },
  );

  test('bulk migration reports database failures without throwing', () async {
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalImage'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: [for (final flag in EntryFlag.values) flag.index],
        ids: null,
        limit: 200,
        // ignore: avoid_redundant_argument_values
        offset: 0,
      ),
    ).thenThrow(StateError('database unavailable'));

    final report = await makeService().migrateAll();

    expect(report.count(ImagePathMigrationStatus.failed), 1);
    expect(report.outcomes.single.entryId, 'bulk-query');
    expect(report.outcomes.single.error, isA<StateError>());
  });
}
