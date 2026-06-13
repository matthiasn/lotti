import 'dart:convert';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/memory/memory_links.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/projection/compaction_plan.dart';
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_events.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor_models.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/sync/agent_log_compactor_models.dart';

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
/// position), the covered event set (`contentEntryId` → digest) and the
/// distilled text — so two devices that summarize the same region dedupe, and
/// the read side (`selectActiveSummary`) picks the active checkpoint as a pure
/// projection. The persisted pointers are a cache; the log is authoritative.
class AgentLogCompactor {
  /// Creates the compactor over an [AgentSyncService] (used for both its
  /// sync-aware writes and its repository reads). [inlineEvents] are
  /// additional events derived from other synced log entities (e.g. resolved
  /// proposal verdicts via `decisionEventsFromLedger`) that share the
  /// substrate: same ordering, folds and cutoff as captured content.
  AgentLogCompactor({
    required AgentSyncService syncService,
    this.inlineEvents = const [],
    this.resolveInlineContent,
  }) : _sync = syncService;

  final AgentSyncService _sync;

  /// Events whose content is carried inline rather than payload-backed.
  final List<InputEvent> inlineEvents;

  /// Resolves content for [InputEvent.inlineDeferred] events by their
  /// `contentEntryId`. Invoked only for the events the compactor actually
  /// renders/folds (the post-cutoff tail), so a covered deferred source never
  /// loads its (potentially large) content again. Returns null when the source
  /// is missing (the event is then dropped, like a missing payload).
  final Future<Map<String, Object?>?> Function(String contentEntryId)?
  resolveInlineContent;

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

  /// Resolves the rendered content for [events] — eager-inline events carry it
  /// directly, deferred-inline events resolve via [resolveInlineContent], and
  /// payload-backed events load their payload — all **concurrently**,
  /// preserving event order and dropping any whose content is missing.
  Future<List<({InputEvent event, Map<String, Object?> content})>>
  _resolveEventContents(List<InputEvent> events) async {
    final resolved = await Future.wait([
      for (final event in events)
        () async {
          final inline = event.inlineContent;
          if (inline != null) {
            return (event: event, content: inline);
          }
          if (event.deferredInline) {
            final content = await resolveInlineContent?.call(
              event.contentEntryId,
            );
            return content == null ? null : (event: event, content: content);
          }
          final digest = event.contentDigest;
          if (digest == null) return null;
          final payload = await _repository.getEntity(digest);
          return payload is AgentMessagePayloadEntity
              ? (event: event, content: payload.content)
              : null;
        }(),
    ]);
    return [
      for (final entry in resolved) ?entry,
    ];
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
  /// input render them as observation-tagged lines (inline events already
  /// carry their type).
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
  Future<String> assembleContext(String agentId) async =>
      (await assembleContextDetailed(agentId)).text;

  /// [assembleContext] plus the reconstruction marker (ADR 0020 v2 prompt
  /// records): the active checkpoint's summary-message id and the position of
  /// the LAST rendered tail event — together they pin this assembly so
  /// [assembleContextAsOf] can re-derive the identical block later, after
  /// further appends and folds.
  Future<AssembledLog> assembleContextDetailed(String agentId) async {
    final view = await _projectActiveView(agentId);
    if (view.log.events.isEmpty) return const AssembledLog.empty();

    final tailEvents = visibleTailEvents(
      log: view.log,
      cutoff: view.active?.cutoff,
    );
    // _resolveEventContents can drop events whose content is (temporarily)
    // unavailable — e.g. a deferred capture not yet synced. The replay marker
    // must pin to the last event actually RENDERED, not the raw tail, or
    // assembleContextAsOf could later reconstruct a different prompt once the
    // dropped content arrives.
    final resolved = await _resolveEventContents(tailEvents);
    final tail = [
      for (final loaded in resolved)
        TailLine(
          source: _toRenderedSource(loaded.event, loaded.content),
          edited: loaded.event.isEdit,
        ),
    ];

    return AssembledLog(
      text: assembleCompactedTaskLog(
        summaryText: view.active?.summaryText,
        tail: tail,
      ),
      activeSummaryId: view.active?.id,
      lastEventPosition: resolved.isEmpty ? null : resolved.last.event.position,
    );
  }

  /// Keyword search over the agent's FULL immutable memory log (folded events
  /// AND the verbatim tail), returning up to [limit] most-recent hits whose
  /// rendered text contains EVERY whitespace-separated term in [query]
  /// (case-insensitive). The agent's recall tool: detail folded out of the
  /// summary is still in the log, so this lets a wake reach back into it.
  ///
  /// On-demand by design. The per-wake assembly path stays lazy (it resolves
  /// only the tail); this is the one reader that scans beyond the tail, and it
  /// only runs when the agent explicitly recalls. Events are scanned
  /// newest-first in chunks so recent matches stop the scan early rather than
  /// resolving the whole multi-year history.
  Future<List<MemoryLogHit>> searchLog(
    String agentId, {
    required String query,
    int limit = 8,
    Set<String> extraKnownIds = const {},
  }) async {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty || limit <= 0) return const [];
    return _scanLog(
      agentId,
      limit: limit,
      extraKnownIds: extraKnownIds,
      matches: (event, text) {
        final haystack = text.toLowerCase();
        return terms.every(haystack.contains);
      },
    );
  }

