import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/sync_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('openDbConnection creates parent directory if missing', () async {
    final base = Directory.systemTemp.createTempSync('db_parent_create_');
    addTearDown(
        () => base.existsSync() ? base.deleteSync(recursive: true) : null);

    // Nested path that does not exist yet
    final nested = Directory('${base.path}/foo/bar/baz');
    expect(nested.existsSync(), isFalse);

    final lazy = openDbConnection(
      'test.sqlite',
      documentsDirectoryProvider: () async => nested,
    );

    // Force initialization by creating a database using the executor
    final db = SyncDatabase.connect(DatabaseConnection(lazy));
    // Trigger a simple query to ensure the file is opened
    await db.allOutboxItems;

    expect(nested.existsSync(), isTrue);
    await db.close();
  });

  test('openDbConnection handles temp directory resolution failure', () async {
    final base = Directory.systemTemp.createTempSync('db_tempdir_fail_');
    addTearDown(
        () => base.existsSync() ? base.deleteSync(recursive: true) : null);

    var tempProviderCalled = false;
    final lazy = openDbConnection(
      'test.sqlite',
      documentsDirectoryProvider: () async => base,
      tempDirectoryProvider: () {
        tempProviderCalled = true;
        throw const FileSystemException('perm denied');
      },
    );

    final db = SyncDatabase.connect(DatabaseConnection(lazy));
    // If temp directory resolution fails, sqlite should still use OS default.
    // Ensure opening works by running a simple query.
    await db.allOutboxItems;
    expect(tempProviderCalled, isTrue);
    await db.close();
  });

  test('openDbConnection enables WAL mode for file-based databases', () async {
    final base = Directory.systemTemp.createTempSync('wal_test_');
    addTearDown(
        () => base.existsSync() ? base.deleteSync(recursive: true) : null);

    final lazy = openDbConnection(
      'test_wal.sqlite',
      documentsDirectoryProvider: () async => base,
      tempDirectoryProvider: () async => base,
    );

    final db = SyncDatabase.connect(DatabaseConnection(lazy));

    final walResult = await db.customSelect('PRAGMA journal_mode').getSingle();
    expect(walResult.read<String>('journal_mode'), 'wal');

    final busyResult = await db.customSelect('PRAGMA busy_timeout').getSingle();
    expect(busyResult.read<int>('timeout'), 5000);

    final syncResult = await db.customSelect('PRAGMA synchronous').getSingle();
    // NORMAL = 1
    expect(syncResult.read<int>('synchronous'), 1);

    await db.close();
  });

  test('openDbConnection with background=false uses NativeDatabase directly',
      () async {
    final base = Directory.systemTemp.createTempSync('wal_nobg_test_');
    addTearDown(
        () => base.existsSync() ? base.deleteSync(recursive: true) : null);

    final lazy = openDbConnection(
      'test_nobg.sqlite',
      background: false,
      documentsDirectoryProvider: () async => base,
      tempDirectoryProvider: () async => base,
    );

    final db = SyncDatabase.connect(DatabaseConnection(lazy));

    // WAL pragmas should still be applied even without background isolate
    final walResult = await db.customSelect('PRAGMA journal_mode').getSingle();
    expect(walResult.read<String>('journal_mode'), 'wal');

    final busyResult = await db.customSelect('PRAGMA busy_timeout').getSingle();
    expect(busyResult.read<int>('timeout'), 5000);

    await db.close();
  });
}
