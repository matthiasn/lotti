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
      executorHostId: Value(attribution.executor.hostId),
      privacyClassification: Value(attribution.privacyClassification.name),
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

  static db.AiAttributionLinksCompanion linkToCompanion(
    AiAttributionLink link,
  ) {
    return db.AiAttributionLinksCompanion(
      id: Value(link.id),
      attributionId: Value(link.attributionId),
      role: Value(link.role.name),
      artifactType: Value(link.artifact.type.name),
      artifactId: Value(link.artifact.id),
      subId: Value(link.artifact.subId),
      contentDigest: Value(link.contentDigest),
      serialized: Value(jsonEncode(link.toJson())),
    );
  }

  static db.AiInteractionPayloadsCompanion payloadToCompanion(
    AiInteractionPayload payload,
  ) {
    return db.AiInteractionPayloadsCompanion(
      id: Value(payload.id),
      interactionId: Value(payload.interactionId),
      capturePolicy: Value(payload.capturePolicy.name),
      privacyClassification: Value(payload.privacyClassification.name),
      requestDigest: Value(payload.requestDigest),
      responseDigest: Value(payload.responseDigest),
      serialized: Value(jsonEncode(payload.toJson())),
    );
  }

  static AiInteractionPayload payloadFromRow(db.AiInteractionPayload row) =>
      AiInteractionPayload.fromJson(
        jsonDecode(row.serialized) as Map<String, dynamic>,
      );

  static db.AiInteractionCostsCompanion costToCompanion(
    AiInteractionCost cost,
  ) {
    return db.AiInteractionCostsCompanion(
      id: Value(cost.id),
      interactionId: Value(cost.interactionId),
      source: Value(cost.source.name),
      originalAmountDecimal: Value(cost.originalAmountDecimal),
      originalUnit: Value(cost.originalUnit),
      reportingAmountMicros: Value(cost.reportingAmountMicros),
      reportingCurrency: Value(cost.reportingCurrency),
      providerType: Value(cost.providerType),
      billingAccountKey: Value(cost.billingAccountKey),
      billingSource: Value(cost.billingSource),
      externalRecordId: Value(cost.externalRecordId),
      supersedesCostId: Value(cost.supersedesCostId),
      assessedAt: Value(cost.assessedAt),
      pricingSnapshot: Value(
        cost.pricingSnapshot == null ? null : jsonEncode(cost.pricingSnapshot),
      ),
      serialized: Value(jsonEncode(cost.toJson())),
    );
  }

  static AiInteractionCost costFromRow(db.AiInteractionCost row) =>
      AiInteractionCost.fromJson(
        jsonDecode(row.serialized) as Map<String, dynamic>,
      );

  static db.PendingAiAttributionsCompanion pendingToCompanion(
    AiAttributionPendingSession pending,
  ) {
    return db.PendingAiAttributionsCompanion(
      id: Value(pending.id),
      startedAt: Value(pending.startedAt),
      lastUpdatedAt: Value(pending.lastUpdatedAt),
      serialized: Value(jsonEncode(pending.toJson())),
    );
  }

  static AiAttributionPendingSession pendingFromRow(
    db.PendingAiAttribution row,
  ) => AiAttributionPendingSession.fromJson(
    jsonDecode(row.serialized) as Map<String, dynamic>,
  );
}
