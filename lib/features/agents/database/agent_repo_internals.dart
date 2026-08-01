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

/// Chunk size for batched `IN (...)` queries.
///
/// `SQLITE_MAX_VARIABLE_NUMBER` was 999 before SQLite 3.32 and is 32766 after
/// it — the bundled library is 3.45, so the real cap is the higher one and 900
/// is far below it. The conservative chunk stays because it also bounds result
/// size and statement-cache churn, and because the ceiling is a build-time
/// option we do not control on every platform.
const int sqliteInClauseChunkSize = 900;

/// Dedup-and-chunk iterator that guards every batched `IN (...)` query against
/// SQLite's host-variable cap. Deduplicates first so callers never emit a
/// chunk larger than [sqliteInClauseChunkSize].
///
/// [reserve] is the number of host variables the caller binds *in addition* to
/// one per chunk element — a type discriminator, a subtype, a second `IN` list
/// in the same statement. The chunk shrinks to make room for them, because the
/// cap applies to the whole statement rather than to one `IN` list, and so does
/// [sqliteInClauseChunkSize]'s intent: a caller binding a large extra list
/// would otherwise silently produce statements far wider than the chunk size
/// implies.
Iterable<List<T>> sqliteInClauseChunks<T>(
  Iterable<T> values, {
  int reserve = 0,
}) sync* {
  final valueList = values.toSet().toList(growable: false);
  // Always leave room for at least one element per chunk, otherwise a caller
  // reserving more than the chunk size would loop forever.
  final chunkSize = (sqliteInClauseChunkSize - reserve).clamp(
    1,
    sqliteInClauseChunkSize,
  );
  for (var start = 0; start < valueList.length; start += chunkSize) {
    final end = start + chunkSize > valueList.length
        ? valueList.length
        : start + chunkSize;
    yield valueList.sublist(start, end);
  }
}
