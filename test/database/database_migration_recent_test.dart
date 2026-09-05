import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../widget_test_utils.dart';
import 'schema_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDirectory;

  setUp(() async {
    testDirectory = Directory.systemTemp.createTempSync(
      'lotti_v45_day_audio_',
    );
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<Directory>(testDirectory);
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => switch (call.method) {
            'getApplicationDocumentsDirectory' ||
            'getApplicationSupportDirectory' ||
            'getTemporaryDirectory' => testDirectory.path,
            _ => null,
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await tearDownTestGetIt();
    if (testDirectory.existsSync()) {
      testDirectory.deleteSync(recursive: true);
    }
  });

  test('v45 backfills and indexes Daily OS audio lookup identity', () async {
    final databaseFile = File(path.join(testDirectory.path, 'v45.db'));
    final sqlite = sqlite3.open(databaseFile.path);
    createJournalSchema(sqlite, 44);
    const insert =
        'INSERT INTO journal (id, serialized, created_at, updated_at, '
        'date_from, date_to, deleted, type, subtype) '
        'VALUES (?, ?, 0, 0, ?, ?, FALSE, ?, NULL)';
    sqlite
      ..execute(insert, [
        'audio-owner-a',
        _serializedDayAudio(
          dayId: 'dayplan-2026-07-18',
          sessionId: 'duplicate-session',
        ),
        0,
        60,
        'JournalAudio',
      ])
      ..execute(insert, [
        'audio-owner-b',
        _serializedDayAudio(
          dayId: 'dayplan-2026-07-18',
          sessionId: 'duplicate-session',
        ),
        60,
        120,
        'JournalAudio',
      ])
      ..execute(insert, [
        'ordinary-entry',
        '{"data":{}}',
        0,
        60,
        'JournalEntry',
      ])
      ..close();

    final db = JournalDb(overriddenFilename: 'v45.db');
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 47);
    final rows = await db
        .customSelect(
          'SELECT id, day_id, recording_session_id FROM journal ORDER BY id',
        )
        .get();
    final byId = {for (final row in rows) row.read<String>('id'): row};
    expect(byId['audio-owner-a']!.read<String>('day_id'), 'dayplan-2026-07-18');
    expect(
      byId['audio-owner-a']!.read<String>('recording_session_id'),
      'duplicate-session',
    );
    expect(
      byId['audio-owner-b']!.read<String?>('recording_session_id'),
      isNull,
    );
    expect(byId['ordinary-entry']!.read<String?>('day_id'), isNull);

    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name IN ('idx_journal_day_audio', "
          "'idx_journal_recording_session') ORDER BY name",
        )
        .get();
    expect(indexes.map((row) => row.read<String>('name')), [
      'idx_journal_day_audio',
      'idx_journal_recording_session',
    ]);
  });
}

String _serializedDayAudio({
  required String dayId,
  required String sessionId,
}) =>
    '{"data":{"dayContext":{"dayId":"$dayId",'
    '"recordingSessionId":"$sessionId"}}}';
