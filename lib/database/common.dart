import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/slow_query_logging.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Constants for database backup operations
const String _backupDirectoryName = 'backup';
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

/// Creates a timestamped, transactionally consistent backup of a database.
///
/// The snapshot is taken with `VACUUM INTO` on a private connection, so it
/// holds every committed transaction — including those still sitting in the
/// WAL, which a plain copy of the main file would miss — and arrives
/// compacted. It runs on its own isolate because the sqlite3 bindings are
/// synchronous and a large journal would otherwise stall the caller.
///
/// When the source cannot be read as a database (the corrupt file a user is
/// about to reset, for one) the main file and its WAL are copied byte for
/// byte instead and a warning is logged, so a reset is never blocked on a
/// backup of something SQLite cannot open.
///
/// Backups are named after their source: `backup/<stem>.<timestamp>.sqlite`,
/// so `db.sqlite` becomes `backup/db.2025-10-17_14-30-45-123.sqlite` and
/// `agent.sqlite` becomes `backup/agent.….sqlite`. Returns the backup file.
///
/// [documentsDirectoryProvider] names the directory the database lives in;
/// it defaults to the active profile root, which is wrong for a database
/// opened in another world, so a database backing itself up passes its own.
///
/// Throws [FileSystemException] if the source file does not exist.
Future<File> createDbBackup(
  String fileName, {
  Future<Directory> Function()? documentsDirectoryProvider,
}) async {
  final directory = documentsDirectoryProvider == null
      ? getDocumentsDirectory()
      : await documentsDirectoryProvider();
  final file = File(p.join(directory.path, fileName));
  if (!file.existsSync()) {
    throw FileSystemException('Database file does not exist', file.path);
  }
  // clock.now() so tests can drive the backup timestamp deterministically
  // via withClock.
  final ts = DateFormat(_backupTimestampFormat).format(clock.now());
  final backupDir = await Directory(
    p.join(file.parent.path, _backupDirectoryName),
  ).create(recursive: true);
  final stem = p.basenameWithoutExtension(fileName);
  final target = File(
    p.join(backupDir.path, '$stem.$ts$_backupFileExtension'),
  );

  // Stash the WAL before touching the file: SQLite discards a `-wal` it
  // finds beside a file it cannot read as a database, and that WAL is the
  // most valuable thing a raw copy of a corrupt store can carry.
  final wal = File('${file.path}-wal');
  final walStash = wal.existsSync()
      ? await wal.copy('${target.path}-wal.stash')
      : null;
  try {
    final sourcePath = file.path;
    final targetPath = target.path;
    await Isolate.run(() => _vacuumInto(sourcePath, targetPath));
    await walStash?.delete();
  } on SqliteException catch (e) {
    DevLogger.warning(
      name: 'Database',
      message:
          'VACUUM INTO failed for $fileName ($e); '
          'falling back to a raw copy of the main file and its WAL',
    );
    if (target.existsSync()) {
      await target.delete();
    }
    await file.copy(target.path);
    await walStash?.rename('${target.path}-wal');
  }
  return target;
}

/// Runs `VACUUM INTO` from a throwaway connection so the snapshot is taken
/// under SQLite's own read transaction, independent of whatever the app's
/// connection is doing (a migration in progress, for one).
void _vacuumInto(String sourcePath, String targetPath) {
  final database = sqlite3.open(sourcePath);
  try {
    database.execute('VACUUM INTO ?', [targetPath]);
  } finally {
    database.close();
  }
}

