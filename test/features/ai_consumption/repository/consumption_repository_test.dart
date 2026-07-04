// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/sync/vector_clock.dart';

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

  group('upsertEvent / getEvent', () {
    test('round-trips an event with full impact data', () async {
      final event = makeConsumptionEvent(
        vectorClock: const VectorClock({'host-a': 3}),
      );
      await repo.upsertEvent(event);
      expect(await repo.getEvent(event.id), event);
    });

    test('round-trips an event with all impact fields null', () async {
      final event = makeConsumptionEvent(
        id: 'gemini-1',
        providerType: InferenceProviderType.gemini,
        responseType: AiConsumptionResponseType.textGeneration,
        credits: null,
        energyKwh: null,
        carbonGCo2: null,
        waterLiters: null,
        renewablePercent: null,
        pue: null,
        dataCenter: null,
      );
      await repo.upsertEvent(event);
      final loaded = await repo.getEvent('gemini-1');
      expect(loaded, event);
      expect(loaded!.energyKwh, isNull);
      expect(loaded.credits, isNull);
      expect(loaded.dataCenter, isNull);
    });

    test(
      'is idempotent by id — a replay overwrites, never duplicates',
      () async {
        final first = makeConsumptionEvent(id: 'dup', outputTokens: 500);
        await repo.upsertEvent(first);
        await repo.upsertEvent(first.copyWith(outputTokens: 999));
        expect(await db.countAllConsumptionEvents(), 1);
        expect((await repo.getEvent('dup'))!.outputTokens, 999);
      },
    );

    test('getEvent returns null for an unknown id', () async {
      expect(await repo.getEvent('nope'), isNull);
    });
  });

  group('getVectorClock', () {
    test('returns the stamped clock without loading the whole row', () async {
      await repo.upsertEvent(
        makeConsumptionEvent(
          id: 'vc-1',
          vectorClock: const VectorClock({'host-a': 2, 'host-b': 5}),
        ),
      );
      expect(
        await repo.getVectorClock('vc-1'),
        const VectorClock({'host-a': 2, 'host-b': 5}),
      );
    });

    test('returns null when the event has no clock', () async {
      await repo.upsertEvent(
        makeConsumptionEvent(id: 'vc-none'),
      );
      expect(await repo.getVectorClock('vc-none'), isNull);
    });

    test('returns null for an unknown id', () async {
      expect(await repo.getVectorClock('missing'), isNull);
    });
  });

  group('totalsForTask', () {
    test('sums every metric and counts only impact-bearing calls', () async {
      await repo.upsertEvent(
        makeConsumptionEvent(
          id: 'a',
          taskId: 't',
          inputTokens: 1000,
          outputTokens: 500,
          totalTokens: 1500,
          credits: 0.002,
          energyKwh: 0.0003,
          carbonGCo2: 0.12,
          waterLiters: 0.01,
        ),
      );
      await repo.upsertEvent(
        makeConsumptionEvent(
          id: 'b',
          taskId: 't',
          inputTokens: 200,
          outputTokens: 100,
          totalTokens: 300,
          credits: 0.001,
          energyKwh: 0.0001,
          carbonGCo2: 0.05,
          waterLiters: 0.02,
        ),
      );
      // A no-impact call (Gemini) on the same task counts toward callCount and
      // tokens, but not impactCallCount or the impact sums.
      await repo.upsertEvent(
        makeConsumptionEvent(
          id: 'c',
          taskId: 't',
          providerType: InferenceProviderType.gemini,
          inputTokens: 50,
          outputTokens: 25,
          totalTokens: 75,
          credits: null,
          energyKwh: null,
          carbonGCo2: null,
          waterLiters: null,
        ),
      );

      final totals = await repo.totalsForTask('t');
      expect(totals.callCount, 3);
      expect(totals.impactCallCount, 2);
      expect(totals.inputTokens, 1250);
      expect(totals.outputTokens, 625);
      expect(totals.totalTokens, 1875);
      expect(totals.credits, closeTo(0.003, 1e-9));
      expect(totals.energyKwh, closeTo(0.0004, 1e-9));
      expect(totals.carbonGCo2, closeTo(0.17, 1e-9));
      expect(totals.waterLiters, closeTo(0.03, 1e-9));
    });

    test('ignores rows belonging to other tasks', () async {
      await repo.upsertEvent(
        makeConsumptionEvent(id: 'x', taskId: 't1', totalTokens: 100),
      );
      await repo.upsertEvent(
        makeConsumptionEvent(id: 'y', taskId: 't2', totalTokens: 999),
      );
      final totals = await repo.totalsForTask('t1');
      expect(totals.callCount, 1);
      expect(totals.totalTokens, 100);
    });

    test('returns zeroed totals for a task with no rows', () async {
      final totals = await repo.totalsForTask('empty');
      expect(totals.callCount, 0);
      expect(totals.impactCallCount, 0);
      expect(totals.totalTokens, 0);
      expect(totals.energyKwh, 0);
    });
  });

  group('projection columns', () {
    test('denormalized columns are populated for aggregation', () async {
      await repo.upsertEvent(
        makeConsumptionEvent(
          id: 'proj',
          taskId: 'task-proj',
          categoryId: 'cat-proj',
          providerType: InferenceProviderType.melious,
          responseType: AiConsumptionResponseType.audioTranscription,
          energyKwh: 0.0009,
        ),
      );
      final row = await db
          .customSelect(
            'SELECT task_id, category_id, provider_type, response_type, '
            'energy_kwh FROM consumption_events WHERE id = ?',
            variables: [Variable.withString('proj')],
          )
          .getSingle();
      expect(row.read<String>('task_id'), 'task-proj');
      expect(row.read<String>('category_id'), 'cat-proj');
      expect(row.read<String>('provider_type'), 'melious');
      expect(row.read<String>('response_type'), 'audioTranscription');
      expect(row.read<double>('energy_kwh'), closeTo(0.0009, 1e-9));
    });
  });

  group('metricRowsInRange', () {
    test(
      'returns only rows within [start, end), created_at as DateTime',
      () async {
        final t1 = DateTime(2026, 3, 15, 10);
        final t2 = DateTime(2026, 3, 15, 23);
        await repo.upsertEvent(
          makeConsumptionEvent(
            id: 'in1',
            createdAt: t1,
            categoryId: 'a',
            totalTokens: 100,
          ),
        );
        await repo.upsertEvent(
          makeConsumptionEvent(
            id: 'in2',
            createdAt: t2,
            categoryId: 'b',
            totalTokens: 40,
          ),
        );
        // Just before the window and just after it — both excluded.
        await repo.upsertEvent(
          makeConsumptionEvent(
            id: 'before',
            createdAt: DateTime(2026, 3, 14, 23),
          ),
        );
        await repo.upsertEvent(
          makeConsumptionEvent(
            id: 'after',
            createdAt: DateTime(2026, 3, 16, 0, 0, 1),
          ),
        );

        final rows = await repo.metricRowsInRange(
          start: DateTime(2026, 3, 15),
          end: DateTime(2026, 3, 16),
        );

        expect(rows.map((r) => r.createdAt).toSet(), {t1, t2});
        expect(
          {for (final r in rows) r.categoryId: r.metrics.totalTokens},
          {'a': 100, 'b': 40},
        );
      },
    );

    test(
      'reads the denormalized category directly — one row per call',
      () async {
        await repo.upsertEvent(
          makeConsumptionEvent(
            id: 'x',
            createdAt: DateTime(2026, 3, 15, 9),
            categoryId: 'cat',
            totalTokens: 10,
          ),
        );
        final rows = await repo.metricRowsInRange(
          start: DateTime(2026, 3, 15),
          end: DateTime(2026, 3, 16),
        );
        expect(rows.length, 1);
        expect(rows.single.categoryId, 'cat');
        expect(rows.single.metrics.callCount, 1);
      },
    );

    test('null token/impact columns read back as zero', () async {
      await repo.upsertEvent(
        makeConsumptionEvent(
          id: 'nulls',
          createdAt: DateTime(2026, 3, 15, 8),
          categoryId: null,
          inputTokens: null,
          outputTokens: null,
          totalTokens: null,
          cachedInputTokens: null,
          thoughtsTokens: null,
          credits: null,
          energyKwh: null,
          carbonGCo2: null,
          waterLiters: null,
        ),
      );
      final rows = await repo.metricRowsInRange(
        start: DateTime(2026, 3, 15),
        end: DateTime(2026, 3, 16),
      );
      final metrics = rows.single.metrics;
      expect(rows.single.categoryId, isNull);
      expect(metrics.totalTokens, 0);
      expect(metrics.energyKwh, 0);
      expect(metrics.callCount, 1);
    });
  });
}
