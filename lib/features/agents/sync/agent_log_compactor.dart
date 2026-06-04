import 'dart:convert';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/projection/compaction_plan.dart';
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
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
/// uncovered verbatim tail exceeds a token budget, fold its **oldest** events
/// into an appended `summary` checkpoint covering that log prefix.
///
/// The checkpoint is an append-only `summary` message pointing at a
/// content-addressed payload that records the covered log prefix (the cutoff
/// position), the covered source set (`contentEntryId` → digest, for
/// retraction invalidation) and the distilled text — so two devices that
/// summarize the same region dedupe, and the read side (`selectActiveSummary`)
/// picks the active checkpoint as a pure projection. The persisted pointers
/// are a cache; the log is authoritative.
class AgentLogCompactor {
  /// Creates the compactor over an [AgentSyncService] (used for both its
  /// sync-aware writes and its repository reads). [inlineEvents] are
  /// additional events derived from other synced log entities (e.g. resolved
  /// proposal verdicts via `decisionEventsFromLedger`) that share the
  /// substrate: same ordering, folds and cutoff as captured content.
  AgentLogCompactor({
    required AgentSyncService syncService,
    this.inlineEvents = const [],
  }) : _sync = syncService;

  final AgentSyncService _sync;

  /// Events whose content is carried inline rather than payload-backed.
  final List<InputEvent> inlineEvents;

  AgentRepository get _repository => _sync.repository;

  static const _uuid = Uuid();

