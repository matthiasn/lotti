import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../test_utils.dart';

void main() {
  late ConsumptionDatabase db;
  late ConsumptionRepository repo;

  setUp(() {
    db = ConsumptionDatabase(inMemoryDatabase: true);
    repo = ConsumptionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('countAllConsumptionEvents reflects inserted rows', () async {
    expect(await db.countAllConsumptionEvents(), 0);
    await repo.upsertEvent(makeConsumptionEvent(id: 'a'));
    await repo.upsertEvent(makeConsumptionEvent(id: 'b'));
    expect(await db.countAllConsumptionEvents(), 2);
  });

  test(
    'streamConsumptionEventsWithVectorClock yields ids and parsed clocks',
    () async {
      await repo.upsertEvent(
        makeConsumptionEvent(id: 'a', vectorClock: const VectorClock({'h': 1})),
      );
      await repo.upsertEvent(makeConsumptionEvent(id: 'b'));

      final all = await db
          .streamConsumptionEventsWithVectorClock(batchSize: 10)
          .expand((batch) => batch)
          .toList();

      expect(all.map((r) => r.id).toList()..sort(), ['a', 'b']);
      expect(all.firstWhere((r) => r.id == 'a').vectorClock, {'h': 1});
      expect(all.firstWhere((r) => r.id == 'b').vectorClock, isNull);
    },
  );

  test('streamConsumptionEventsWithVectorClock pages by batchSize', () async {
    for (var i = 0; i < 5; i++) {
      await repo.upsertEvent(makeConsumptionEvent(id: 'e$i'));
    }
    final batches = await db
        .streamConsumptionEventsWithVectorClock(batchSize: 2)
        .toList();
    expect(batches.map((b) => b.length).toList(), [2, 2, 1]);
  });

  test('migrates the schema-v1 event store to attribution schema v2', () async {
    final directory = Directory.systemTemp.createTempSync('consumption-v1-');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final sqlite = sqlite3.open(
      path.join(directory.path, consumptionDbFileName),
    );
    // ignore: cascade_invocations
    sqlite
      ..execute('''
        CREATE TABLE consumption_events (
          id TEXT NOT NULL PRIMARY KEY,
          parent_id TEXT,
          created_at INTEGER NOT NULL,
          task_id TEXT,
          category_id TEXT,
          entry_id TEXT,
          agent_id TEXT,
          wake_run_key TEXT,
          thread_id TEXT,
          turn_index INTEGER,
          prompt_id TEXT,
          skill_id TEXT,
          config_id TEXT,
          provider_type TEXT NOT NULL,
          model_id TEXT,
          provider_model_id TEXT,
          response_type TEXT NOT NULL,
          duration_ms INTEGER,
          input_tokens INTEGER,
          output_tokens INTEGER,
          cached_input_tokens INTEGER,
          thoughts_tokens INTEGER,
          total_tokens INTEGER,
          credits REAL,
          energy_kwh REAL,
          carbon_g_co2 REAL,
          water_liters REAL,
          renewable_percent REAL,
          pue REAL,
          data_center TEXT,
          upstream_provider_id TEXT,
          serialized TEXT NOT NULL,
          schema_version INTEGER NOT NULL DEFAULT 1
        )
      ''')
      ..execute('PRAGMA user_version = 1')
      ..dispose();

    final migrated = ConsumptionDatabase(
      background: false,
      documentsDirectoryProvider: () async => directory,
      tempDirectoryProvider: () async => directory,
    );
    addTearDown(migrated.close);

    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await migrated
        .customSelect('PRAGMA table_info(consumption_events)')
        .get();
    final objects = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type IN ('table', 'index')",
        )
        .get();
    final names = objects.map((row) => row.read<String>('name')).toSet();

    expect(version.read<int>('user_version'), 2);
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('attribution_id'),
    );
    expect(
      names,
      containsAll(<String>{
        'ai_work_attributions',
        'idx_consumption_attribution',
        'idx_attribution_output',
        'idx_attribution_task_created',
        'idx_attribution_actor_created',
        'idx_attribution_type_created',
      }),
    );
  });
}
