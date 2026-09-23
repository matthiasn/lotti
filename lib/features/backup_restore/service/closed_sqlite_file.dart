import 'dart:io';

import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// What SQLite reports about a database file nothing else has open.
typedef ClosedSqliteReport = ({int userVersion, List<String> problems});

/// Runs `PRAGMA integrity_check` on [database] and reads its
/// `user_version`, without writing anything next to it.
///
/// The file is opened read-only with the `immutable=1` URI option, so SQLite
/// neither takes locks nor creates `-wal`/`-shm` companions. That is only
/// correct because the caller guarantees nothing else has the file open — a
/// staged snapshot or a decrypted backup, never a live database.
///
/// Throws [SqliteException] when the file is not a database at all.
ClosedSqliteReport inspectClosedSqliteFile(File database) {
  final connection = sqlite3.open(
    Uri.file(
      database.path,
    ).replace(queryParameters: const {'immutable': '1'}).toString(),
    mode: OpenMode.readOnly,
    uri: true,
  );
  try {
    final rows = connection.select('PRAGMA integrity_check');
    return (
      userVersion: connection.userVersion,
      problems: [
        for (final row in rows)
          if (row.values.single != 'ok') '${row.values.single}',
      ],
    );
  } finally {
    connection.close();
  }
}

/// The SQLite companions a still-open connection leaves beside [database].
List<File> sqliteCompanions(File database) => [
  for (final suffix in const ['-wal', '-shm', '-journal'])
    if (File(database.path + suffix).existsSync()) File(database.path + suffix),
];

/// Waits until every profile database under [root] is fully closed, and
/// proves it by leaving no `-wal`, `-shm` or `-journal` behind.
///
/// Closing a Drift database does not wait for its read-pool isolates, whose
/// connections can outlive `close()` by a moment. SQLite deletes a WAL only
/// when its last connection closes, so for each database that still has
/// companions this opens a short-lived connection of its own, checkpoints the
/// WAL into the database file, and closes — as the last connection, that
/// removes them. Until the stragglers are gone it retries, pausing with
/// [pause] up to [attempts] times, then gives up with a
/// [ProfileQuiescenceException] naming each database still held open.
///
/// Must only run while the profile's generation is closed.
Future<void> settleProfileDatabases(
  Directory root, {
  int attempts = 100,
  Future<void> Function() pause = _shortPause,
}) async {
  final pending = [
    for (final store in ProfileBackupCatalog.stores)
      if (store.kind == BackupStoreKind.sqliteDatabase)
        File(p.join(root.path, store.relativePath)),
  ].where((database) => database.existsSync()).toList();

  for (var attempt = 0; attempt < attempts && pending.isNotEmpty; attempt++) {
    if (attempt > 0) await pause();
    pending.removeWhere((database) {
      if (sqliteCompanions(database).isEmpty) return true;
      _checkpointAndClose(database);
      return sqliteCompanions(database).isEmpty;
    });
  }
  if (pending.isNotEmpty) {
    throw ProfileQuiescenceException([
      for (final database in pending)
        ServiceDisposalFailure(
          service: p.relative(database.path, from: root.path),
          error: StateError('a connection to this database is still open'),
          stackTrace: StackTrace.current,
        ),
    ]);
  }
}

Future<void> _shortPause() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void _checkpointAndClose(File database) {
  Database? connection;
  try {
    connection = sqlite3.open(database.path)
      ..execute('PRAGMA wal_checkpoint(TRUNCATE)');
  } on SqliteException {
    // Busy or locked: another connection is still closing. The caller
    // retries, and reports the database if it never settles.
  } finally {
    connection?.close();
  }
}
