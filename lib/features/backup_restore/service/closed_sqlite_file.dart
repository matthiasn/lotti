import 'dart:io';

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
