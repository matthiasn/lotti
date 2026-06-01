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
      messages.where((m) => m.agentId == agentId).toList();

  @override
  Future<List<AgentMessageEntity>> getMessagesByKind(
    String agentId,
    AgentMessageKind kind, {
    int? limit,
  }) async => messages
      .where(
        (m) => m.agentId == agentId && m.kind == kind && m.deletedAt == null,
      )
      .toList();

  @override
  Future<List<AgentLink>> getLinksFrom(String fromId, {String? type}) async =>
      _links.values
          .where((l) => l.fromId == fromId && l.deletedAt == null)
          .toList();
}
