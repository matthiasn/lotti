part of 'agent_log_compactor.dart';

/// One hit from [AgentLogCompactor.searchLog] / [AgentLogCompactor.resolveByIds]
/// — a raw memory-log entry (capture transcript or observation) that matched,
/// including detail that has been folded out of the compacted summary.
class MemoryLogHit {
  /// Wraps a hit.
  const MemoryLogHit({
    required this.contentEntryId,
    required this.at,
    required this.type,
    required this.text,
    required this.edited,
    this.links = const [],
    this.supersededByEntryId,
  });

  /// The originating entity id (capture id, observation message id, …).
  final String contentEntryId;

  /// The event's log position time (capture/observation creation).
  final DateTime at;

  /// The entry type — `capture`, `observation`, or `entry` as a fallback.
  final String type;

  /// The rendered searchable text of the entry.
  final String text;

  /// True when a later event supersedes this one for the same source.
  final bool edited;

  /// Author-time `[[relation:id]]` links parsed from this entry's text, each
  /// validated for existence against the log (see [ResolvedMemoryLink]).
  final List<ResolvedMemoryLink> links;

  /// When another entry carries `[[supersedes:thisId]]`, the id of the newest
  /// such entry; null when nothing supersedes this one.
  final String? supersededByEntryId;
}

/// One assembled compacted log plus the marker that pins it for
/// reconstruction (ADR 0020 v2 prompt records).
class AssembledLog {
  /// Wraps an assembly result.
  const AssembledLog({
    required this.text,
    required this.activeSummaryId,
    required this.lastEventPosition,
  });

  /// An empty assembly (agent has no captured input yet).
  const AssembledLog.empty()
    : text = '',
      activeSummaryId = null,
      lastEventPosition = null;

  /// The rendered `summary + tail` block.
  final String text;

  /// The active checkpoint's summary-message id, or null when none.
  final String? activeSummaryId;

  /// The position of the last rendered tail event, or null when the tail
  /// was empty.
  final EventPosition? lastEventPosition;
}