  /// Loads the agent's materialized [SummaryCheckpoint]s from its `summary`
  /// messages — each points (via `contentEntryId`) at a payload holding the
  /// covered prefix cutoff, the covered source set and the summary text.
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
          cutoff: _parseCutoff(payload.content['coverageCutoff']),
        ),
      );
    }
    return checkpoints;
  }

  static EventPosition? _parseCutoff(Object? raw) {
    if (raw is! Map) return null;
    final at = raw['at'];
    final sourceAt = raw['sourceAt'];
    final key = raw['key'];
    if (at is! String || sourceAt is! String || key is! String) return null;
    final parsedAt = DateTime.tryParse(at);
    final parsedSourceAt = DateTime.tryParse(sourceAt);
    if (parsedAt == null || parsedSourceAt == null) return null;
    return EventPosition(at: parsedAt, sourceAt: parsedSourceAt, key: key);
  }

  /// Resolves the rendered content for [events] — inline events carry it
  /// directly, payload-backed events load it **concurrently** — preserving
  /// event order and dropping any whose payload is missing.
  Future<List<({InputEvent event, Map<String, Object?> content})>>
  _resolveEventContents(List<InputEvent> events) async {
    final payloads = await Future.wait([
      for (final event in events)
        if (event.contentDigest case final digest?)
          _repository.getEntity(digest)
        else
          Future<AgentDomainEntity?>.value(),
    ]);
    final result = <({InputEvent event, Map<String, Object?> content})>[];
    for (var i = 0; i < events.length; i++) {
      final inline = events[i].inlineContent;
      if (inline != null) {
        result.add((event: events[i], content: inline));
        continue;
      }
      final payload = payloads[i];
      if (payload is AgentMessagePayloadEntity) {
        result.add((event: events[i], content: payload.content));
      }
    }
    return result;
  }

  Future<({InputEventLog log, SummaryCheckpoint? active})> _projectActiveView(
    String agentId,
  ) async {
    final systemMessages = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.system,
    );
    // Observations share the log substrate (single memory: same ordering,
    // folds and cutoff as captured user content).
    final observations = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );
    final links = await _repository.getLinksFrom(agentId);
    final log = projectInputEvents(
      messages: systemMessages,
      links: links,
      observationMessages: observations,
      inlineEvents: inlineEvents,
    );
    if (log.isEmpty) return (log: log, active: null);
    final active = selectActiveSummary(
      summaries: await loadSummaries(agentId),
      log: log,
    );
    return (log: log, active: active);
  }

  /// The [RenderedSource] view of one resolved event — observation events are
  /// tagged with their type so both the prompt tail and the summarizer's fold
  /// input render them as `(observation)` lines (inline events already carry
  /// their type).
  static RenderedSource _toRenderedSource(
    InputEvent event,
    Map<String, Object?> content,
  ) => RenderedSource(
    contentEntryId: event.contentEntryId,
    sourceCreatedAt: event.sourceCreatedAt,
    content: event.isObservation
        ? <String, Object?>{...content, 'entryType': 'observation'}
        : content,
  );

  /// Assembles the read-side compacted task log for [agentId] (ADR 0017
  /// Decision 6): the active summary's prose followed by the verbatim event
  /// tail in capture order — append-only between folds, so consecutive wakes
  /// share a byte-identical prefix. Returns the empty string when the agent
  /// has no captured input yet. Pure read — no writes.
  Future<String> assembleContext(String agentId) async {
    final view = await _projectActiveView(agentId);
    if (view.log.events.isEmpty) return '';

    final tailEvents = visibleTailEvents(
      log: view.log,
      cutoff: view.active?.cutoff,
    );
    final tail = [
      for (final loaded in await _resolveEventContents(tailEvents))
        TailLine(
          source: _toRenderedSource(loaded.event, loaded.content),
          edited: loaded.event.isEdit,
        ),
    ];

    return assembleCompactedTaskLog(
      summaryText: view.active?.summaryText,
      tail: tail,
    );
  }

  /// Compacts [agentId] if its uncovered tail exceeds [budget] tokens, calling
  /// [summarize] to distill the folded events. Returns the appended summary's
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
    final view = await _projectActiveView(agentId);
    if (view.log.events.isEmpty) return null;

    final tailEvents = visibleTailEvents(
      log: view.log,
      cutoff: view.active?.cutoff,
    );
    // The uncovered tail with token costs, in event order. Payloads load
    // concurrently.
    final loadedTail = await _resolveEventContents(tailEvents);

    final tail = [
      for (final loaded in loadedTail)
        TailEntry(
          id: loaded.event.position.key,
          tokens: TextChunker.estimateTokens(jsonEncode(loaded.content)),
        ),
    ];
    final plan = planCompaction(tail: tail, budget: budget);
    if (!plan.shouldCompact) return null;

    // Triggered — fold down to the low watermark (see the docstring).
    final foldPlan = retainTokens != null && retainTokens < budget
        ? planCompaction(tail: tail, budget: retainTokens)
        : plan;

    // planCompaction folds a clean oldest-first prefix, so the fold set is the
    // first N events and the new cutoff is the last folded event's position.
    final foldSet = foldPlan.foldIds.toSet();
    final folded = [
      for (final loaded in loadedTail)
        if (foldSet.contains(loaded.event.position.key)) loaded,
    ];
    if (folded.isEmpty) return null;
    final cutoff = folded.last.event.position;

    // The new checkpoint extends the prior active one: its prose folds in the
    // prior summary, its covered set grows by the freshly folded sources
    // (later events overwrite earlier digests for the same source).
    final coveredSources = <String, String>{
      ...?view.active?.coveredSources,
      // Inline events have no payload digest; cover them by the digest of
      // their inline content so the checkpoint-completeness check can prove
      // a folded verdict was seen (a key absent from this map at or before
      // the cutoff invalidates the checkpoint as a late arrival).
      for (final loaded in folded)
        loaded.event.contentEntryId:
            loaded.event.contentDigest ??
            // Exactly one of digest/inlineContent is set by construction.
            ContentDigest.of(loaded.event.inlineContent),
    };

    final summaryText = await summarize(
      sources: [
        for (final loaded in folded)
          _toRenderedSource(loaded.event, loaded.content),
      ],
      priorSummary: view.active?.summaryText,
    );

    final payloadContent = <String, Object?>{
      'coverageCutoff': <String, Object?>{
        'at': cutoff.at.toIso8601String(),
        'sourceAt': cutoff.sourceAt.toIso8601String(),
        'key': cutoff.key,
      },
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
