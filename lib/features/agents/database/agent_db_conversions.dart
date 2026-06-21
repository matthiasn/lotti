import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;

/// Type mapping layer between Drift DB rows and Freezed models for the agent
/// domain.
///
/// Immutable variants (agentMessage, agentMessagePayload, agentReport, unknown)
/// do not carry an `updatedAt` field in their Dart model. For those variants,
/// [entityUpdatedAt] returns `createdAt` so that the `updated_at` column is
/// always populated consistently on write.
class AgentDbConversions {
  // ── entity ────────────────────────────────────────────────────────────────

  /// Convert a Freezed [AgentDomainEntity] to a Drift companion for upsert.
  static AgentEntitiesCompanion toEntityCompanion(AgentDomainEntity entity) {
    final subtype = entitySubtype(entity);
    final deletedAt = entity.map(
      agent: (e) => e.deletedAt,
      agentState: (e) => e.deletedAt,
      agentMessage: (e) => e.deletedAt,
      agentMessagePayload: (e) => e.deletedAt,
      agentReport: (e) => e.deletedAt,
      agentReportHead: (e) => e.deletedAt,
      scheduledWake: (e) => e.deletedAt,
      plannerKnowledge: (e) => e.deletedAt,
      capture: (e) => e.deletedAt,
      parsedItem: (e) => e.deletedAt,
      dayPlan: (e) => e.deletedAt,
      daySummary: (e) => e.deletedAt,
      attentionRequest: (e) => e.deletedAt,
      attentionClaimDisposition: (e) => e.deletedAt,
      attentionAward: (e) => e.deletedAt,
      standingAgreement: (e) => e.deletedAt,
      projectRecommendation: (e) => e.deletedAt,
      agentTemplate: (e) => e.deletedAt,
      agentTemplateVersion: (e) => e.deletedAt,
      agentTemplateHead: (e) => e.deletedAt,
      evolutionSession: (e) => e.deletedAt,
      evolutionSessionRecap: (e) => e.deletedAt,
      evolutionNote: (e) => e.deletedAt,
      changeSet: (e) => e.deletedAt,
      changeDecision: (e) => e.deletedAt,
      wakeTokenUsage: (e) => e.deletedAt,
      soulDocument: (e) => e.deletedAt,
      soulDocumentVersion: (e) => e.deletedAt,
      soulDocumentHead: (e) => e.deletedAt,
      unknown: (e) => e.deletedAt,
    );

    final threadId = entity.mapOrNull(
      agentMessage: (m) => m.threadId,
      agentReport: (r) => r.threadId,
      changeSet: (c) => c.threadId,
      wakeTokenUsage: (e) => e.threadId,
    );

    final json = entity.toJson();
    _addLegacyCounterMirrors(entity, json);

    return AgentEntitiesCompanion(
      id: Value(entity.id),
      agentId: Value(entity.agentId),
      type: Value(entityType(entity)),
      subtype: subtype != null ? Value(subtype) : const Value<String?>.absent(),
      threadId: threadId != null
          ? Value(threadId)
          : const Value<String?>.absent(),
      createdAt: Value(entityCreatedAt(entity)),
      updatedAt: Value(entityUpdatedAt(entity)),
      deletedAt: Value(deletedAt),
      serialized: Value(jsonEncode(json)),
    );
  }

  /// Dual-write back-compat for the int → per-host G-counter migration:
  /// alongside the `*ByHost` maps that `toJson` already emits, also write the
  /// legacy scalar keys (= each counter's summed `value`) so a device still on
  /// the pre-G-counter build keeps reading a sane integer instead of seeing the
  /// field absent (→ 0). The mirror keys are dropped a release after the
  /// rollout. Only `AgentStateEntity` carries them.
  static void _addLegacyCounterMirrors(
    AgentDomainEntity entity,
    Map<String, dynamic> json,
  ) {
    if (entity is! AgentStateEntity) return;
    json['wakeCounter'] = entity.wakeCounter.value;
    // `toJson` is implicit-to-json: nested values remain Dart objects (not maps)
    // until `jsonEncode` recurses, so `json['slots']` is an AgentSlots, not a
    // mutable map. Replace it with the slots' own json plus the mirror keys.
    json['slots'] = entity.slots.toJson()
      ..['totalSessionsCompleted'] = entity.slots.totalSessionsCompleted.value
      ..['weeklyReviewCount'] = entity.slots.weeklyReviewCount.value;
  }

