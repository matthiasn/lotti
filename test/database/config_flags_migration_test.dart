// The v48 config_flags rebuild (`lib/database/database_migration_recent.dart`).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'schema_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDirectory;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }
    testDirectory = Directory.systemTemp.createTempSync('lotti_v48_flags_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async => switch (call.method) {
            'getApplicationDocumentsDirectory' ||
            'getApplicationSupportDirectory' ||
            'getTemporaryDirectory' => testDirectory.path,
            _ => null,
          },
        );
    getIt.registerSingleton<Directory>(testDirectory);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'v48 keeps every flag and lets two flags share a description',
    () async {
      final dbFile = File(p.join(testDirectory.path, 'flags_v47.db'));
      final sqlite = sqlite3.open(dbFile.path);
      createJournalSchema(sqlite, 47);
      sqlite
        ..execute(
          'INSERT INTO config_flags (name, description, status) '
          "VALUES ('private', 'Show private entries', 1)",
        )
        ..execute(
          'INSERT INTO config_flags (name, description, status) '
          "VALUES ('enable_notifications', 'Enable notifications', 0)",
        );
      // What the old shape refused: a second flag with the same wording.
      expect(
        () => sqlite.execute(
          'INSERT INTO config_flags (name, description, status) '
          "VALUES ('other', 'Show private entries', 0)",
        ),
        throwsA(isA<SqliteException>()),
      );
      sqlite.close();

      final db = JournalDb(overriddenFilename: 'flags_v47.db');
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 48);

      final flags = await db.listConfigFlags().get();
      expect(
        {for (final flag in flags) flag.name: flag.status},
        {'private': true, 'enable_notifications': false},
      );

      await db.upsertConfigFlag(
        const ConfigFlag(
          name: 'other',
          description: 'Show private entries',
          status: false,
        ),
      );
      expect(await db.getConfigFlag('other'), isFalse);
      expect(await db.listConfigFlags().get(), hasLength(3));
    },
  );
}