/// Backs up [fileName] before a schema migration from [from] to [to].
///
/// A failed backup is logged, never fatal: refusing to migrate would leave
/// the app unable to open at all, which is worse than migrating without a
/// safety copy. Pass the database's actual file name — an overridden one
/// included — so the copy is of the file being migrated.
Future<void> backupBeforeMigration(
  String fileName, {
  required int from,
  required int to,
  Future<Directory> Function()? documentsDirectoryProvider,
}) async {
  try {
    final backup = await createDbBackup(
      fileName,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    DevLogger.log(
      name: 'Database',
      message:
          'Backed up $fileName to ${backup.path} '
          'before migrating v$from to v$to',
    );
  } catch (e, s) {
    DevLogger.error(
      name: 'Database',
      message: 'Failed to back up $fileName before migrating v$from to v$to',
      error: e,
      stackTrace: s,
    );
  }
}

/// Configures WAL mode and recommended pragmas on a freshly opened database.
///
/// Applied via the `setup` callback so that every connection (including
/// read-pool isolates) inherits these settings.
///
/// `wal_autocheckpoint` is lowered from SQLite's default of 1000 pages to
/// 200 pages (~800 KB at the default 4 KB page size). A shorter WAL means
/// smaller, more frequent checkpoints and a narrower window in which a
/// checkpoint can starve a reader — slow-query capture observed a 9-minute
/// stall on a `sync_sequence_log` read whose p95 is <60 ms, consistent
/// with a WAL checkpoint pause rather than a bad plan.
void _setupDatabase(Database database) {
  database
    ..execute('PRAGMA journal_mode = WAL;')
    ..execute('PRAGMA busy_timeout = 5000;')
    ..execute('PRAGMA synchronous = NORMAL;')
    ..execute('PRAGMA wal_autocheckpoint = 200;');
}

/// Resolves the directory database files live in when no explicit
/// [openDbConnection] provider is passed.
///
/// The registered [Directory] singleton is the active profile root (real or
/// guest world) and is the single source of truth for all persisted paths —
/// database opens must never re-derive the OS documents directory, or a DB
/// could land outside the active profile. The OS fallback exists only for
/// bare unit tests that construct a database before any root is registered.
Future<Directory> _defaultDocumentsDirectory() async {
  if (getIt.isRegistered<Directory>()) {
    return getIt<Directory>();
  }
  return findDocumentsDirectory();
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
/// - [slowQueryThreshold]: Threshold used by the shared slow-query interceptor.
///   Slow-query writes remain disabled until the corresponding logging domain
///   is enabled in Settings > Advanced > Logging Domains. Default is 10 ms —
///   a fraction of the 16 ms frame budget, so any single query logged here
///   is already a meaningful slice of a frame. n+1 chains are not caught
///   by thresholding individual queries (each link is under the bar); they
///   are caught by the coalescers in `JournalDb` and by counting round-trips
///   in tests. Pass [Duration.zero] in tests and deep-dive captures to
///   surface every query.
/// - [documentsDirectoryProvider]: Optional provider for the documents
///   directory. Defaults to the registered active-profile root; pass an
///   explicit provider to open a database in a different world (tests,
///   profile seeding).
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
  Duration slowQueryThreshold = const Duration(milliseconds: 10),
  SlowQueryReporter? slowQueryReporter,
  Future<Directory> Function()? documentsDirectoryProvider,
  Future<Directory> Function()? tempDirectoryProvider,
}) {
  return LazyDatabase(() async {
    if (inMemoryDatabase) {
      return NativeDatabase.memory().interceptWith(
        SlowQueryInterceptor(
          databaseName: fileName,
          threshold: slowQueryThreshold,
          reporter:
              slowQueryReporter ?? SlowQueryInterceptor.devLoggerReporter(),
        ),
      );
    }

    final dbFolder =
        await (documentsDirectoryProvider?.call() ??
            _defaultDocumentsDirectory());
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

    final executor = background
        ? NativeDatabase.createInBackground(
            file,
            setup: _setupDatabase,
            readPool: readPool,
          )
        : NativeDatabase(file, setup: _setupDatabase);

    return executor.interceptWith(
      SlowQueryInterceptor(
        databaseName: fileName,
        threshold: slowQueryThreshold,
        reporter:
            slowQueryReporter ??
            SlowQueryInterceptor.fileReporter(
              documentsDirectoryPath: dbFolder.path,
            ),
      ),
    );
  });
}