  /// Convert a Drift [AgentEntity] row back to a Freezed [AgentDomainEntity].
  ///
  /// Applies forward-migration fixups for schema changes that occurred before
  /// the schema_version column was actively bumped:
  /// - `agentReport.content`: migrated from `Map<String, Object?>` → `String`.
  /// - `AgentStateEntity` counters: legacy scalar `wakeCounter` /
  ///   `totalSessionsCompleted` / `weeklyReviewCount` seeded into their per-host
  ///   `*ByHost` G-counter maps (see [_migrateGCounters]).
  static AgentDomainEntity fromEntityRow(AgentEntity row) {
    final json = jsonDecode(row.serialized) as Map<String, dynamic>;
    _migrateReportContent(json);
    _migrateGCounters(json);
    return AgentDomainEntity.fromJson(json);
  }

  /// If [json] is an `agentReport` whose `content` is still a Map (pre-migration
  /// format), replace it with the `markdown` value from that map (or the first
  /// string value, falling back to an empty string).
  static void _migrateReportContent(Map<String, dynamic> json) {
    if (json['runtimeType'] != 'agentReport') return;
    final content = json['content'];
    if (content is Map) {
      json['content'] =
          (content['markdown'] ?? content.values.firstOrNull ?? '').toString();
    }
  }

  /// The host the pre-G-counter legacy scalar is seeded under. Fixed and shared
  /// across devices: `wakeCounter` etc. were single synced ints that LWW-
  /// converged to one value `n` everywhere, so seeding each device's scalar under
  /// *its own* host would element-wise-max-merge to `N·n` (overcount). One shared
  /// key makes the merge `max(n, …) = n` and preserves the value; forward per-
  /// host increments are never lost.
  static const preGCounterSentinelHost = '__pre_gcounter__';

  /// Read-side back-compat for the int → per-host G-counter migration. A
  /// pre-G-counter row — or a write from a device still on the old build —
  /// stores these counters as plain integers under their legacy keys. Seed the
  /// `*ByHost` map from that scalar (under [preGCounterSentinelHost]). When the
  /// `*ByHost` map is already present (a new-client write), the legacy scalar
  /// mirror is ignored. Only `AgentStateEntity` carries these counters.
  static void _migrateGCounters(Map<String, dynamic> json) {
    if (json['runtimeType'] != 'agentState') return;
    _seedGCounter(json, 'wakeCounterByHost', 'wakeCounter');
    final slots = json['slots'];
    if (slots is Map<String, dynamic>) {
      _seedGCounter(
        slots,
        'totalSessionsCompletedByHost',
        'totalSessionsCompleted',
      );
      _seedGCounter(slots, 'weeklyReviewCountByHost', 'weeklyReviewCount');
    }
  }

  /// Seeds [byHostKey] from a legacy numeric [legacyKey] under the sentinel host,
  /// unless the per-host map is already present.
  static void _seedGCounter(
    Map<String, dynamic> json,
    String byHostKey,
    String legacyKey,
  ) {
    if (json[byHostKey] != null) return;
    final legacy = json[legacyKey];
    if (legacy is num) {
      json[byHostKey] = <String, dynamic>{
        preGCounterSentinelHost: legacy.toInt(),
      };
    }
  }

  // ── link ──────────────────────────────────────────────────────────────────

  /// Convert a Freezed [model.AgentLink] to a Drift companion for upsert.
  static AgentLinksCompanion toLinkCompanion(model.AgentLink link) {
    final deletedAt = link.map(
      basic: (l) => l.deletedAt,
      agentState: (l) => l.deletedAt,
      messagePrev: (l) => l.deletedAt,
      messagePayload: (l) => l.deletedAt,
      toolEffect: (l) => l.deletedAt,
      agentTask: (l) => l.deletedAt,
      captureToParsedItem: (l) => l.deletedAt,
      parsedItemToTask: (l) => l.deletedAt,
      captureToPlan: (l) => l.deletedAt,
      attentionRequestEvidence: (l) => l.deletedAt,
      attentionAwardRequest: (l) => l.deletedAt,
      attentionAwardPlan: (l) => l.deletedAt,
      templateAssignment: (l) => l.deletedAt,
      improverTarget: (l) => l.deletedAt,
      agentProject: (l) => l.deletedAt,
      agentEvent: (l) => l.deletedAt,
      agentDay: (l) => l.deletedAt,
      soulAssignment: (l) => l.deletedAt,
    );

    return AgentLinksCompanion(
      id: Value(link.id),
      fromId: Value(link.fromId),
      toId: Value(link.toId),
      type: Value(linkType(link)),
      createdAt: Value(link.createdAt),
      updatedAt: Value(link.updatedAt),
      deletedAt: Value(deletedAt),
      serialized: Value(jsonEncode(link.toJson())),
    );
  }