  /// Pulls up specific memory-log entries by their [ids] — the "follow a link"
  /// counterpart to [searchLog], used to expand a `[[relation:id]]` reference
  /// the agent saw. Same lazy newest-first scan: it resolves content only for
  /// matching events and stops once [limit] are found, so following a handful
  /// of links never loads the whole history. Returns at most [limit] hits.
  Future<List<MemoryLogHit>> resolveByIds(
    String agentId, {
    required Set<String> ids,
    int limit = 20,
    Set<String> extraKnownIds = const {},
  }) async {
    if (ids.isEmpty || limit <= 0) return const [];
    return _scanLog(
      agentId,
      limit: limit,
      extraKnownIds: extraKnownIds,
      matches: (event, text) => ids.contains(event.contentEntryId),
    );
  }

  /// Shared newest-first chunked scan behind [searchLog] and [resolveByIds].
  ///
  /// Resolves content per chunk, collecting the first [limit] events for which
  /// [matches] holds. Two things are derived for every returned hit without a
  /// second pass over the log — with different completeness guarantees:
  /// - **`supersededByEntryId` (the hit's *own* supersession) is complete.**
  ///   It is accumulated from every scanned `[[supersedes:id]]` token; because
  ///   the agent can only cite ids it saw in an earlier wake, a superseder is
  ///   strictly newer than its target, and the scan runs newest-first — so any
  ///   superseder of a returned hit is always scanned before the hit matches,
  ///   even when the scan stops early at [limit]. (A same-instant tie that the
  ///   position key happened to order superseder-after-target is the only gap;
  ///   it cannot arise from real cross-wake authoring.)
  /// - **Outgoing `[[relation:id]]` links are best-effort.** Existence is
  ///   validated against the full (cheaply-projected) set of log entry ids plus
  ///   [extraKnownIds] (e.g. durable-knowledge keys outside the episodic log),
  ///   which is always complete. Forward-following a non-`supersedes` target to
  ///   its live version, however, only fires when that target's superseder was
  ///   itself within the scan window — otherwise the link renders at its
  ///   original (still-valid) id. This is presentation-only (transient tool
  ///   output, never persisted), so the bound is acceptable.
  ///
  /// [extraKnownIds] lets a caller widen link validation beyond the memory log
  /// (the planner passes its knowledge keys/ids so cross-tier links resolve);
  /// the compactor stays agnostic about what those ids mean.
  Future<List<MemoryLogHit>> _scanLog(
    String agentId, {
    required int limit,
    required bool Function(InputEvent event, String text) matches,
    Set<String> extraKnownIds = const {},
  }) async {
    final view = await _projectActiveView(agentId);
    if (view.log.events.isEmpty) return const [];

    final knownIds = <String>{
      for (final e in view.log.events) e.contentEntryId,
      ...extraKnownIds,
    };
    final events = view.log.events.reversed.toList(); // newest-first
    final supersededBy = <String, String>{};
    final matched =
        <
          ({
            InputEvent event,
            String type,
            String text,
            bool edited,
            List<MemoryLink> parsed,
          })
        >[];

    const chunk = 50;
    outer:
    for (var i = 0; i < events.length; i += chunk) {
      final end = i + chunk < events.length ? i + chunk : events.length;
      final loaded = await _resolveEventContents(events.sublist(i, end));
      for (final l in loaded) {
        final text = _searchableText(l.content);
        final parsed = parseMemoryLinks(text);
        for (final link in parsed) {
          if (link.relation == LinkRelation.supersedes) {
            supersededBy.putIfAbsent(
              link.entryId,
              () => l.event.contentEntryId,
            );
          }
        }
        if (matches(l.event, text)) {
          matched.add((
            event: l.event,
            type:
                (l.content['entryType'] as String?) ??
                (l.event.isObservation ? 'observation' : 'entry'),
            text: text,
            edited: l.event.isEdit,
            parsed: parsed,
          ));
          if (matched.length >= limit) break outer;
        }
      }
    }

    return [
      for (final m in matched)
        MemoryLogHit(
          contentEntryId: m.event.contentEntryId,
          at: m.event.position.at,
          type: m.type,
          text: m.text,
          edited: m.edited,
          links: resolveMemoryLinks(
            m.parsed,
            knownIds: knownIds,
            supersededBy: supersededBy,
          ),
          supersededByEntryId: supersededBy[m.event.contentEntryId],
        ),
    ];
  }

