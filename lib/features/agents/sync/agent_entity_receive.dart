import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_message_dag.dart';

/// What a replica does with one received agent entity: the version it holds
/// under the id (`stored`, a tombstone included, or `null` when it holds
/// none) and the row to write in its place (`toWrite`, or `null` when
/// `stored` stands).
typedef AgentEntityReceipt = ({
  AgentDomainEntity? stored,
  AgentDomainEntity? toWrite,
});

/// Resolves a received agent entity against the stored version of its id.
///
/// The stored version is read with its tombstone
/// ([AgentRepository.getEntityIncludingDeleted]): a removal is a version
/// like any other. Read as no row, as `getEntity` reads it, any version that
/// arrived after a removal — a late copy of the live entity from a peer, a
/// backfill answer, a message delayed in transit — replaced it, and the
/// removed entity came back (ADR 0081, addendum;
/// `specs/tla/AgentReplication.tla`, the removal kind).
///
/// The decision is [resolveAgentEntityVersions]; for two agent-state rows
/// whose heads differ, the order of the heads in the local message DAG is
/// read first ([AgentMessageDag.ancestryOf]), so the merge keeps the head
/// that descends from the other (ADR 0076). A clock the resolver cannot
/// compare is reported to [onMalformedClock], and [incoming] is written.
///
/// Must run inside the transaction that writes the receipt's `toWrite`:
/// a local write that committed between this read and that write would be
/// overwritten. `SyncEventProcessor` is the caller; the multi-device test
/// harness receives through it too.
Future<AgentEntityReceipt> resolveReceivedAgentEntity(
  AgentRepository repository,
  AgentDomainEntity incoming, {
  required void Function(Object error, StackTrace stackTrace) onMalformedClock,
}) async {
  final stored = await repository.getEntityIncludingDeleted(incoming.id);
  if (stored == null) return (stored: null, toWrite: incoming);
  final isAncestor = stored is AgentStateEntity && incoming is AgentStateEntity
      ? await AgentMessageDag(repository).ancestryOf(
          stored.recentHeadMessageId,
          incoming.recentHeadMessageId,
        )
      : noKnownAncestry;
  final AgentDomainEntity resolved;
  try {
    resolved = resolveAgentEntityVersions(
      local: stored,
      incoming: incoming,
      isAncestor: isAncestor,
    );
  } catch (error, stackTrace) {
    onMalformedClock(error, stackTrace);
    return (stored: stored, toWrite: incoming);
  }
  return (
    stored: stored,
    toWrite: identical(resolved, stored) ? null : resolved,
  );
}
