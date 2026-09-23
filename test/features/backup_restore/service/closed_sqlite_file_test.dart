import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/backup_restore/service/closed_sqlite_file.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Closes [connection] once; later calls are no-ops.
void closeQuietly(Database connection) {
  try {
    connection.close();
    // Closing twice is a StateError in package:sqlite3.
    // ignore: avoid_catching_errors
  } on StateError {
    // Already closed.
  }
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('lotti_settle_'));
  tearDown(() => root.deleteSync(recursive: true));

  File database(String name) => File(p.join(root.path, name));

  /// A WAL database with one committed row still only in its WAL, and a
  /// second connection kept open — as a read-pool isolate that has not
  /// finished closing leaves it. Returns that straggler.
  Database leaveStraggler(String name) {
    final writer = sqlite3.open(database(name).path)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA wal_autocheckpoint = 0')
      ..execute('CREATE TABLE probe (value TEXT)')
      ..execute("INSERT INTO probe VALUES ('committed')");
    final straggler = sqlite3.open(database(name).path)
      ..select('SELECT count(*) FROM probe');
    // Closed by the test when it wants, and always at the end, so a failing
    // assertion never leaves it holding the file.
    addTearDown(() => closeQuietly(straggler));
    writer.close();
    expect(sqliteCompanions(database(name)), isNotEmpty);
    return straggler;
  }

  group('settleProfileDatabases', () {
    test('waits out a lingering connection, then leaves no companions and '
        'the commit in the database file', () async {
      final straggler = leaveStraggler('db.sqlite');
      var pauses = 0;

      await settleProfileDatabases(
        root,
        pause: () async {
          pauses++;
          closeQuietly(straggler);
        },
      );

      expect(pauses, 1);
      expect(sqliteCompanions(database('db.sqlite')), isEmpty);
      final report = inspectClosedSqliteFile(database('db.sqlite'));
      expect(report.problems, isEmpty);
      final check = sqlite3.open(
        database('db.sqlite').path,
        mode: OpenMode.readOnly,
      );
      addTearDown(check.close);
      expect(
        check.select('SELECT value FROM probe').single['value'],
        'committed',
      );
    });

    test('removes what a read-only last connection leaves behind', () async {
      // A read-only connection closing last cannot remove the WAL, so the
      // companions outlive every connection — only a checkpoint by a
      // writable connection of our own clears them.
      final writer = sqlite3.open(database('db.sqlite').path)
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('PRAGMA wal_autocheckpoint = 0')
        ..execute('CREATE TABLE probe (value TEXT)')
        ..execute("INSERT INTO probe VALUES ('committed')");
      final reader = sqlite3.open(
        database('db.sqlite').path,
        mode: OpenMode.readOnly,
      )..select('SELECT count(*) FROM probe');
      writer.close();
      reader.close();
      expect(
        sqliteCompanions(database('db.sqlite')),
        isNotEmpty,
        reason: 'the fixture must leave companions with nothing open',
      );
      var pauses = 0;

      await settleProfileDatabases(root, pause: () async => pauses++);

      expect(pauses, 0);
      expect(sqliteCompanions(database('db.sqlite')), isEmpty);
      final check = sqlite3.open(
        database('db.sqlite').path,
        mode: OpenMode.readOnly,
      );
      addTearDown(check.close);
      expect(
        check.select('SELECT value FROM probe').single['value'],
        'committed',
      );
    });

    test('waits between attempts by default', () {
      fakeAsync((async) {
        final straggler = leaveStraggler('db.sqlite');
        var settled = false;
        unawaited(settleProfileDatabases(root).then((_) => settled = true));
        async.flushMicrotasks();
        expect(settled, isFalse);

        closeQuietly(straggler);
        async
          ..elapse(const Duration(milliseconds: 50))
          ..flushMicrotasks();

        expect(settled, isTrue);
        expect(sqliteCompanions(database('db.sqlite')), isEmpty);
      });
    });

    test('reports a database it cannot even checkpoint', () async {
      // Not a database at all, with a companion beside it: every checkpoint
      // attempt fails, and the file is named rather than trusted.
      // Several pages of text: long enough that SQLite reads a header and
      // rejects it, where a file shorter than one could pass as empty.
      final garbage = database('db.sqlite')
        ..writeAsStringSync('not a database ' * 600);
      File('${garbage.path}-wal').writeAsStringSync('x');

      await expectLater(
        settleProfileDatabases(root, attempts: 2, pause: () async {}),
        throwsA(
          isA<ProfileQuiescenceException>().having(
            (e) => e.failures.single.service,
            'database',
            'db.sqlite',
          ),
        ),
      );
    });

    test('names every database that never settles', () async {
      leaveStraggler('db.sqlite');
      leaveStraggler('settings.sqlite');
      var pauses = 0;

      await expectLater(
        settleProfileDatabases(
          root,
          attempts: 3,
          pause: () async => pauses++,
        ),
        throwsA(
          isA<ProfileQuiescenceException>().having(
            (e) => e.failures.map((f) => f.service).toSet(),
            'databases',
            {'db.sqlite', 'settings.sqlite'},
          ),
        ),
      );
      expect(pauses, 2);
    });

    test('returns at once when every database is already closed', () async {
      sqlite3.open(database('db.sqlite').path)
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('CREATE TABLE probe (value TEXT)')
        ..close();
      // Not a database the catalog knows, so never looked at.
      File(p.join(root.path, 'notes.sqlite-wal')).writeAsStringSync('x');
      var pauses = 0;

      await settleProfileDatabases(root, pause: () async => pauses++);

      expect(pauses, 0);
    });
  });

  test('lists the companions beside a database', () {
    final file = database('db.sqlite')..writeAsStringSync('');
    File('${file.path}-wal').writeAsStringSync('');
    File('${file.path}-journal').writeAsStringSync('');

    expect(
      sqliteCompanions(file).map((f) => p.basename(f.path)),
      ['db.sqlite-wal', 'db.sqlite-journal'],
    );
  });
}
