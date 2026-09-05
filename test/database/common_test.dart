import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

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

/// A database whose `PRAGMA optimize` never completes, standing in for one
/// waiting on a lock held elsewhere.
class _HangingOptimizeDb extends Fake implements GeneratedDatabase {
  bool closed = false;

  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) =>
      Completer<void>().future;

  @override
  Future<void> close() async {
    closed = true;
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

    /// A real WAL-mode database with one row checkpointed into the main file
    /// and, while the returned connection stays open, a second row that only
    /// exists in the WAL.
    Database seedWalDatabase(String fileName) {
      final source = sqlite3.open(p.join(testDir.path, fileName));
      addTearDown(source.close);
      source
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('CREATE TABLE rows (id INTEGER PRIMARY KEY, label TEXT)')
        ..execute("INSERT INTO rows (label) VALUES ('checkpointed')")
        ..execute('PRAGMA wal_checkpoint(TRUNCATE)')
        ..execute("INSERT INTO rows (label) VALUES ('still in the wal')");
      return source;
    }

    List<String> labelsIn(File backup) {
      final copy = sqlite3.open(backup.path);
      addTearDown(copy.close);
      return copy
          .select('SELECT label FROM rows ORDER BY id')
          .map((row) => row['label'] as String)
          .toList();
    }

    test('the backup holds commits that are still in the WAL', () async {
      const fileName = 'test_db.sqlite';
      seedWalDatabase(fileName);
      final wal = File(p.join(testDir.path, '$fileName-wal'));
      expect(wal.lengthSync(), greaterThan(0), reason: 'row must be in WAL');

      final backup = await createDbBackup(fileName);

      // A plain copy of the main file would only carry 'checkpointed'.
      expect(labelsIn(backup), ['checkpointed', 'still in the wal']);
      expect(File('${backup.path}-wal').existsSync(), isFalse);
    });

    test('backups are named after their source and the clock', () async {
      seedWalDatabase('agent.sqlite');

      final backup = await withClock(
        Clock.fixed(DateTime(2026, 9, 5, 10, 30, 15)),
        () => createDbBackup('agent.sqlite'),
      );

      expect(backup.parent.path, p.join(testDir.path, _backupDirectoryName));
      expect(
        p.basename(backup.path),
        matches(RegExp(r'^agent\.2026-09-05_10-30-15-\d+\.sqlite$')),
      );
    });

    test('successive backups never collide', () async {
      const fileName = 'test_db.sqlite';
      seedWalDatabase(fileName);

      final first = await withClock(
        Clock.fixed(DateTime(2026, 9, 5, 10, 30, 15)),
        () => createDbBackup(fileName),
      );
      final second = await withClock(
        Clock.fixed(DateTime(2026, 9, 5, 10, 30, 16)),
        () => createDbBackup(fileName),
      );

      expect(first.path, isNot(second.path));
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      expect(backupDir.listSync(), hasLength(2));
    });

    test('two backups in the same instant get distinct files', () async {
      const fileName = 'test_db.sqlite';
      seedWalDatabase(fileName);
      final sameInstant = Clock.fixed(DateTime(2026, 9, 5, 10, 30, 15));

      final first = await withClock(
        sameInstant,
        () => createDbBackup(fileName),
      );
      final second = await withClock(
        sameInstant,
        () => createDbBackup(fileName),
      );

      expect(first.path, isNot(second.path));
      expect(p.basename(second.path), endsWith('-2.sqlite'));
      // Both are real snapshots — the second did not overwrite the first.
      expect(labelsIn(first), ['checkpointed', 'still in the wal']);
      expect(labelsIn(second), ['checkpointed', 'still in the wal']);
    });

    test(
      'a failure that is not an unreadable source propagates instead of '
      'being papered over with a raw copy',
      () async {
        const fileName = 'test_db.sqlite';
        seedWalDatabase(fileName);
        // Occupy the exact target with a directory so VACUUM INTO cannot
        // write there: the source is fine, the backup is what failed.
        final backupDir = Directory(p.join(testDir.path, _backupDirectoryName))
          ..createSync();
        Directory(
          p.join(backupDir.path, 'test_db.2026-09-05_10-30-15-000.sqlite'),
        ).createSync();

        await expectLater(
          withClock(
            Clock.fixed(DateTime(2026, 9, 5, 10, 30, 15)),
            () => createDbBackup(fileName),
          ),
          throwsA(isA<SqliteException>()),
        );

        expect(
          backupDir.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.sqlite'),
          ),
          isEmpty,
          reason: 'no raw copy may stand in for a failed snapshot',
        );
      },
    );

    test(
      'keeps only the newest snapshots of a database and takes a pruned '
      "raw copy's WAL with it",
      () async {
        const fileName = 'test_db.sqlite';
        seedWalDatabase(fileName);
        final backupDir = Directory(p.join(testDir.path, _backupDirectoryName))
          ..createSync();
        // A legacy raw-copy snapshot from before VACUUM INTO, with its WAL:
        // it sorts oldest and must be the first to go, sidecar included.
        File(
          p.join(backupDir.path, 'test_db.2026-01-01_00-00-00-000.sqlite'),
        ).writeAsStringSync('old');
        File(
          p.join(backupDir.path, 'test_db.2026-01-01_00-00-00-000.sqlite-wal'),
        ).writeAsStringSync('old wal');

        final kept = <String>[];
        for (final second in [10, 11, 12]) {
          final backup = await withClock(
            Clock.fixed(DateTime(2026, 9, 5, 10, 30, second)),
            () => createDbBackup(fileName),
          );
          kept.add(p.basename(backup.path));
        }

        final remaining =
            backupDir
                .listSync()
                .map((entity) => p.basename(entity.path))
                .toList()
              ..sort();
        expect(remaining, kept..sort());
        expect(remaining, hasLength(backupsKeptPerDatabase));
      },
    );

    test(
      'a snapshot taken after the clock moved backwards still counts as the '
      'newest, so three copies remain',
      () async {
        const fileName = 'test_db.sqlite';
        seedWalDatabase(fileName);
        for (final second in [10, 11, 12]) {
          await withClock(
            Clock.fixed(DateTime(2026, 9, 5, 10, 30, second)),
            () => createDbBackup(fileName),
          );
        }

        // The device clock was corrected backwards: the new file sorts
        // below all three existing ones.
        final latest = await withClock(
          Clock.fixed(DateTime(2026, 9, 5, 10, 30, 5)),
          () => createDbBackup(fileName),
        );

        final remaining = Directory(
          p.join(testDir.path, _backupDirectoryName),
        ).listSync().map((entity) => p.basename(entity.path)).toList()..sort();
        expect(remaining, hasLength(backupsKeptPerDatabase));
        expect(remaining, contains(p.basename(latest.path)));
        expect(
          remaining,
          isNot(contains('test_db.2026-09-05_10-30-10-000.sqlite')),
        );
      },
    );

    test('prunes each database separately', () async {
      seedWalDatabase('db.sqlite');
      seedWalDatabase('agent.sqlite');
      for (final second in [10, 11, 12, 13]) {
        await withClock(
          Clock.fixed(DateTime(2026, 9, 5, 10, 30, second)),
          () => createDbBackup('db.sqlite'),
        );
      }
      await withClock(
        Clock.fixed(DateTime(2026, 9, 5, 10, 30, 10)),
        () => createDbBackup('agent.sqlite'),
      );

      final names = Directory(
        p.join(testDir.path, _backupDirectoryName),
      ).listSync().map((entity) => p.basename(entity.path)).toList();
      expect(names.where((n) => n.startsWith('db.')), hasLength(3));
      expect(
        names.where((n) => n.startsWith('db.')),
        isNot(contains('db.2026-09-05_10-30-10-000.sqlite')),
      );
      expect(names.where((n) => n.startsWith('agent.')), hasLength(1));
    });

    test('a failed snapshot leaves the existing backups untouched', () async {
      const fileName = 'test_db.sqlite';
      seedWalDatabase(fileName);
      final earlier = await withClock(
        Clock.fixed(DateTime(2026, 9, 5, 10, 30, 10)),
        () => createDbBackup(fileName),
      );
      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      Directory(
        p.join(backupDir.path, 'test_db.2026-09-05_10-30-15-000.sqlite'),
      ).createSync();

      await expectLater(
        withClock(
          Clock.fixed(DateTime(2026, 9, 5, 10, 30, 15)),
          () => createDbBackup(fileName),
        ),
        throwsA(isA<SqliteException>()),
      );

      expect(earlier.existsSync(), isTrue);
    });

    test('throws when the source file does not exist', () async {
      await expectLater(
        createDbBackup('missing.sqlite'),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        Directory(p.join(testDir.path, _backupDirectoryName)).existsSync(),
        isFalse,
      );
    });

    test(
      'a source SQLite cannot read is copied byte for byte with its WAL',
      () async {
        const fileName = 'broken.sqlite';
        final garbage = List<int>.generate(_testBinaryDataSize, (i) => i);
        final walGarbage = List<int>.generate(
          _testBinaryDataSize,
          (i) => 255 - i,
        );
        File(p.join(testDir.path, fileName)).writeAsBytesSync(garbage);
        File(
          p.join(testDir.path, '$fileName-wal'),
        ).writeAsBytesSync(walGarbage);

        final backup = await createDbBackup(fileName);

        expect(backup.readAsBytesSync(), garbage);
        expect(File('${backup.path}-wal').readAsBytesSync(), walGarbage);
      },
    );

    test('backs up from an explicit documents directory', () async {
      final otherWorld = Directory(p.join(testDir.path, 'other-world'))
        ..createSync();
      final source = sqlite3.open(p.join(otherWorld.path, 'db.sqlite'));
      addTearDown(source.close);
      source
        ..execute('CREATE TABLE rows (id INTEGER PRIMARY KEY, label TEXT)')
        ..execute("INSERT INTO rows (label) VALUES ('elsewhere')");

      final backup = await createDbBackup(
        'db.sqlite',
        documentsDirectoryProvider: () async => otherWorld,
      );

      expect(p.isWithin(otherWorld.path, backup.path), isTrue);
      expect(labelsIn(backup), ['elsewhere']);
    });
  });

  group('backupBeforeMigration', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
      setupTestDirectoryWithGetIt(testDir);
      DevLogger.capturedLogs.clear();
    });

    tearDown(() async {
      await cleanupTestDirectoryWithGetIt(testDir);
    });

    test('writes the backup and logs where it went', () async {
      final source = sqlite3.open(p.join(testDir.path, 'sync.sqlite'));
      addTearDown(source.close);
      source.execute('CREATE TABLE rows (id INTEGER PRIMARY KEY)');

      await backupBeforeMigration('sync.sqlite', from: 3, to: 4);

      final backups = Directory(
        p.join(testDir.path, _backupDirectoryName),
      ).listSync();
      expect(backups, hasLength(1));
      expect(
        DevLogger.capturedLogs.any(
          (line) =>
              line.contains('Backed up sync.sqlite') &&
              line.contains('before migrating v3 to v4'),
        ),
        isTrue,
        reason: DevLogger.capturedLogs.join('\n'),
      );
    });

    test(
      'a failed backup is logged and never stops the migration',
      () async {
        // No such file: the backup throws, the migration must still run.
        await expectLater(
          backupBeforeMigration('missing.sqlite', from: 3, to: 4),
          completes,
        );

        expect(
          Directory(p.join(testDir.path, _backupDirectoryName)).existsSync(),
          isFalse,
        );
        expect(
          DevLogger.capturedLogs.any(
            (line) => line.contains(
              'Failed to back up missing.sqlite before migrating v3 to v4',
            ),
          ),
          isTrue,
          reason: DevLogger.capturedLogs.join('\n'),
        );
      },
    );
  });

  group('openDbConnection Tests', () {
    // Constructor smoke tests were removed: behavioral coverage for
    // openDbConnection (WAL mode, pragmas, directory creation) lives in
    // open_db_connection_test.dart.
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

  group('openDbConnection profile-root fallback', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
      setupTestDirectoryWithGetIt(testDir);
      // Any path_provider hit means a database bypassed the registered
      // profile root — make that a hard failure, not a silent fallback.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              throw PlatformException(
                code: 'forbidden',
                message:
                    'path_provider must not be consulted '
                    'when a profile root is registered',
              );
            },
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      await cleanupTestDirectoryWithGetIt(testDir);
    });

    test('EditorDb without provider opens under the registered root', () async {
      final db = EditorDb();
      await db.allDrafts().get();
      await db.close();

      expect(File(p.join(testDir.path, editorDbFileName)).existsSync(), isTrue);
    });

    test('Fts5Db without provider opens under the registered root', () async {
      final db = Fts5Db();
      await db.customSelect('SELECT 1').get();
      await db.close();

      expect(File(p.join(testDir.path, fts5DbFileName)).existsSync(), isTrue);
    });

    test(
      'AiConfigDb without provider opens under the registered root',
      () async {
        final db = AiConfigDb();
        await db.customSelect('SELECT 1').get();
        await db.close();

        expect(
          File(p.join(testDir.path, aiConfigDbFileName)).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'explicit documentsDirectoryProvider overrides the registered root',
      () async {
        final otherDir = setupTestDirectory();
        try {
          final db = Fts5Db(
            documentsDirectoryProvider: () async => otherDir,
            tempDirectoryProvider: () async => otherDir,
          );
          await db.customSelect('SELECT 1').get();
          await db.close();

          expect(
            File(p.join(otherDir.path, fts5DbFileName)).existsSync(),
            isTrue,
          );
          expect(
            File(p.join(testDir.path, fts5DbFileName)).existsSync(),
            isFalse,
          );
        } finally {
          if (otherDir.existsSync()) {
            await otherDir.delete(recursive: true);
          }
        }
      },
    );
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

  group('DevLogger error handling', () {
    late Directory testDir;

    setUp(() {
      testDir = setupTestDirectory();
      DevLogger.capturedLogs.clear();
    });

    tearDown(() async {
      if (testDir.existsSync()) {
        await testDir.delete(recursive: true);
      }
    });

    test('logs warning when temp directory resolution fails', () async {
      final db = EditorDb(
        documentsDirectoryProvider: () async => testDir,
        tempDirectoryProvider: () async => throw Exception('Temp dir failed'),
      );

      // Trigger initialization
      await db.allDrafts().get();
      await db.close();

      // Verify DevLogger.warning was called
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('Database') &&
              log.contains('Failed to resolve temp directory') &&
              log.contains('Temp dir failed'),
        ),
        isTrue,
        reason: 'Temp directory resolution failure should be logged',
      );
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

    test('an empty source file backs up as a valid empty database', () async {
      const fileName = 'empty_db.sqlite';
      // SQLite treats a zero-length file as an empty database, so the
      // snapshot is a real (header-only) database rather than an empty file.
      final sourceFile = File(p.join(testDir.path, fileName));
      await sourceFile.writeAsString('');

      final backup = await createDbBackup(fileName);

      final backupDir = Directory(p.join(testDir.path, _backupDirectoryName));
      expect(backupDir.listSync(), hasLength(1));
      final snapshot = sqlite3.open(backup.path);
      addTearDown(snapshot.close);
      expect(snapshot.select('SELECT name FROM sqlite_master'), isEmpty);
    });

    test('a large source SQLite cannot read is copied in full', () async {
      const fileName = 'large_db.sqlite';

      // Create large source file (1MB)
      final largeData = List.generate(
        _testLargeFileSizeBytes,
        (i) => i % _testBinaryDataSize,
      );
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

  group('recoverDatabaseIfUnreadable', () {
    late Directory testDirectory;

    setUp(() {
      testDirectory = setupTestDirectory();
      setupTestDirectoryWithGetIt(testDirectory);
      DevLogger.capturedLogs.clear();
    });

    tearDown(() => cleanupTestDirectoryWithGetIt(testDirectory));

    /// A real SQLite file holding one row, so a restore can be told apart
    /// from an empty file by its contents.
    void writeDatabase(String path, String marker) {
      sqlite3.open(path)
        ..execute('CREATE TABLE t (v TEXT)')
        ..execute("INSERT INTO t (v) VALUES ('$marker')")
        ..close();
    }

    String markerOf(String path) {
      final db = sqlite3.open(path);
      try {
        return db.select('SELECT v FROM t').single['v'] as String;
      } finally {
        db.close();
      }
    }

    File backupOf(String stem, String timestamp, String marker) {
      final dir = Directory(p.join(testDirectory.path, _backupDirectoryName))
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, '$stem.$timestamp.sqlite'));
      writeDatabase(file.path, marker);
      return file;
    }

    test('a readable database is left exactly as it is', () async {
      final file = File(p.join(testDirectory.path, 'db.sqlite'));
      writeDatabase(file.path, 'live');
      backupOf('db', '2026-09-05_10-00-00-000', 'backup');

      await recoverDatabaseIfUnreadable(file);

      expect(markerOf(file.path), 'live');
      expect(
        Directory(
          testDirectory.path,
        ).listSync().whereType<File>().map((f) => p.basename(f.path)),
        ['db.sqlite'],
        reason: 'nothing should have been moved aside',
      );
    });

    test('a corrupt database is replaced by the newest backup', () async {
      final file = File(p.join(testDirectory.path, 'db.sqlite'))
        ..writeAsStringSync('this is not a database');
      File('${file.path}-wal').writeAsStringSync('stale wal');
      backupOf('db', '2026-09-05_09-00-00-000', 'older');
      backupOf('db', '2026-09-05_11-00-00-000', 'newest');

      await withClock(
        Clock.fixed(DateTime(2026, 9, 5, 12)),
        () => recoverDatabaseIfUnreadable(file),
      );

      expect(markerOf(file.path), 'newest');
      // The damaged file is kept: it holds whatever the backup does not.
      final kept = Directory(testDirectory.path)
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where(
            (name) =>
                name.contains('.corrupt-') &&
                !name.endsWith('-wal') &&
                !name.endsWith('-shm'),
          )
          .toList();
      expect(kept, hasLength(1));
      // A WAL belonging to the replaced file would be replayed into the
      // restored one, so it leaves the live path — with the corrupt file
      // rather than into the bin, because it holds the commits the snapshot
      // is missing.
      expect(File('${file.path}-wal').existsSync(), isFalse);
      final corrupt = kept.single;
      expect(
        File(p.join(testDirectory.path, '$corrupt-wal')).readAsStringSync(),
        'stale wal',
      );
    });

    test(
      'falls back to an older backup when the newest is damaged too',
      () async {
        final file = File(p.join(testDirectory.path, 'db.sqlite'))
          ..writeAsStringSync('not a database');
        backupOf('db', '2026-09-05_09-00-00-000', 'older');
        backupOf(
          'db',
          '2026-09-05_11-00-00-000',
          'newest',
        ).writeAsStringSync('also not a database');

        await withClock(
          Clock.fixed(DateTime(2026, 9, 5, 12)),
          () => recoverDatabaseIfUnreadable(file),
        );

        expect(markerOf(file.path), 'older');
      },
    );

    test('keeps the damaged database when the restore copy fails', () async {
      final file = File(p.join(testDirectory.path, 'db.sqlite'))
        ..writeAsStringSync('not a database');
      final backup = backupOf('db', '2026-09-05_11-00-00-000', 'backup');
      // A scratch path that already exists as a *directory* makes the copy
      // fail the way a full disk would, after the snapshot passed its probe.
      Directory('${file.path}.restore-tmp').createSync();

      await withClock(
        Clock.fixed(DateTime(2026, 9, 5, 12)),
        () => recoverDatabaseIfUnreadable(file),
      );

      // Nothing may be left half-done: an empty live path would be filled
      // with a fresh blank database by the open that follows, and the
      // corruption would never surface.
      expect(file.readAsStringSync(), 'not a database');
      expect(backup.existsSync(), isTrue);
    });

    test('leaves the file alone when there is no backup to restore', () async {
      final file = File(p.join(testDirectory.path, 'db.sqlite'))
        ..writeAsStringSync('not a database');

      await recoverDatabaseIfUnreadable(file);

      expect(file.readAsStringSync(), 'not a database');
      expect(
        DevLogger.capturedLogs.any((line) => line.contains('No usable backup')),
        isTrue,
        reason: DevLogger.capturedLogs.join('\n'),
      );
    });

    test('a missing file is not a corruption verdict', () async {
      final file = File(p.join(testDirectory.path, 'absent.sqlite'));
      backupOf('absent', '2026-09-05_11-00-00-000', 'backup');

      await recoverDatabaseIfUnreadable(file);

      expect(
        file.existsSync(),
        isFalse,
        reason: 'a first launch must not be handed an old backup',
      );
    });
  });

  group('optimizeAndClose', () {
    test('closes the database even when optimize never finishes', () async {
      final db = _HangingOptimizeDb();

      await optimizeAndClose(db, timeout: const Duration(milliseconds: 20));

      // The disposer closes on shutdown precisely so no native handle
      // outlives the engine; an optimize stuck on a lock must not take the
      // close down with it.
      expect(db.closed, isTrue);
    });

    test('refreshes planner statistics and closes the database', () async {
      final directory = setupTestDirectory();
      addTearDown(() => directory.deleteSync(recursive: true));
      final db = AiConfigDb(
        documentsDirectoryProvider: () async => directory,
        tempDirectoryProvider: () async => directory,
      );
      // Give the planner something worth analysing, then a query that makes
      // the stale-statistics estimate worth refreshing.
      await db.customStatement(
        'CREATE TABLE t (id INTEGER PRIMARY KEY, k TEXT)',
      );
      await db.customStatement('CREATE INDEX i ON t(k)');
      for (var i = 0; i < 400; i++) {
        await db.customStatement(
          "INSERT INTO t (k) VALUES ('k' || ${i % 5})",
        );
      }
      await db.customSelect("SELECT * FROM t WHERE k = 'k3'").get();

      await optimizeAndClose(db);

      final raw = sqlite3.open(p.join(directory.path, aiConfigDbFileName));
      addTearDown(raw.close);
      expect(
        raw
            .select(
              "SELECT name FROM sqlite_master WHERE name = 'sqlite_stat1'",
            )
            .length,
        1,
        reason: 'PRAGMA optimize should have left statistics behind',
      );
    });
  });
}