  static String _searchableText(Map<String, Object?> content) {
    final text = content['text'];
    if (text is String) return text;
    return jsonEncode(content);
  }

  /// Re-derives the log block a PAST wake rendered (ADR 0020 v2 prompt
  /// records): the checkpoint pinned by [summaryId] (used even if later
  /// invalidated — the wake really rendered its prose) plus the visible
  /// events in `(checkpoint.cutoff, until]`. A null [until] means the wake's
  /// tail was empty.
  ///
  /// Inline events (decisions, day captures) must be re-derived by the
  /// caller and supplied via the constructor's `inlineEvents`. Retractions
  /// are append-only, not suppressing: one past [until] never reaches back
  /// into the reconstruction, and one inside `(cutoff, until]` renders as its
  /// own marker line beside the content it concerns. Late-arriving synced
  /// events with positions ≤ [until] make the reconstruction reflect the
  /// CONVERGED log rather than the device-local render — semantically
  /// auditable, not forensically byte-exact.
  Future<String> assembleContextAsOf(
    String agentId, {
    String? summaryId,
    EventPosition? until,
  }) async {
    final systemMessages = await _repository.getMessagesByKind(
      agentId,
      AgentMessageKind.system,
    );
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

    SummaryCheckpoint? pinned;
    if (summaryId != null) {
      final summaries = await loadSummaries(agentId);
      for (final summary in summaries) {
        if (summary.id == summaryId) {
          pinned = summary;
          break;
        }
      }
    }

    final tailEvents = until == null
        ? const <InputEvent>[]
        : visibleTailEvents(
            log: log,
            cutoff: pinned?.cutoff,
          ).where((e) => !e.position.isAfter(until)).toList();
    final tail = [
      for (final loaded in await _resolveEventContents(tailEvents))
        TailLine(
          source: _toRenderedSource(loaded.event, loaded.content),
          edited: loaded.event.isEdit,
        ),
    ];

    return assembleCompactedTaskLog(
      summaryText: pinned?.summaryText,
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
            // Inline events (eager or deferred) have no payload digest; cover
            // them by the digest of their resolved content. `loaded.content`
            // equals the eager `inlineContent` for eager events and the
            // resolver output for deferred ones, so the digest is identical
            // across both paths (and across app versions).
            ContentDigest.of(loaded.content),
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
