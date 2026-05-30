import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Last-writer-wins timestamp source for [AgentDomainEntity].
extension AgentDomainEntityLwwTimestamp on AgentDomainEntity {
  /// The timestamp used for last-writer-wins comparison: the entity's
  /// `updatedAt` when its variant has one, otherwise its `createdAt`.
  ///
  /// The union has no field common to every variant — mutable variants
  /// (identity, state, heads, templates…) carry `updatedAt`, while append-only
  /// variants (messages, payloads, reports, observations…) carry only
  /// `createdAt`. Reading from the serialized form handles every current and
  /// future variant without a per-variant `switch`; both fields serialize as
  /// ISO-8601 strings, and every variant defines at least one of them.
  DateTime get effectiveUpdatedAt {
    final json = toJson();
    final raw = (json['updatedAt'] ?? json['createdAt']) as String;
    return DateTime.parse(raw);
  }
}
