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

/// How many snapshots of one database [createDbBackup] keeps.
///
/// A backup is the safety copy for the migration or purge that just ran,
/// not an archive: three covers the copy before this upgrade, the one
/// before that, and a purge in between, while keeping `backup/` bounded.
/// Before retention existed the directory only ever grew — three stores
/// each adding a journal-sized file per upgrade.
const int backupsKeptPerDatabase = 3;
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
/// `agent.sqlite` becomes `backup/agent.….sqlite`. Once the new snapshot is
/// complete, older snapshots of the same source beyond
/// [backupsKeptPerDatabase] are deleted (with the WAL sidecar a raw-copy
/// fallback leaves), so a failed snapshot never costs an existing one.
/// Returns the backup file.
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
  final target = _unusedBackupTarget(backupDir, '$stem.$ts');

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
    if (!_isUnreadableSource(e)) {
      // Anything but "the source is not a readable database" — a busy
      // lock, an unwritable target — is a failure of *this* backup, not a
      // reason to hand back a raw copy that may not be consistent.
      await walStash?.delete();
      rethrow;
    }
    DevLogger.warning(
      name: 'Database',
      message:
          'VACUUM INTO failed for $fileName ($e); '
          'falling back to a raw copy of the main file and its WAL',
    );
    // File.copy replaces whatever a failed attempt left at the target.
    await file.copy(target.path);
    await walStash?.rename('${target.path}-wal');
  }
  await _pruneOlderBackups(backupDir, stem: stem, newest: target);
  return target;
}

final RegExp _backupTimestamp = RegExp(
  r'^(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}-\d+)(?:-(\d+))?$',
);

/// Keeps `newest` plus the [backupsKeptPerDatabase] − 1 most recent other
/// snapshots of [stem] in [backupDir] and deletes the rest. `newest` is
/// kept by identity, not by rank: if the device clock has moved backwards
/// since the previous snapshot, the file just written sorts *below* older
/// ones, and ranking alone would keep four copies. Ordering of the others
/// comes from the timestamp in the file name, so it matches the clock that
/// named them rather than filesystem times.
/// Every snapshot of [stem] in [backupDir] as (timestamp, collision suffix,
/// file), newest first. Ordering comes from the timestamp in the file name,
/// so it follows the clock that named them rather than filesystem times.
List<(String, int, File)> _snapshotsOf(
  Directory backupDir, {
  required String stem,
}) {
  final prefix = '$stem.';
  final snapshots = <(String, int, File)>[];
  if (!backupDir.existsSync()) return snapshots;
  for (final entity in backupDir.listSync()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (!name.startsWith(prefix) || !name.endsWith(_backupFileExtension)) {
      continue;
    }
    final match = _backupTimestamp.firstMatch(
      name.substring(prefix.length, name.length - _backupFileExtension.length),
    );
    if (match == null) continue;
    snapshots.add((
      match.group(1)!,
      int.tryParse(match.group(2) ?? '1') ?? 1,
      entity,
    ));
  }
  return snapshots..sort((a, b) {
    final byTime = b.$1.compareTo(a.$1);
    return byTime != 0 ? byTime : b.$2.compareTo(a.$2);
  });
}

Future<void> _pruneOlderBackups(
  Directory backupDir, {
  required String stem,
  required File newest,
}) async {
  final snapshots = _snapshotsOf(backupDir, stem: stem)
    ..removeWhere((snapshot) => p.equals(snapshot.$3.path, newest.path));
  final stale = snapshots.skip(backupsKeptPerDatabase - 1);
  var pruned = 0;
  for (final (_, _, file) in stale) {
    await file.delete();
    final wal = File('${file.path}-wal');
    if (wal.existsSync()) {
      await wal.delete();
    }
    pruned += 1;
  }
  if (pruned > 0) {
    DevLogger.log(
      name: 'Database',
      message:
          'Pruned $pruned older backup(s) of $stem, '
          'keeping the $backupsKeptPerDatabase newest',
    );
  }
}

