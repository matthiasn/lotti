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
      agentTemplate: (e) => e.deletedAt,
      agentTemplateVersion: (e) => e.deletedAt,
      agentTemplateHead: (e) => e.deletedAt,
      evolutionSession: (e) => e.deletedAt,
      evolutionNote: (e) => e.deletedAt,
      unknown: (e) => e.deletedAt,
    );

    final threadId = entity.mapOrNull(
      agentMessage: (m) => m.threadId,
      agentReport: (r) => r.threadId,
    );

    return AgentEntitiesCompanion(
      id: Value(entity.id),
      agentId: Value(entity.agentId),
      type: Value(entityType(entity)),
      subtype: subtype != null ? Value(subtype) : const Value<String?>.absent(),
      threadId:
          threadId != null ? Value(threadId) : const Value<String?>.absent(),
      createdAt: Value(entityCreatedAt(entity)),
      updatedAt: Value(entityUpdatedAt(entity)),
      deletedAt: Value(deletedAt),
      serialized: Value(jsonEncode(entity.toJson())),
    );
  }

  /// Convert a Drift [AgentEntity] row back to a Freezed [AgentDomainEntity].
  ///
  /// Applies forward-migration fixups for schema changes that occurred before
  /// the schema_version column was actively bumped:
  /// - `agentReport.content`: migrated from `Map<String, Object?>` → `String`.
  static AgentDomainEntity fromEntityRow(AgentEntity row) {
    final json = jsonDecode(row.serialized) as Map<String, dynamic>;
    _migrateReportContent(json);
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
      templateAssignment: (l) => l.deletedAt,
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
      agentTemplate: (_) => 'agentTemplate',
      agentTemplateVersion: (_) => 'agentTemplateVersion',
      agentTemplateHead: (_) => 'agentTemplateHead',
      evolutionSession: (_) => 'evolutionSession',
      evolutionNote: (_) => 'evolutionNote',
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
      agentTemplate: (t) => t.kind.name,
      agentTemplateVersion: (v) => v.status.name,
      evolutionSession: (s) => s.status.name,
      evolutionNote: (n) => n.kind.name,
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
      agentTemplate: (e) => e.createdAt,
      agentTemplateVersion: (e) => e.createdAt,
      agentTemplateHead: (e) => e.updatedAt,
      evolutionSession: (e) => e.createdAt,
      evolutionNote: (e) => e.createdAt,
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
      agentTemplate: (e) => e.updatedAt,
      agentTemplateVersion: (e) => e.createdAt,
      agentTemplateHead: (e) => e.updatedAt,
      evolutionSession: (e) => e.updatedAt,
      evolutionNote: (e) => e.createdAt,
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
      templateAssignment: (_) => AgentLinkTypes.templateAssignment,
    );
  }
}
