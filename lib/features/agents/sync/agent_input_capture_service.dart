import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_frontier.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:uuid/uuid.dart';

/// Captures the user-generated content a wake reads into the agent's
/// append-only log (ADR 0020), so the agent's inputs become a pure projection
/// of the log rather than a live read of the mutable journal.
///
/// This replaces the old "persist the whole assembled prompt as one blob per
/// wake" behaviour (ADR 0020's explicitly-rejected alternative) with per-source,
/// content-addressed snapshots that dedupe across wakes and agents and are
/// collapsed later by compaction (PR 5 / ADR 0017).
class AgentInputCaptureService {
  /// Creates the service over an [AgentSyncService] (used for both its
  /// sync-aware writes and its underlying repository reads).
  AgentInputCaptureService({required AgentSyncService syncService})
    : _sync = syncService;

  final AgentSyncService _sync;

  static const _uuid = Uuid();

  /// Owner `agentId` for content-addressed input payloads.
  ///
  /// Payloads dedupe by `contentDigest` **across agents** (ADR 0020 rule 2), so
  /// a payload is shared — it must not belong to whichever agent happened to
  /// capture it first. `hardDeleteAgent` cascades by `agent_id` (deletes the
  /// agent's entities *and any link pointing at them*), so an agent-owned shared
  /// payload would take other agents' references down with it on delete. A fixed
  /// sentinel owner (never a real agent id) keeps shared content global and
  /// untouched by per-agent deletion; each agent's own `messagePayload` links
  /// (`fromId == agentId`) are still deleted with it.
  static const sharedContentAgentId = 'shared-input-content';

  AgentRepository get _repository => _sync.repository;

  /// Captures the [sources] a wake rendered for [agentId], appending only the
  /// delta versus the agent's active input frontier (ADR 0020):
  ///
  /// - **content-addressed payloads** for new/changed content — skipping any
  ///   already stored, since a payload's id *is* its `contentDigest`, so
  ///   identical content is written once across wakes and agents;
  /// - **`messagePayload` reference links** (`agentId` → payload) carrying
  ///   provenance (`contentEntryId`) and canonical ordering (`sourceCreatedAt`);
  /// - **retraction events** (`system` messages tagged `retractsContentEntryId`)
  ///   for sources that vanished since the last capture — soft-retracting them
  ///   from active consideration while leaving the snapshots auditable.
  ///
  /// Returns the applied [CaptureDelta]. An empty delta — the common
  /// "re-wake with no content change" case — writes nothing and opens no
  /// transaction. [systemMessages] and [links] let a caller that already loaded
  /// them (e.g. alongside `reconciledAgentState`) avoid a second read.
  Future<CaptureDelta> captureWakeInputs({
    required String agentId,
    required List<RenderedSource> sources,
    required DateTime at,
    String? threadId,
    String? runKey,
    List<AgentMessageEntity>? systemMessages,
    List<AgentLink>? links,
  }) async {
    final messages =
        systemMessages ??
        await _repository.getMessagesByKind(agentId, AgentMessageKind.system);
    final agentLinks = links ?? await _repository.getLinksFrom(agentId);

    final delta = reconcileCapture(
      currentSources: sources,
      activeDigestByEntry: inputFrontierDigests(
        projectInputFrontier(messages: messages, links: agentLinks),
      ),
    );
    if (delta.isEmpty) return delta;

    await _sync.runInTransaction(() async {
      for (final payload in delta.newPayloads) {
        // The payload id is its content digest, so a present row is
        // byte-identical — skip the redundant write and its sync echo.
        if (await _repository.getEntity(payload.contentDigest) != null) {
          continue;
        }
        await _sync.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payload.contentDigest,
            // Shared owner, not `agentId` — see [sharedContentAgentId]: the
            // payload is content-addressed and deduped across agents, so it
            // must survive any single agent's hard delete.
            agentId: sharedContentAgentId,
            createdAt: at,
            vectorClock: null,
            content: payload.content,
          ),
        );
      }
      for (final reference in delta.newReferences) {
        await _sync.upsertLink(
          AgentLink.messagePayload(
            id: _uuid.v4(),
            fromId: agentId,
            toId: reference.contentDigest,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
            contentEntryId: reference.contentEntryId,
            sourceCreatedAt: reference.sourceCreatedAt,
          ),
        );
      }
      for (final entryId in delta.retractedEntryIds) {
        final id = _uuid.v4();
        await _sync.upsertEntity(
          AgentDomainEntity.agentMessage(
            id: id,
            agentId: agentId,
            threadId: threadId ?? id,
            kind: AgentMessageKind.system,
            createdAt: at,
            vectorClock: null,
            metadata: AgentMessageMetadata(
              runKey: runKey,
              retractsContentEntryId: entryId,
            ),
          ),
        );
      }
    });
    return delta;
  }
}
