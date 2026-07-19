import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart'
    as db;
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';

/// Blob-plus-projection conversions for AI attribution domain records.
class AttributionDbConversions {
  static db.AiWorkAttributionsCompanion attributionToCompanion(
    AiWorkAttribution attribution,
  ) {
    final output = attribution.primaryOutput;
    return db.AiWorkAttributionsCompanion(
      id: Value(attribution.id),
      workType: Value(attribution.workType.name),
      status: Value(attribution.status.name),
      initiatorType: Value(attribution.initiator.type.name),
      initiatorId: Value(attribution.initiator.id),
      initiatorDisplayName: Value(attribution.initiator.displayName),
      triggerType: Value(attribution.trigger.type.name),
      startedAt: Value(attribution.startedAt),
      completedAt: Value(attribution.completedAt),
      parentAttributionId: Value(attribution.parentAttributionId),
      taskId: Value(attribution.taskId),
      categoryId: Value(attribution.categoryId),
      primaryOutputType: Value(output?.type.name),
      primaryOutputId: Value(output?.id),
      primaryOutputSubId: Value(output?.subId),
      serialized: Value(jsonEncode(attribution.toJson())),
      schemaVersion: Value(attribution.schemaVersion),
    );
  }

  static AiWorkAttribution attributionFromRow(db.AiWorkAttribution row) =>
      AiWorkAttribution.fromJson(
        jsonDecode(row.serialized) as Map<String, dynamic>,
      );
}
