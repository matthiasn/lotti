import 'dart:convert';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/projection/compaction_plan.dart';
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_frontier.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:uuid/uuid.dart';

/// Distills a set of folded input sources into summary prose, optionally
/// folding in the [priorSummary] it supersedes. Injected so the LLM dependency
/// lives at the edge and the compactor stays deterministically testable.
typedef AgentSummarizer =
    Future<String> Function({
      required List<RenderedSource> sources,
      String? priorSummary,
    });

/// Background compaction of an agent's captured input log (ADR 0017): when the
/// uncovered verbatim tail exceeds a token budget, fold its **oldest** sources
/// into an appended `summary` checkpoint.
///
/// The checkpoint is an append-only `summary` message pointing at a
/// content-addressed payload that records both the covered source set
/// (`contentEntryId` → digest) and the distilled text — so two devices that
/// summarize the same region dedupe, and the read side (`selectActiveSummary`)
/// picks the active checkpoint as a pure projection. The persisted pointers are
/// a cache; the log is authoritative.
class AgentLogCompactor {
  /// Creates the compactor over an [AgentSyncService] (used for both its
  /// sync-aware writes and its repository reads).
  AgentLogCompactor({required AgentSyncService syncService})
    : _sync = syncService;

  final AgentSyncService _sync;

  AgentRepository get _repository => _sync.repository;

  static const _uuid = Uuid();

  /// Loads the agent's materialized [SummaryCheckpoint]s from its `summary`
  /// messages — each points (via `contentEntryId`) at a payload holding the
  /// covered source set and the summary text.
  Future<List<SummaryCheckpoint>> loadSummaries(String agentId) async {
    final messages = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.summary,
    );
    final checkpoints = <SummaryCheckpoint>[];
    for (final message in messages) {
      if (message.deletedAt != null) continue;
      final payloadId = message.contentEntryId;
      if (payloadId == null) continue;
      final payload = await _repository.getEntity(payloadId);
      if (payload is! AgentMessagePayloadEntity) continue;
      final coveredRaw = payload.content['coveredSources'];
      checkpoints.add(
        SummaryCheckpoint(
          id: message.id,
          contentDigest: payloadId,
          coveredSources: <String, String>{
            if (coveredRaw is Map)
              for (final entry in coveredRaw.entries)
                entry.key.toString(): entry.value.toString(),
          },
          summaryText: payload.content['summaryText']?.toString() ?? '',
        ),
      );
    }
    return checkpoints;
  }

  /// Compacts [agentId] if its uncovered tail exceeds [budget] tokens, calling
  /// [summarize] to distill the folded sources. Returns the appended summary's
  /// id, or null when nothing needed folding (a pure read in that case — no
  /// writes, no outbox churn).
  Future<String?> maybeCompact({
    required String agentId,
    required int budget,
    required AgentSummarizer summarize,
    required DateTime at,
    String? threadId,
    String? runKey,
  }) async {
    final systemMessages = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.system,
    );
    final links = await _repository.getLinksFrom(agentId);
    final frontier = projectInputFrontier(
      messages: systemMessages,
      links: links,
    );
    if (frontier.isEmpty) return null;

    final summaries = await loadSummaries(agentId);
    final active = selectActiveSummary(
      frontier: inputFrontierDigests(frontier),
      summaries: summaries,
    );

    // The uncovered tail (sources not yet folded), with token costs, in
    // chronological assembly order.
    final uncovered = <_Uncovered>[];
    for (final entryId in active.uncoveredEntryIds) {
      final ref = frontier[entryId];
      if (ref == null) continue;
      final payload = await _repository.getEntity(ref.contentDigest);
      if (payload is! AgentMessagePayloadEntity) continue;
      uncovered.add(
        _Uncovered(
          source: RenderedSource(
            contentEntryId: entryId,
            sourceCreatedAt: ref.sourceCreatedAt,
            content: payload.content,
          ),
          digest: ref.contentDigest,
          tokens: TextChunker.estimateTokens(jsonEncode(payload.content)),
        ),
      );
    }
    uncovered.sort((a, b) {
      final byTime = a.source.sourceCreatedAt.compareTo(
        b.source.sourceCreatedAt,
      );
      if (byTime != 0) return byTime;
      return a.source.contentEntryId.compareTo(b.source.contentEntryId);
    });

    final plan = planCompaction(
      tail: [
        for (final entry in uncovered)
          TailEntry(id: entry.source.contentEntryId, tokens: entry.tokens),
      ],
      budget: budget,
    );
    if (!plan.shouldCompact) return null;

    final foldSet = plan.foldIds.toSet();
    final foldedSources = [
      for (final entry in uncovered)
        if (foldSet.contains(entry.source.contentEntryId)) entry.source,
    ];

    // The new checkpoint folds in the prior active checkpoint plus the freshly
    // folded sources (so coverage only ever grows along the trunk).
    final coveredSources = <String, String>{
      ...?active.checkpoint?.coveredSources,
      for (final entry in uncovered)
        if (foldSet.contains(entry.source.contentEntryId))
          entry.source.contentEntryId: entry.digest,
    };

    final summaryText = await summarize(
      sources: foldedSources,
      priorSummary: active.checkpoint?.summaryText,
    );

    final payloadContent = <String, Object?>{
      'coveredSources': coveredSources,
      'summaryText': summaryText,
    };
    final payloadId = ContentDigest.of(payloadContent);
    final summaryId = _uuid.v4();

    await _sync.runInTransaction(() async {
      if (await _repository.getEntity(payloadId) == null) {
        await _sync.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: payloadId,
            agentId: agentId,
            createdAt: at,
            vectorClock: null,
            content: payloadContent,
          ),
        );
      }
      await _sync.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: summaryId,
          agentId: agentId,
          threadId: threadId ?? summaryId,
          kind: AgentMessageKind.summary,
          createdAt: at,
          vectorClock: null,
          contentEntryId: payloadId,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    });
    return summaryId;
  }
}

class _Uncovered {
  const _Uncovered({
    required this.source,
    required this.digest,
    required this.tokens,
  });

  final RenderedSource source;
  final String digest;
  final int tokens;
}
