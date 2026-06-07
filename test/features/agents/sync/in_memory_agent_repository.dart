import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';

import '../../../mocks/mocks.dart';

/// A `MockAgentRepository` backed by in-memory maps so a real
/// `AgentSyncService` (its append path, input capture, and compaction) reads
/// and writes exactly as it would against the database — the only faithful way
/// to test that what these services *write* reads back through the projections.
///
/// Shared by the input-capture and log-compactor service tests.
class InMemoryAgentRepository extends MockAgentRepository {
  final Map<String, AgentDomainEntity> _entities = {};
  final Map<String, AgentLink> _links = {};
  final Map<String, int> _entityWrites = {};

  /// All stored entities (any type), for tests that need raw access.
  List<AgentDomainEntity> get entities => _entities.values.toList();

  /// How many times [upsertEntity] was called for [id] — lets tests prove a
  /// content-addressed write was skipped rather than idempotently repeated.
  int entityWriteCount(String id) => _entityWrites[id] ?? 0;

  List<AgentMessageEntity> get messages =>
      _entities.values.whereType<AgentMessageEntity>().toList();

  List<AgentLink> get links => _links.values.toList();

  List<MessagePayloadLink> get payloadLinks =>
      _links.values.whereType<MessagePayloadLink>().toList();

  List<AgentMessagePayloadEntity> get payloads =>
      _entities.values.whereType<AgentMessagePayloadEntity>().toList();

  void seed(Iterable<AgentDomainEntity> entities) {
    for (final entity in entities) {
      _entities[entity.id] = entity;
    }
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();

  @override
  Future<void> upsertEntity(AgentDomainEntity entity) async {
    _entityWrites[entity.id] = (_entityWrites[entity.id] ?? 0) + 1;
    _entities[entity.id] = entity;
  }

  @override
  Future<void> upsertLink(AgentLink link) async {
    _links[link.id] = link;
  }

  @override
  Future<AgentDomainEntity?> getEntity(String id) async => _entities[id];

  @override
  Future<AgentStateEntity?> getAgentState(String agentId) async {
    final states = _entities.values
        .whereType<AgentStateEntity>()
        .where((s) => s.agentId == agentId)
        .toList();
    return states.isEmpty ? null : states.single;
  }

  @override
  Future<List<AgentMessageEntity>> getAgentMessages(String agentId) async =>
      // Mirror the real query: soft-deleted messages are excluded.
      messages
          .where((m) => m.agentId == agentId && m.deletedAt == null)
          .toList();

  @override
  Future<List<AgentMessageEntity>> getMessagesByKind(
    String agentId,
    AgentMessageKind kind, {
    int? limit,
  }) async {
    // Mirror the real query: most-recent first, then apply the limit.
    final matching =
        messages
            .where(
              (m) =>
                  m.agentId == agentId && m.kind == kind && m.deletedAt == null,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit != null && limit >= 0 && matching.length > limit) {
      return matching.sublist(0, limit);
    }
    return matching;
  }

  @override
  Future<List<AgentLink>> getLinksFrom(String fromId, {String? type}) async =>
      _links.values
          .where(
            (l) =>
                l.fromId == fromId &&
                l.deletedAt == null &&
                (type == null || AgentDbConversions.linkType(l) == type),
          )
          .toList();

  @override
  Future<Map<String, List<AgentLink>>> getLinksFromMultiple(
    List<String> fromIds, {
    required String type,
  }) async {
    final ids = fromIds.toSet();
    final result = <String, List<AgentLink>>{};
    for (final link in _links.values) {
      if (ids.contains(link.fromId) &&
          link.deletedAt == null &&
          AgentDbConversions.linkType(link) == type) {
        (result[link.fromId] ??= []).add(link);
      }
    }
    return result;
  }
}
