import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';

/// Type mapping between Drift rows (`ConsumptionEvent`) and the Freezed
/// [AiConsumptionEvent] domain model.
///
/// `serialized` — the entity JSON, including `vectorClock` — is the source of
/// truth and round-trips losslessly. The typed columns are a denormalized
/// projection written on insert purely so aggregation queries never touch the
/// JSON blob; nothing reads them back into the domain model.
class ConsumptionDbConversions {
  /// Convert a Freezed [AiConsumptionEvent] to a Drift companion for upsert.
  static ConsumptionEventsCompanion toCompanion(AiConsumptionEvent event) {
    return ConsumptionEventsCompanion(
      id: Value(event.id),
      parentId: Value(event.parentId),
      createdAt: Value(event.createdAt),
      taskId: Value(event.taskId),
      categoryId: Value(event.categoryId),
      entryId: Value(event.entryId),
      agentId: Value(event.agentId),
      wakeRunKey: Value(event.wakeRunKey),
      threadId: Value(event.threadId),
      turnIndex: Value(event.turnIndex),
      promptId: Value(event.promptId),
      skillId: Value(event.skillId),
      configId: Value(event.configId),
      providerType: Value(event.providerType.name),
      modelId: Value(event.modelId),
      providerModelId: Value(event.providerModelId),
      responseType: Value(event.responseType.name),
      durationMs: Value(event.durationMs),
      inputTokens: Value(event.inputTokens),
      outputTokens: Value(event.outputTokens),
      cachedInputTokens: Value(event.cachedInputTokens),
      thoughtsTokens: Value(event.thoughtsTokens),
      totalTokens: Value(event.totalTokens),
      credits: Value(event.credits),
      energyKwh: Value(event.energyKwh),
      carbonGCo2: Value(event.carbonGCo2),
      waterLiters: Value(event.waterLiters),
      renewablePercent: Value(event.renewablePercent),
      pue: Value(event.pue),
      dataCenter: Value(event.dataCenter),
      upstreamProviderId: Value(event.upstreamProviderId),
      serialized: Value(jsonEncode(event.toJson())),
    );
  }

  /// Convert a Drift [ConsumptionEvent] row back to an [AiConsumptionEvent] by
  /// decoding the `serialized` blob (the projected columns are write-only).
  static AiConsumptionEvent fromRow(ConsumptionEvent row) {
    return AiConsumptionEvent.fromJson(
      jsonDecode(row.serialized) as Map<String, dynamic>,
    );
  }
}
