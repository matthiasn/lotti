import 'package:lotti/features/agents/database/agent_repository.dart'
    show AgentRepository;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';

/// Shared internal constants and pure helpers for the [AgentRepository]
/// collaborators in this directory. These were previously top-level privates
/// in `agent_repository.dart` when the repository was assembled from `part`
/// mixins; they now live in one place so every collaborator class can reuse
/// them without re-declaring or duplicating logic.

/// Over-fetch factor applied when a query must filter in Dart after the SQL
/// `LIMIT` (e.g. taskId filtering on the serialized JSON column), so the post
/// filter still has enough rows to satisfy the requested limit.
const int overFetchMultiplier = 5;

bool affectsAttentionClaimProjection(AgentDomainEntity entity) {
  return entity is AttentionRequestEntity ||
      entity is AttentionClaimDispositionEntity;
}

bool affectsStandingAgreementProjection(AgentDomainEntity entity) {
  return entity is StandingAgreementEntity;
}

/// SQLite's default `SQLITE_MAX_VARIABLE_NUMBER` is 999; we chunk batched
/// `IN (...)` queries below this to stay safe across builds.
const int sqliteInClauseChunkSize = 900;

/// Dedup-and-chunk iterator that guards every batched `IN (...)` query against
/// SQLite's host-variable cap. Deduplicates first so callers never emit a
/// chunk larger than [sqliteInClauseChunkSize].
Iterable<List<T>> sqliteInClauseChunks<T>(Iterable<T> values) sync* {
  final valueList = values.toSet().toList(growable: false);
  for (
    var start = 0;
    start < valueList.length;
    start += sqliteInClauseChunkSize
  ) {
    final end = start + sqliteInClauseChunkSize > valueList.length
        ? valueList.length
        : start + sqliteInClauseChunkSize;
    yield valueList.sublist(start, end);
  }
}
