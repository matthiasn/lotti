// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }

    testDirectory = Directory.systemTemp.createTempSync('lotti_default_prio_');

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

  test('Legacy tasks default to P2 priority when not set', () async {
    final db = JournalDb(inMemoryDatabase: true);
    final base = DateTime(2024, 10, 1);

    const id = 'legacy-task';
    final task = JournalEntity.task(
      meta: Metadata(
        id: id,
        createdAt: base,
        updatedAt: base,
        dateFrom: base,
        dateTo: base,
      ),
      data: testTask.data.copyWith(
        title: 'Legacy Task',
        // do not set priority explicitly, rely on default
      ),
      entryText: const EntryText(plainText: 'test'),
    );

    await db.updateJournalEntity(task);

    final result = await db.journalEntityById(id);
    expect(result, isNotNull);
    final savedTask = result! as Task;
    expect(savedTask.data.priority, TaskPriority.p2Medium);

    await db.close();
  });
}