/// Two backups in one formatted instant (the same millisecond) must not
/// share a target: `VACUUM INTO` refuses an existing non-empty file, and the
/// fallback would then overwrite the first backup. Suffix until free.
File _unusedBackupTarget(Directory backupDir, String baseName) {
  var candidate = File(
    p.join(backupDir.path, '$baseName$_backupFileExtension'),
  );
  var attempt = 1;
  while (candidate.existsSync()) {
    attempt += 1;
    candidate = File(
      p.join(backupDir.path, '$baseName-$attempt$_backupFileExtension'),
    );
  }
  return candidate;
}

/// `SQLITE_NOTADB` and `SQLITE_CORRUPT`: the source itself cannot be read as
/// a database, which is the one case a raw copy is the best we can do.
bool _isUnreadableSource(SqliteException e) {
  const notADatabase = 26;
  const corrupt = 11;
  return e.resultCode == notADatabase || e.resultCode == corrupt;
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
/// 200 pages (~800 KB at the default 4 KB page size), targeting smaller,
/// more frequent checkpoints. Slow-query executor timings do not isolate
/// checkpoint work from queueing, transport, or application suspension;
/// they cannot establish the cause of historical multi-minute stalls.
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

    // A file whose header no longer reads as a database fails every query
    // that follows, so try the newest backup before opening it.
    await recoverDatabaseIfUnreadable(file);
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

/// Whether [file] can still be opened and read as a SQLite database.
///
/// Reads the header and the schema cookie only, so the cost does not grow
/// with the database — this runs once per store per launch. A file that is
/// not a database at all, or whose header is damaged, reports `false`;
/// anything else (a lock, a missing file, a permission problem) is not a
/// corruption verdict and reports `true` so the normal open path surfaces it.
bool isReadableDatabaseFile(File file) {
  if (!file.existsSync()) return true;
  Database? database;
  try {
    database = sqlite3.open(file.path)..select('PRAGMA schema_version');
    return true;
  } on SqliteException catch (e) {
    return !_isUnreadableSource(e);
  } catch (_) {
    return true;
  } finally {
    database?.close();
  }
}

/// Replaces an unreadable [file] with the newest usable backup of it, if one
/// exists, and returns the backup that was restored.
///
/// The damaged file is kept as `<name>.corrupt-<timestamp>` rather than
/// deleted: it is the only copy of whatever the backup does not carry, and a
/// user who asks for help later needs it. Its `-wal` and `-shm` companions
/// move with it under the same name — they must leave the live path, because
/// SQLite would otherwise replay a write-ahead log belonging to the file that
/// was just replaced, but the WAL of an unreadable file holds exactly the
/// commits the snapshot is missing.
///
/// The snapshot is copied to a scratch path and only moved into place once
/// that copy has succeeded, so a failure partway cannot leave the live path
/// empty for the next open to fill with a fresh, blank database.
///
/// Snapshots are tried newest first, so a backup that is itself damaged does
/// not block recovery from an older one. Returns `null` when nothing was
/// restored — no backup directory, no snapshot, or none of them readable.
Future<File?> restoreDatabaseFromBackup(File file) async {
  final backupDir = Directory(p.join(file.parent.path, _backupDirectoryName));
  final stem = p.basenameWithoutExtension(file.path);
  for (final (_, _, snapshot) in _snapshotsOf(backupDir, stem: stem)) {
    if (!isReadableDatabaseFile(snapshot)) {
      DevLogger.warning(
        name: 'Database',
        message:
            'Backup ${p.basename(snapshot.path)} is unreadable too, '
            'trying an older one',
      );
      continue;
    }
    // Copy to a scratch path first: a copy that fails partway — a full disk,
    // a snapshot that became unreadable since the probe — must not be able to
    // leave the live path empty, because the open that follows would create a
    // fresh database there and the corruption would never surface.
    final staged = File('${file.path}.restore-tmp');
    if (staged.existsSync()) await staged.delete();
    try {
      await snapshot.copy(staged.path);
    } catch (_) {
      if (staged.existsSync()) await staged.delete();
      rethrow;
    }
    final ts = DateFormat(_backupTimestampFormat).format(clock.now());
    if (file.existsSync()) {
      await file.rename('${file.path}.corrupt-$ts');
    }
    // The companions move with the file they belong to rather than being
    // deleted. They must leave the live path — SQLite would replay a WAL it
    // finds beside the restored snapshot — but an unreadable main file's WAL
    // holds exactly the commits the snapshot is missing, which is what makes
    // the kept artifact worth keeping.
    for (final suffix in const ['-wal', '-shm']) {
      final companion = File('${file.path}$suffix');
      if (companion.existsSync()) {
        await companion.rename('${file.path}.corrupt-$ts$suffix');
      }
    }
    await staged.rename(file.path);
    return snapshot;
  }
  return null;
}

/// Restores [file] from its newest backup when it can no longer be read.
///
/// Called on the open path, before the connection is built: a database whose
/// header is damaged fails every query afterwards, and the snapshot taken
/// before the last migration is a better starting point than an app that
/// cannot start. A store with no backup is left alone, so the failure
/// surfaces where it always did.
Future<void> recoverDatabaseIfUnreadable(File file) async {
  if (isReadableDatabaseFile(file)) return;
  DevLogger.warning(
    name: 'Database',
    message:
        '${p.basename(file.path)} cannot be read as a database, '
        'looking for a backup to restore',
  );
  try {
    final restored = await restoreDatabaseFromBackup(file);
    DevLogger.log(
      name: 'Database',
      message: restored == null
          ? 'No usable backup of ${p.basename(file.path)} to restore from'
          : 'Restored ${p.basename(file.path)} from '
                '${p.basename(restored.path)}',
    );
  } catch (e, stackTrace) {
    // Recovery is best effort: a failure here must not stop the app from
    // reaching the open call that reports the real problem.
    DevLogger.warning(
      name: 'Database',
      message: 'Restoring ${p.basename(file.path)} failed: $e\n$stackTrace',
    );
  }
}

/// How long `PRAGMA optimize` may run before [optimizeAndClose] gives up on
/// it and closes anyway. Comfortably under both the disposer's per-operation
/// deadline and the 5s `busy_timeout` these connections carry, so a statement
/// stuck behind a lock cannot eat the budget the close needs.
const optimizeBeforeCloseTimeout = Duration(seconds: 1);

/// Runs `PRAGMA optimize` and closes [database].
///
/// `ANALYZE` only ever runs inside a migration step here, so planner
/// statistics age with the data while the schema stands still — and the
/// index comments in `database.drift` record how sensitive this schema's
/// plans are to stale statistics. `PRAGMA optimize` is the cheap form:
/// SQLite re-analyses only the indexes whose statistics it believes have
/// gone stale, and does nothing at all on a connection that barely queried.
/// Shutdown is where it costs nothing the user can feel.
///
/// A failure is logged and swallowed, and the statement is bounded by
/// [timeout]: this runs on the way out, nothing about it is worth failing a
/// shutdown for, and the close it precedes has a deadline of its own that a
/// statement waiting on a busy lock must not be allowed to consume. The
/// close runs whatever the optimize did.
Future<void> optimizeAndClose(
  GeneratedDatabase database, {
  Duration timeout = optimizeBeforeCloseTimeout,
}) async {
  try {
    await database.customStatement('PRAGMA optimize').timeout(timeout);
  } catch (e, stackTrace) {
    DevLogger.warning(
      name: 'Database',
      message: 'PRAGMA optimize failed before close: $e\n$stackTrace',
    );
  } finally {
    // Always, and in a finally: the whole point of closing on shutdown is
    // that no native handle outlives the engine, and an optimize that hangs
    // on a lock must not be able to take the close down with it.
    await database.close();
  }
}

/// The result of an integrity check over one database file.
typedef DatabaseIntegrityReport = ({String database, List<String> problems});

/// Runs `PRAGMA quick_check` against [database] and reports what it found.
///
/// `quick_check` is the cheaper half of `integrity_check`: it verifies page
/// structure and record layout but skips the index-content cross-checks, so
/// it is fast enough to run from a settings page. SQLite reports a single
/// row reading `ok` on a healthy database; anything else is the list of
/// problems, which is what the report's `problems` carries.
Future<DatabaseIntegrityReport> quickCheck(
  String name,
  GeneratedDatabase database,
) async {
  final rows = await database.customSelect('PRAGMA quick_check').get();
  final results = rows
      .map((row) => row.data.values.first.toString())
      .where((result) => result != 'ok')
      .toList(growable: false);
  return (database: name, problems: results);
}