  /// Convert a Drift [AgentLink] row back to a Freezed [model.AgentLink].
  static model.AgentLink fromLinkRow(AgentLink row) {
    return model.AgentLink.fromJson(
      jsonDecode(row.serialized) as Map<String, dynamic>,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Extract the type string for the `agent_entities.type` column.
  static String entityType(AgentDomainEntity entity) {
    return entity.map(
      agent: (_) => 'agent',
      agentState: (_) => 'agentState',
      agentMessage: (_) => 'agentMessage',
      agentMessagePayload: (_) => 'agentMessagePayload',
      agentReport: (_) => 'agentReport',
      agentReportHead: (_) => 'agentReportHead',
      scheduledWake: (_) => AgentEntityTypes.scheduledWake,
      plannerKnowledge: (_) => AgentEntityTypes.plannerKnowledge,
      capture: (_) => AgentEntityTypes.capture,
      parsedItem: (_) => AgentEntityTypes.parsedItem,
      dayPlan: (_) => AgentEntityTypes.dayPlan,
      daySummary: (_) => AgentEntityTypes.daySummary,
      attentionRequest: (_) => AgentEntityTypes.attentionRequest,
      attentionClaimDisposition: (_) =>
          AgentEntityTypes.attentionClaimDisposition,
      attentionAward: (_) => AgentEntityTypes.attentionAward,
      standingAgreement: (_) => AgentEntityTypes.standingAgreement,
      projectRecommendation: (_) => AgentEntityTypes.projectRecommendation,
      agentTemplate: (_) => 'agentTemplate',
      agentTemplateVersion: (_) => 'agentTemplateVersion',
      agentTemplateHead: (_) => 'agentTemplateHead',
      evolutionSession: (_) => 'evolutionSession',
      evolutionSessionRecap: (_) => AgentEntityTypes.evolutionSessionRecap,
      evolutionNote: (_) => 'evolutionNote',
      changeSet: (_) => 'changeSet',
      changeDecision: (_) => 'changeDecision',
      wakeTokenUsage: (_) => 'wakeTokenUsage',
      soulDocument: (_) => AgentEntityTypes.soulDocument,
      soulDocumentVersion: (_) => AgentEntityTypes.soulDocumentVersion,
      soulDocumentHead: (_) => AgentEntityTypes.soulDocumentHead,
      unknown: (_) => 'unknown',
    );
  }

  /// Extract the subtype for the `agent_entities.subtype` column.
  ///
  /// Populates the subtype for variants that have a natural sub-classification,
  /// enabling indexed lookups via `idx_agent_entities_agent_type_sub`.
  static String? entitySubtype(AgentDomainEntity entity) {
    return entity.mapOrNull(
      agent: (a) => a.kind,
      agentMessage: (msg) => msg.kind.name,
      agentReport: (report) => report.scope,
      agentReportHead: (head) => head.scope,
      scheduledWake: (wake) => wake.status.name,
      plannerKnowledge: (k) => k.key,
      capture: (capture) => capture.id,
      parsedItem: (item) => item.kind.name,
      dayPlan: (plan) => plan.dayId,
      daySummary: (e) => e.dayId,
      attentionRequest: (request) => request.scopeKind.name,
      attentionClaimDisposition: (disposition) => disposition.requestId,
      attentionAward: (award) => award.dayId,
      standingAgreement: (agreement) => agreement.scope.name,
      projectRecommendation: (recommendation) => recommendation.status.name,
      agentTemplate: (t) => t.kind.name,
      agentTemplateVersion: (v) => v.status.name,
      evolutionSession: (s) => s.status.name,
      evolutionNote: (n) => n.kind.name,
      changeSet: (c) => c.status.name,
      changeDecision: (d) => d.verdict.name,
      soulDocumentVersion: (v) => v.status.name,
    );
  }

  /// Determine the `created_at` value to write for an entity row.
  ///
  /// Variants that do not carry a `createdAt` field ([AgentStateEntity],
  /// [AgentReportHeadEntity]) fall back to `updatedAt`, which is the closest
  /// equivalent timestamp available.
  static DateTime entityCreatedAt(AgentDomainEntity entity) {
    return entity.map(
      agent: (e) => e.createdAt,
      agentState: (e) => e.updatedAt,
      agentMessage: (e) => e.createdAt,
      agentMessagePayload: (e) => e.createdAt,
      agentReport: (e) => e.createdAt,
      agentReportHead: (e) => e.updatedAt,
      scheduledWake: (e) => e.updatedAt,
      plannerKnowledge: (e) => e.createdAt,
      capture: (e) => e.createdAt,
      parsedItem: (e) => e.createdAt,
      dayPlan: (e) => e.createdAt,
      daySummary: (e) => e.createdAt,
      attentionRequest: (e) => e.createdAt,
      attentionClaimDisposition: (e) => e.createdAt,
      attentionAward: (e) => e.createdAt,
      standingAgreement: (e) => e.createdAt,
      projectRecommendation: (e) => e.createdAt,
      agentTemplate: (e) => e.createdAt,
      agentTemplateVersion: (e) => e.createdAt,
      agentTemplateHead: (e) => e.updatedAt,
      evolutionSession: (e) => e.createdAt,
      evolutionSessionRecap: (e) => e.createdAt,
      evolutionNote: (e) => e.createdAt,
      changeSet: (e) => e.createdAt,
      changeDecision: (e) => e.createdAt,
      wakeTokenUsage: (e) => e.createdAt,
      soulDocument: (e) => e.createdAt,
      soulDocumentVersion: (e) => e.createdAt,
      soulDocumentHead: (e) => e.updatedAt,
      unknown: (e) => e.createdAt,
    );
  }

  /// Determine the `updated_at` value to write for an entity row.
  ///
  /// Immutable variants (agentMessage, agentMessagePayload, agentReport,
  /// agentTemplateVersion, unknown) have no `updatedAt` field, so `createdAt`
  /// is used instead to satisfy the NOT NULL constraint.
  static DateTime entityUpdatedAt(AgentDomainEntity entity) {
    return entity.map(
      agent: (e) => e.updatedAt,
      agentState: (e) => e.updatedAt,
      agentMessage: (e) => e.createdAt,
      agentMessagePayload: (e) => e.createdAt,
      agentReport: (e) => e.createdAt,
      agentReportHead: (e) => e.updatedAt,
      scheduledWake: (e) => e.updatedAt,
      plannerKnowledge: (e) => e.updatedAt,
      capture: (e) => e.createdAt,
      parsedItem: (e) => e.createdAt,
      dayPlan: (e) => e.updatedAt,
      daySummary: (e) => e.updatedAt,
      attentionRequest: (e) => e.createdAt,
      attentionClaimDisposition: (e) => e.createdAt,
      attentionAward: (e) => e.createdAt,
      standingAgreement: (e) => e.updatedAt,
      projectRecommendation: (e) => e.updatedAt,
      agentTemplate: (e) => e.updatedAt,
      agentTemplateVersion: (e) => e.createdAt,
      agentTemplateHead: (e) => e.updatedAt,
      evolutionSession: (e) => e.updatedAt,
      evolutionSessionRecap: (e) => e.createdAt,
      evolutionNote: (e) => e.createdAt,
      changeSet: (e) => e.resolvedAt ?? e.createdAt,
      changeDecision: (e) => e.createdAt,
      wakeTokenUsage: (e) => e.createdAt,
      soulDocument: (e) => e.updatedAt,
      soulDocumentVersion: (e) => e.createdAt,
      soulDocumentHead: (e) => e.updatedAt,
      unknown: (e) => e.createdAt,
    );
  }

  /// Extract the type string for the `agent_links.type` column.
  static String linkType(model.AgentLink link) {
    return link.map(
      basic: (_) => AgentLinkTypes.basic,
      agentState: (_) => AgentLinkTypes.agentState,
      messagePrev: (_) => AgentLinkTypes.messagePrev,
      messagePayload: (_) => AgentLinkTypes.messagePayload,
      toolEffect: (_) => AgentLinkTypes.toolEffect,
      agentTask: (_) => AgentLinkTypes.agentTask,
      captureToParsedItem: (_) => AgentLinkTypes.captureToParsedItem,
      parsedItemToTask: (_) => AgentLinkTypes.parsedItemToTask,
      captureToPlan: (_) => AgentLinkTypes.captureToPlan,
      attentionRequestEvidence: (_) => AgentLinkTypes.attentionRequestEvidence,
      attentionAwardRequest: (_) => AgentLinkTypes.attentionAwardRequest,
      attentionAwardPlan: (_) => AgentLinkTypes.attentionAwardPlan,
      templateAssignment: (_) => AgentLinkTypes.templateAssignment,
      improverTarget: (_) => AgentLinkTypes.improverTarget,
      agentProject: (_) => AgentLinkTypes.agentProject,
      agentEvent: (_) => AgentLinkTypes.agentEvent,
      agentDay: (_) => AgentLinkTypes.agentDay,
      soulAssignment: (_) => AgentLinkTypes.soulAssignment,
    );
  }
}
