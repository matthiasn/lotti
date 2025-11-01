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
}
