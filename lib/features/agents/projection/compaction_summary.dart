import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';

/// A materialized summary checkpoint over a set of captured **input sources**
/// (ADR 0017 / ADR 0020 rule 6): it folds [coveredSources] (each source's
/// `contentEntryId` → the `contentDigest` it covered at fold time) into
/// [summaryText], and is itself identified by [contentDigest].
///
/// Coverage is by `(entryId, digest)` pair — not by id alone — so a later
/// **edit** to a covered source (a new digest for that entry) leaves the
/// checkpoint no longer covering it: the edited content resurfaces verbatim in
/// the tail rather than being hidden behind a stale summary.
class SummaryCheckpoint extends Equatable {
  /// Creates a checkpoint. [id] is the summary event id.
  const SummaryCheckpoint({
    required this.id,
    required this.contentDigest,
    required this.coveredSources,
    required this.summaryText,
  });

  /// The summary event's id.
  final String id;

  /// Content-addressed digest of the summary artifact (text + folded prior).
  final String contentDigest;

  /// The sources this checkpoint folds: `contentEntryId` → covered digest.
  final Map<String, String> coveredSources;

  /// The distilled summary prose.
  final String summaryText;

  @override
  List<Object?> get props => [id, contentDigest, coveredSources, summaryText];
}

/// The summary selected for a wake plus the sources left verbatim.
class ActiveSummary extends Equatable {
  /// Wraps a selection. Callers obtain instances from [selectActiveSummary].
  const ActiveSummary({
    required this.checkpoint,
    required this.uncoveredEntryIds,
  });

  /// The active checkpoint, or null when no checkpoint completely covers a
  /// subset of the current frontier (e.g. no summaries yet, or every summary
  /// is stale because a covered source was edited).
  final SummaryCheckpoint? checkpoint;

  /// Frontier `contentEntryId`s not covered by [checkpoint] — the verbatim
  /// tail — sorted for determinism.
  final List<String> uncoveredEntryIds;

  @override
  List<Object?> get props => [checkpoint, uncoveredEntryIds];
}

/// Selects the active summary for the current input [frontier] (each source's
/// `contentEntryId` → its active `contentDigest`, e.g. from
/// `inputFrontierDigests`) among the agent's materialized [summaries].
///
/// A summary is a *candidate* only if it is **complete** — every covered
/// `(entryId, digest)` is still exactly present in the frontier (ADR 0017's
/// "maximal complete checkpoint", over the source frontier rather than the
/// message DAG). The active one covers the most sources; ties — concurrent
/// summaries over the same coverage — break by lowest `(contentDigest, id)`
/// (ADR 0017 Decision 3). The uncovered tail is every frontier source the
/// active checkpoint does not cover. Pure → two devices converge.
ActiveSummary selectActiveSummary({
  required Map<String, String> frontier,
  required List<SummaryCheckpoint> summaries,
}) {
  SummaryCheckpoint? active;
  for (final summary in summaries) {
    final complete = summary.coveredSources.entries.every(
      (entry) => frontier[entry.key] == entry.value,
    );
    if (!complete) continue;
    if (active == null ||
        summary.coveredSources.length > active.coveredSources.length ||
        (summary.coveredSources.length == active.coveredSources.length &&
            _tieKey(summary).compareTo(_tieKey(active)) < 0)) {
      active = summary;
    }
  }

  final covered = active?.coveredSources.keys.toSet() ?? const <String>{};
  final uncoveredEntryIds = [
    for (final entryId in frontier.keys)
      if (!covered.contains(entryId)) entryId,
  ]..sort();

  return ActiveSummary(
    checkpoint: active,
    uncoveredEntryIds: uncoveredEntryIds,
  );
}

String _tieKey(SummaryCheckpoint summary) =>
    '${summary.contentDigest}|${summary.id}';

/// Assembles the captured task log a wake reads: the active summary prose (when
/// present) followed by the verbatim tail [tail] in canonical assembly order
/// (ADR 0017 Decision 6 stable-prefix ordering — summary before tail).
///
/// Pure function of its inputs. Returns the empty string when there is neither
/// a summary nor any tail, so callers can omit the section entirely.
String assembleCompactedTaskLog({
  required List<RenderedSource> tail,
  String? summaryText,
}) {
  final hasSummary = summaryText != null && summaryText.trim().isNotEmpty;
  if (!hasSummary && tail.isEmpty) return '';

  final buffer = StringBuffer();
  if (hasSummary) {
    buffer
      ..writeln('### Summary of earlier activity')
      ..writeln(summaryText.trim())
      ..writeln();
  }
  if (tail.isNotEmpty) {
    buffer.writeln('### Recent entries');
    for (final source in tail) {
      final type = source.content['entryType'] ?? 'entry';
      final text = source.content['text'] ?? '';
      final transcript = source.content['audioTranscript'];
      final body = (text is String && text.isNotEmpty)
          ? text
          : (transcript is String ? transcript : '');
      // Keep the per-entry time evidence when it carries information.
      final duration = source.content['loggedDuration'];
      final durationTag =
          (duration is String && duration.isNotEmpty && duration != '00:00')
          ? ' · $duration'
          : '';
      buffer.writeln(
        '- [${source.sourceCreatedAt.toIso8601String()}] '
        '($type$durationTag) $body',
      );
    }
  }
  return buffer.toString().trimRight();
}
