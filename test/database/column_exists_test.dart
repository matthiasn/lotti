import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }

    testDirectory = Directory.systemTemp.createTempSync('lotti_col_exists_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory' ||
            methodCall.method == 'getApplicationSupportDirectory' ||
            methodCall.method == 'getTemporaryDirectory') {
          return testDirectory!.path;
        }
        return null;
      },
    );

    getIt.registerSingleton<Directory>(testDirectory!);
  });

  tearDown(() async {
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
    if (testDirectory != null && testDirectory!.existsSync()) {
      testDirectory!.deleteSync(recursive: true);
    }
  });

  test('columnExistsForTesting returns true/false appropriately', () async {
    final db = JournalDb(overriddenFilename: 'col_exists.db');
    // journal table is part of schema; id column should exist
    expect(await db.columnExistsForTesting('journal', 'id'), isTrue);
    // Priority columns should also exist in current schema
    expect(await db.columnExistsForTesting('journal', 'task_priority'), isTrue);
    expect(await db.columnExistsForTesting('journal', 'task_priority_rank'),
        isTrue);
    expect(await db.columnExistsForTesting('journal', 'nonexistent'), isFalse);
    // Non-existent table should be false
    expect(await db.columnExistsForTesting('fake_table', 'id'), isFalse);
    await db.close();
  });
}
