import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/database/embeddings_init.dart';

import 'load_sqlite_vec.dart';

void main() {
  setUpAll(loadSqliteVecForTests);

  group('embeddingsDbPath', () {
    test('appends embeddings.sqlite to documents path', () {
      expect(
        embeddingsDbPath('/home/user/documents'),
        '/home/user/documents/embeddings.sqlite',
      );
    });

    test('handles trailing slash in documents path', () {
      expect(
        embeddingsDbPath('/home/user/documents/'),
        '/home/user/documents/embeddings.sqlite',
      );
    });

    test('uses the kEmbeddingsDbFilename constant', () {
      const path = '/data';
      expect(
        embeddingsDbPath(path),
        '$path/$kEmbeddingsDbFilename',
      );
    });
  });

  group('kEmbeddingsDbFilename', () {
    test('is embeddings.sqlite', () {
      expect(kEmbeddingsDbFilename, 'embeddings.sqlite');
    });
  });

  group('createEmbeddingsDb', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('embeddings_init_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('creates and opens a database at the expected path', () {
      final db = createEmbeddingsDb(documentsPath: tempDir.path);
      addTeardownDb(db);

      expect(db, isA<EmbeddingsDb>());
      // Verify the database is open by checking count (would throw if closed)
      expect(db.count, 0);
    });

    test('creates the database file on disk', () {
      final db = createEmbeddingsDb(documentsPath: tempDir.path);
      addTeardownDb(db);

      final dbFile = File(embeddingsDbPath(tempDir.path));
      expect(dbFile.existsSync(), isTrue);
    });

    test('returned database is functional', () {
      final db = createEmbeddingsDb(documentsPath: tempDir.path);
      addTeardownDb(db);

      // Verify basic operations work (schema was created)
      expect(db.hasEmbedding('nonexistent'), isFalse);
      expect(db.count, 0);
    });

    test('creates database with correct path property', () {
      final db = createEmbeddingsDb(documentsPath: tempDir.path);
      addTeardownDb(db);

      expect(db.path, embeddingsDbPath(tempDir.path));
    });
  });
}

/// Registers a teardown to close the database after the test.
void addTeardownDb(EmbeddingsDb db) {
  addTearDown(db.close);
}
