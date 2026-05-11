import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/sync/matrix/sync_journal_entity_loader.dart';
import 'package:path/path.dart' as path;

import '../../../helpers/fallbacks.dart';

void main() {
  final getIt = GetIt.instance;

  group('FileSyncJournalEntityLoader', () {
    late Directory tempDir;

    setUp(() async {
      await getIt.reset();
      getIt.allowReassignment = true;
      tempDir = await Directory.systemTemp.createTemp('sync_loader_test');
      getIt.registerSingleton<Directory>(tempDir);
    });

    tearDown(() async {
      await getIt.reset();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<void> writeEntity(String relativePath) async {
      final file = File(path.join(tempDir.path, relativePath));
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(fallbackJournalEntity.toJson()));
    }

    test('loads entity when jsonPath starts with leading slash', () async {
      await writeEntity('entity.json');

      const loader = FileSyncJournalEntityLoader();
      final entity = await loader.load(jsonPath: '/entity.json');

      expect(entity.meta.id, fallbackJournalEntity.meta.id);
    });

    test('loads entity when jsonPath is relative', () async {
      await writeEntity('nested/entity.json');

      const loader = FileSyncJournalEntityLoader();
      final entity = await loader.load(jsonPath: 'nested/entity.json');

      expect(entity.meta.id, fallbackJournalEntity.meta.id);
    });

    test('rejects path traversal attempts', () async {
      // Create a file outside the documents directory to ensure it's not read.
      final externalDir = await Directory.systemTemp.createTemp(
        'sync_loader_ext',
      );
      final externalFile = File(path.join(externalDir.path, 'escape.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(fallbackJournalEntity.toJson()));

      const loader = FileSyncJournalEntityLoader();

      expect(
        () => loader.load(jsonPath: '../${path.basename(externalFile.path)}'),
        throwsA(isA<FileSystemException>()),
      );

      externalDir.deleteSync(recursive: true);
    });
  });
}
