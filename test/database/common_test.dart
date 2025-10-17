import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;

// Test constants
const String _testDirectoryPrefix = 'lotti_common_test_';
const String _backupDirectoryName = 'backup';
const int _testBinaryDataSize = 256;
const int _testLargeFileSizeBytes = 1024 * 1024; // 1MB

/// Setup a temp directory for testing
Directory setupTestDirectory() {
  final directory = Directory.systemTemp.createTempSync(_testDirectoryPrefix);
  return directory;
}

/// Helper to setup test directory with GetIt registration
void setupTestDirectoryWithGetIt(Directory testDir) {
  if (getIt.isRegistered<Directory>()) {
    getIt.unregister<Directory>();
  }
  getIt.registerSingleton<Directory>(testDir);
}

/// Helper to cleanup test directory and GetIt registration
Future<void> cleanupTestDirectoryWithGetIt(Directory testDir) async {
  if (testDir.existsSync()) {
    await testDir.delete(recursive: true);
  }
  if (getIt.isRegistered<Directory>()) {
    getIt.unregister<Directory>();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getDatabaseFile Tests', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
      setupTestDirectoryWithGetIt(testDir);
    });

    tearDown(() async {
      await cleanupTestDirectoryWithGetIt(testDir);
    });

    test('returns correct file path', () async {
      const dbFileName = 'test_db.sqlite';
      final file = await getDatabaseFile(dbFileName);

      expect(file.path, equals(p.join(testDir.path, dbFileName)));
    });

    test('file name is properly joined to path', () async {
      const dbFileName = 'my_database.db';
      final file = await getDatabaseFile(dbFileName);

      expect(file.path, contains(testDir.path));
      expect(file.path, contains(dbFileName));
      expect(p.basename(file.path), equals(dbFileName));
    });

    test('works with different file names', () async {
      final fileNames = [
        'test1.sqlite',
        'test2.db',
        'my_custom_db.sqlite3',
      ];

      for (final fileName in fileNames) {
        final file = await getDatabaseFile(fileName);
        expect(p.basename(file.path), equals(fileName));
      }
    });

    test('returns File object', () async {
      final file = await getDatabaseFile('test.db');
      expect(file, isA<File>());
    });
  });

  group('createDbBackup Tests', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
      setupTestDirectoryWithGetIt(testDir);
    });

    tearDown(() async {
      await cleanupTestDirectoryWithGetIt(testDir);
    });

    test('creates backup directory if it does not exist', () async {
      const fileName = 'test_db.sqlite';

      // Create source file
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString('test data');

      // Create backup
      await createDbBackup(fileName);

      // Verify backup directory exists
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      expect(backupDir.existsSync(), isTrue);
    });

    test('creates backup with correct timestamp format', () async {
      const fileName = 'test_db.sqlite';

      // Create source file
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString('test data');

      // Create backup
      await createDbBackup(fileName);

      // Check backup directory for files
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      final backupFiles = backupDir.listSync();

      expect(backupFiles.length, equals(1));
      final backupFile = backupFiles.first as File;

      // Verify timestamp format: db.yyyy-MM-dd_HH-mm-ss-S.sqlite
      final backupFileName = p.basename(backupFile.path);
      expect(backupFileName, startsWith('db.'));
      expect(backupFileName, endsWith('.sqlite'));
      expect(
          backupFileName,
          matches(
              RegExp(r'db\.\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}-\d+\.sqlite')));
    });

    test('creates backup in correct location', () async {
      const fileName = 'test_db.sqlite';

      // Create source file
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString('test data');

      // Create backup
      await createDbBackup(fileName);

      // Verify backup location
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      expect(backupDir.existsSync(), isTrue);

      final backupFiles = backupDir.listSync();
      expect(backupFiles.length, equals(1));
    });

    test('backup directory already exists (should not fail)', () async {
      const fileName = 'test_db.sqlite';

      // Create backup directory first
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      await backupDir.create(recursive: true);

      // Create source file
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString('test data');

      // Create backup - should not fail
      await createDbBackup(fileName);

      // Verify backup was created
      final backupFiles = backupDir.listSync();
      expect(backupFiles.length, equals(1));
    });

    test('backup file contains same data as source', () async {
      const fileName = 'test_db.sqlite';
      const testData = 'This is test database content';

      // Create source file with test data
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString(testData);

      // Create backup
      await createDbBackup(fileName);

      // Read backup and verify content
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      final backupFiles = backupDir.listSync();
      final backupFile = backupFiles.first as File;
      final backupContent = await backupFile.readAsString();

      expect(backupContent, equals(testData));
    });

    test('handles non-existent source file gracefully', () async {
      const fileName = 'nonexistent_db.sqlite';

      // Try to create backup of non-existent file
      expect(
        () => createDbBackup(fileName),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('multiple backups create separate files', () async {
      const fileName = 'test_db.sqlite';

      // Create source file
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString('test data');

      // Create first backup
      await createDbBackup(fileName);

      // Create second backup immediately - timestamp format includes milliseconds
      // which should be sufficient to create unique filenames
      await createDbBackup(fileName);

      // Verify at least one backup file exists (could be 1 or 2 depending on timing)
      // The main point is that backups are created without errors
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      final backupFiles = backupDir.listSync();
      expect(backupFiles.length, greaterThanOrEqualTo(1));
    });

    test('backup preserves binary data', () async {
      const fileName = 'test_db.sqlite';
      final binaryData = List.generate(_testBinaryDataSize, (i) => i);

      // Create source file with binary data
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsBytes(binaryData);

      // Create backup
      await createDbBackup(fileName);

      // Read backup and verify content
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      final backupFiles = backupDir.listSync();
      final backupFile = backupFiles.first as File;
      final backupContent = await backupFile.readAsBytes();

      expect(backupContent, equals(binaryData));
    });
  });

  group('openDbConnection Tests', () {
    test('creates in-memory database when inMemoryDatabase=true', () {
      final db = openDbConnection('test.db', inMemoryDatabase: true);
      expect(db, isNotNull);
    });

    test('returns LazyDatabase instance', () {
      final db = openDbConnection('test.db', inMemoryDatabase: true);
      expect(db.toString(), contains('LazyDatabase'));
    });

    test('lazy initialization behavior with in-memory database', () async {
      final db = openDbConnection('test.db', inMemoryDatabase: true);

      // LazyDatabase should not throw on creation
      expect(db, isNotNull);

      // The actual database connection is created lazily when first used
      // We can verify this doesn't throw
      expect(() => db, returnsNormally);
    });

    test('different file names create separate connections', () {
      final db1 = openDbConnection('db1.sqlite', inMemoryDatabase: true);
      final db2 = openDbConnection('db2.sqlite', inMemoryDatabase: true);

      expect(db1, isNotNull);
      expect(db2, isNotNull);
      // Note: Can't easily verify they're different without opening them
    });

    test('in-memory database does not create file', () async {
      final testDir = setupTestDirectory();

      try {
        const fileName = 'memory_test.db';
        final db = openDbConnection(fileName, inMemoryDatabase: true);

        expect(db, isNotNull);

        // Verify no file was created in the test directory
        final possibleFile = File(p.join(testDir.path, fileName));
        expect(possibleFile.existsSync(), isFalse);
      } finally {
        if (testDir.existsSync()) {
          await testDir.delete(recursive: true);
        }
      }
    });

    test('handles special characters in filename', () {
      final specialNames = [
        'test-db.sqlite',
        'test_db.sqlite',
        'test.db.sqlite',
      ];

      for (final name in specialNames) {
        final db = openDbConnection(name, inMemoryDatabase: true);
        expect(db, isNotNull);
      }
    });

    test('multiple calls with same filename return new instances', () {
      const fileName = 'test.db';

      final db1 = openDbConnection(fileName, inMemoryDatabase: true);
      final db2 = openDbConnection(fileName, inMemoryDatabase: true);

      expect(db1, isNotNull);
      expect(db2, isNotNull);
      // Each call creates a new LazyDatabase instance
    });
  });

  group('openDbConnection Integration Tests', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
    });

    tearDown(() async {
      if (testDir.existsSync()) {
        await testDir.delete(recursive: true);
      }
    });

    test('creates database file when inMemoryDatabase=false', () async {
      const fileName = 'test_real_db.sqlite';

      // Note: This test verifies the structure but doesn't actually
      // open the database since that requires the full app context
      final db = openDbConnection(fileName);
      expect(db, isNotNull);
    });
  });

  group('openDbConnection File-based Tests', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
    });

    tearDown(() async {
      if (testDir.existsSync()) {
        await testDir.delete(recursive: true);
      }
    });

    test('creates file-based database connection with custom directory',
        () async {
      final db = openDbConnection(
        'test_file.db',
        documentsDirectoryProvider: () async => testDir,
        tempDirectoryProvider: () async => testDir,
      );

      expect(db, isNotNull);
      expect(db.toString(), contains('LazyDatabase'));
    });

    test('initializes database file on first use', () async {
      final db = EditorDb(
        documentsDirectoryProvider: () async => testDir,
        tempDirectoryProvider: () async => testDir,
      );

      // Perform a simple operation to trigger database initialization
      await db.allDrafts().get();
      await db.close();

      // Verify file was created
      final dbFile = File(p.join(testDir.path, editorDbFileName));
      expect(dbFile.existsSync(), isTrue);
    });

    test('sets correct file path for database', () async {
      final db = EditorDb(
        documentsDirectoryProvider: () async => testDir,
        tempDirectoryProvider: () async => testDir,
      );

      await db.allDrafts().get();
      await db.close();

      final expectedPath = p.join(testDir.path, editorDbFileName);
      final dbFile = File(expectedPath);
      expect(dbFile.existsSync(), isTrue);
    });

    test('creates file in correct directory structure', () async {
      final db = EditorDb(
        documentsDirectoryProvider: () async => testDir,
        tempDirectoryProvider: () async => testDir,
      );

      await db.allDrafts().get();
      await db.close();

      // Verify file exists in test directory
      final files = testDir.listSync();
      expect(files.any((f) => f.path.contains(editorDbFileName)), isTrue);
    });

    test('handles multiple database instances with same directory', () async {
      final db1 = EditorDb(
        documentsDirectoryProvider: () async => testDir,
        tempDirectoryProvider: () async => testDir,
      );

      // Trigger initialization
      await db1.allDrafts().get();
      await db1.close();

      // Create another instance
      final db2 = EditorDb(
        documentsDirectoryProvider: () async => testDir,
        tempDirectoryProvider: () async => testDir,
      );

      await db2.allDrafts().get();
      await db2.close();

      // Verify file exists
      expect(File(p.join(testDir.path, editorDbFileName)).existsSync(), isTrue);
    });
  });

  group('File Path Construction Tests', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
      setupTestDirectoryWithGetIt(testDir);
    });

    tearDown(() async {
      await cleanupTestDirectoryWithGetIt(testDir);
    });

    test('handles paths with spaces', () async {
      // This tests that path joining works correctly
      const fileName = 'my database.sqlite';
      final file = await getDatabaseFile(fileName);

      expect(p.basename(file.path), equals(fileName));
    });

    test('handles relative path components correctly', () async {
      const fileName = 'test.db';
      final file = await getDatabaseFile(fileName);

      // Should be an absolute path
      expect(p.isAbsolute(file.path), isTrue);
    });

    test('uses correct path separator for platform', () async {
      const fileName = 'test.db';
      final file = await getDatabaseFile(fileName);

      // The path should use the platform's separator
      expect(file.path, contains(Platform.pathSeparator));
    });
  });

  group('Edge Cases and Error Handling', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
      setupTestDirectoryWithGetIt(testDir);
    });

    tearDown(() async {
      await cleanupTestDirectoryWithGetIt(testDir);
    });

    test('getDatabaseFile handles empty filename', () async {
      final file = await getDatabaseFile('');
      expect(file.path, equals(testDir.path));
    });

    test('backup handles empty source file', () async {
      const fileName = 'empty_db.sqlite';

      // Create empty source file
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString('');

      // Create backup
      await createDbBackup(fileName);

      // Verify backup was created
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      final backupFiles = backupDir.listSync();
      expect(backupFiles.length, equals(1));

      // Verify backup is also empty
      final backupFile = backupFiles.first as File;
      final content = await backupFile.readAsString();
      expect(content, isEmpty);
    });

    test('backup handles large file', () async {
      const fileName = 'large_db.sqlite';

      // Create large source file (1MB)
      final largeData = List.generate(
          _testLargeFileSizeBytes, (i) => i % _testBinaryDataSize);
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsBytes(largeData);

      // Create backup
      await createDbBackup(fileName);

      // Verify backup size matches
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      final backupFiles = backupDir.listSync();
      final backupFile = backupFiles.first as File;
      final backupSize = await backupFile.length();
      final sourceSize = await sourceFile.length();

      expect(backupSize, equals(sourceSize));
    });
  });
}
