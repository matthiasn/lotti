import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

/// Constants for database backup operations
const String _backupDirectoryName = 'backup';
const String _backupFilePrefix = 'db.';
const String _backupFileExtension = '.sqlite';
const String _backupTimestampFormat = 'yyyy-MM-dd_HH-mm-ss-S';

/// Retrieves the database file for the given filename.
///
/// Returns a [File] object pointing to the database file in the
/// documents directory. The file may not exist yet.
///
/// Example:
/// ```dart
/// final dbFile = await getDatabaseFile('my_database.sqlite');
/// ```
Future<File> getDatabaseFile(String dbFileName) async {
  final dbFolder = getDocumentsDirectory();
  return File(p.join(dbFolder.path, dbFileName));
}

/// Creates a timestamped backup of the database file.
///
/// Creates a backup directory if it doesn't exist and copies the database
/// file with a timestamp in the filename. The backup format is:
/// `db.yyyy-MM-dd_HH-mm-ss-S.sqlite`
///
/// Throws [FileSystemException] if the source file doesn't exist or
/// if there are permission issues.
///
/// Example:
/// ```dart
/// await createDbBackup('my_database.sqlite');
/// // Creates: backup/db.2025-10-17_14-30-45-123.sqlite
/// ```
Future<void> createDbBackup(String fileName) async {
  final file = await getDatabaseFile(fileName);
  final ts = DateFormat(_backupTimestampFormat).format(DateTime.now());
  final backupDir =
      await Directory(p.join(file.parent.path, _backupDirectoryName))
          .create(recursive: true);
  await file.copy(
      p.join(backupDir.path, '$_backupFilePrefix$ts$_backupFileExtension'));
}

/// Configures WAL mode and recommended pragmas on a freshly opened database.
///
/// Applied via the `setup` callback so that every connection (including
/// read-pool isolates) inherits these settings.
void _setupDatabase(Database database) {
  database
    ..execute('PRAGMA journal_mode = WAL;')
    ..execute('PRAGMA busy_timeout = 5000;')
    ..execute('PRAGMA synchronous = NORMAL;');
}

/// Opens a database connection with lazy initialization.
///
/// Creates a [LazyDatabase] that initializes the actual database connection
/// only when first accessed. Supports both in-memory and file-based databases.
///
/// Parameters:
/// - [fileName]: Name of the database file
/// - [inMemoryDatabase]: If true, creates an in-memory database (default: false)
/// - [background]: If true (default), runs the database in a background
///   isolate via [NativeDatabase.createInBackground]. Set to false when
///   opening from an actor isolate to avoid nested isolates.
/// - [readPool]: Number of read-only isolates for offloading heavy reads
///   (default: 0). Only effective when [background] is true.
/// - [documentsDirectoryProvider]: Optional provider for documents directory (for testing)
/// - [tempDirectoryProvider]: Optional provider for temp directory (for testing)
///
/// Returns a [LazyDatabase] instance that will initialize on first use.
///
/// Example:
/// ```dart
/// // File-based database
/// final db = openDbConnection('app.sqlite');
///
/// // In-memory database (for testing)
/// final testDb = openDbConnection('test.sqlite', inMemoryDatabase: true);
/// ```
LazyDatabase openDbConnection(
  String fileName, {
  bool inMemoryDatabase = false,
  bool background = true,
  int readPool = 0,
  Future<Directory> Function()? documentsDirectoryProvider,
  Future<Directory> Function()? tempDirectoryProvider,
}) {
  return LazyDatabase(() async {
    if (inMemoryDatabase) {
      return NativeDatabase.memory();
    }

    final dbFolder =
        await (documentsDirectoryProvider?.call() ?? findDocumentsDirectory());
    final file = File(p.join(dbFolder.path, fileName));
    // Ensure parent directory exists before opening to avoid SQLITE_CANTOPEN (14)
    try {
      await file.parent.create(recursive: true);
    } catch (e, st) {
      // Best-effort; if this fails, sqlite open will also fail and be surfaced upstream
      DevLogger.warning(
        name: 'Database',
        message:
            'Failed to create DB directory at ${file.parent.path}: $e\n$st',
      );
    }

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    try {
      sqlite3.tempDirectory =
          (await (tempDirectoryProvider?.call() ?? getTemporaryDirectory()))
              .path;
    } catch (e) {
      // If temp directory resolution fails, keep default; sqlite will use OS default tmp
      DevLogger.warning(
        name: 'Database',
        message: 'Failed to resolve temp directory, using sqlite default: $e',
      );
    }

    if (background) {
      return NativeDatabase.createInBackground(
        file,
        setup: _setupDatabase,
        readPool: readPool,
      );
    } else {
      return NativeDatabase(file, setup: _setupDatabase);
    }
  });
}
