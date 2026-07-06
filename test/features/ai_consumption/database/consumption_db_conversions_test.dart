import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/database/consumption_db_conversions.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_utils.dart';

void main() {
  late ConsumptionDatabase db;

  setUp(() {
    db = ConsumptionDatabase(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  Future<ConsumptionEvent> insertAndReadRow(AiConsumptionEvent event) async {
    await db
        .into(db.consumptionEvents)
        .insertOnConflictUpdate(ConsumptionDbConversions.toCompanion(event));
    return db.select(db.consumptionEvents).getSingle();
  }

  test(
    'toCompanion projects queryable fields into the typed columns',
    () async {
      // The typed columns are write-only (aggregation queries read them, the
      // domain model never does), so this is the only place their projection is
      // verified.
      final event = makeConsumptionEvent(
        turnIndex: 4,
        cachedInputTokens: 250,
        thoughtsTokens: 30,
        upstreamProviderId: 'z-ai',
      );

      final row = await insertAndReadRow(event);

      expect(row.id, event.id);
      expect(row.createdAt, event.createdAt);
      expect(row.taskId, event.taskId);
      expect(row.categoryId, event.categoryId);
      expect(row.turnIndex, 4);
      expect(row.providerType, 'melious');
      expect(row.responseType, 'agentTurn');
      expect(row.modelId, event.modelId);
      expect(row.durationMs, event.durationMs);
      expect(row.inputTokens, event.inputTokens);
      expect(row.outputTokens, event.outputTokens);
      expect(row.cachedInputTokens, 250);
      expect(row.thoughtsTokens, 30);
      expect(row.totalTokens, event.totalTokens);
      expect(row.credits, event.credits);
      expect(row.energyKwh, event.energyKwh);
      expect(row.carbonGCo2, event.carbonGCo2);
      expect(row.waterLiters, event.waterLiters);
      expect(row.renewablePercent, event.renewablePercent);
      expect(row.pue, event.pue);
      expect(row.dataCenter, event.dataCenter);
      expect(row.upstreamProviderId, 'z-ai');
    },
  );

  test(
    'serialized column carries the full entity JSON including vectorClock',
    () async {
      final event = makeConsumptionEvent(
        vectorClock: const VectorClock({'host-a': 2}),
      );

      final row = await insertAndReadRow(event);
      final blob = jsonDecode(row.serialized) as Map<String, dynamic>;

      expect(blob['id'], event.id);
      expect(blob['vectorClock'], {'host-a': 2});
    },
  );

  test('fromRow decodes the serialized blob back to an equal event', () async {
    final event = makeConsumptionEvent(
      vectorClock: const VectorClock({'host-a': 2, 'host-b': 5}),
      parentId: 'wake-1',
      turnIndex: 1,
    );

    final row = await insertAndReadRow(event);

    expect(ConsumptionDbConversions.fromRow(row), event);
  });
}
