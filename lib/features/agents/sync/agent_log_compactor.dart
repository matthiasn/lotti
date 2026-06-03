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
    final live = [
      for (final m in messages)
        if (m.deletedAt == null && m.contentEntryId != null) m,
    ];
    // Load every checkpoint payload concurrently (avoids an N+1 per summary).
    final payloads = await Future.wait(
      live.map((m) => _repository.getEntity(m.contentEntryId!)),
    );

    final checkpoints = <SummaryCheckpoint>[];
    for (var i = 0; i < live.length; i++) {
      final payload = payloads[i];
      if (payload is! AgentMessagePayloadEntity) continue;
      final coveredRaw = payload.content['coveredSources'];
      checkpoints.add(
        SummaryCheckpoint(
          id: live[i].id,
          contentDigest: live[i].contentEntryId!,
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

  /// Loads the payloads for [entryIds] from [frontier] **concurrently**,
  /// preserving the given order and dropping any whose payload is missing.
  Future<List<({CaptureReference ref, AgentMessagePayloadEntity payload})>>
  _loadFrontierSources(
    Map<String, CaptureReference> frontier,
    List<String> entryIds,
  ) async {
    final refs = [
      for (final entryId in entryIds)
        if (frontier[entryId] != null) frontier[entryId]!,
    ];
    final payloads = await Future.wait(
      refs.map((ref) => _repository.getEntity(ref.contentDigest)),
    );
    final result =
        <({CaptureReference ref, AgentMessagePayloadEntity payload})>[];
    for (var i = 0; i < refs.length; i++) {
      final payload = payloads[i];
      if (payload is AgentMessagePayloadEntity) {
        result.add((ref: refs[i], payload: payload));
      }
    }
    return result;
  }

  /// Assembles the read-side compacted task log for [agentId] (ADR 0017
  /// Decision 6): the active summary's prose followed by the uncovered verbatim
  /// tail, in canonical assembly order. Returns the empty string when the agent
  /// has no captured input yet. Pure read — no writes.
  Future<String> assembleContext(String agentId) async {
    final systemMessages = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.system,
    );
    final links = await _repository.getLinksFrom(agentId);
    final frontier = projectInputFrontier(
      messages: systemMessages,
      links: links,
    );
    if (frontier.isEmpty) return '';

    final active = selectActiveSummary(
      frontier: inputFrontierDigests(frontier),
      summaries: await loadSummaries(agentId),
    );

    final tail = [
      for (final loaded in await _loadFrontierSources(
        frontier,
        active.uncoveredEntryIds,
      ))
        RenderedSource(
          contentEntryId: loaded.ref.contentEntryId,
          sourceCreatedAt: loaded.ref.sourceCreatedAt,
          content: loaded.payload.content,
        ),
    ]..sort(_byChrono);

    return assembleCompactedTaskLog(
      summaryText: active.checkpoint?.summaryText,
      tail: tail,
    );
  }

  /// Compacts [agentId] if its uncovered tail exceeds [budget] tokens, calling
  /// [summarize] to distill the folded sources. Returns the appended summary's
  /// id, or null when nothing needed folding (a pure read in that case — no
  /// writes, no outbox churn).
  ///
  /// **Hysteresis.** [budget] is the *trigger* (high watermark): nothing happens
  /// while the tail fits it. Once exceeded, the fold goes *deeper* — down to
  /// [retainTokens] (low watermark) of most-recent verbatim content — so the
  /// next `budget - retainTokens` tokens of new activity arrive without another
  /// summarization. Folding only back to [budget] would leave the tail at the
  /// boundary, re-summarizing (and churning the cache-stable summary block in
  /// the prompt prefix) on nearly every subsequent wake. When [retainTokens] is
  /// null or `>= budget`, the fold stops at [budget] (the pre-hysteresis
  /// behaviour).
  Future<String?> maybeCompact({
    required String agentId,
    required int budget,
    required AgentSummarizer summarize,
    required DateTime at,
    int? retainTokens,
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
    // chronological assembly order. Payloads load concurrently.
    final uncovered = [
      for (final loaded in await _loadFrontierSources(
        frontier,
        active.uncoveredEntryIds,
      ))
        _Uncovered(
          source: RenderedSource(
            contentEntryId: loaded.ref.contentEntryId,
            sourceCreatedAt: loaded.ref.sourceCreatedAt,
            content: loaded.payload.content,
          ),
          digest: loaded.ref.contentDigest,
          tokens: TextChunker.estimateTokens(
            jsonEncode(loaded.payload.content),
          ),
        ),
    ]..sort((a, b) => _byChrono(a.source, b.source));

    final tail = [
      for (final entry in uncovered)
        TailEntry(id: entry.source.contentEntryId, tokens: entry.tokens),
    ];
    final plan = planCompaction(tail: tail, budget: budget);
    if (!plan.shouldCompact) return null;

    // Triggered — fold down to the low watermark (see the docstring).
    final foldPlan = retainTokens != null && retainTokens < budget
        ? planCompaction(tail: tail, budget: retainTokens)
        : plan;

    final foldSet = foldPlan.foldIds.toSet();
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

/// Chronological assembly order for captured sources (ADR 0020 rule 4): by
/// [RenderedSource.sourceCreatedAt], then [RenderedSource.contentEntryId] as a
/// stable, log-derived tiebreak.
int _byChrono(RenderedSource a, RenderedSource b) {
  final byTime = a.sourceCreatedAt.compareTo(b.sourceCreatedAt);
  if (byTime != 0) return byTime;
  return a.contentEntryId.compareTo(b.contentEntryId);
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
