import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/projection/input_events.dart';

/// A materialized summary checkpoint over a **prefix of the captured input
/// event log** (ADR 0017 / ADR 0020 rule 6): it folds every content event up
/// to and including [cutoff] into [summaryText], and is itself identified by
/// [contentDigest].
///
/// Coverage is a log *prefix*, not a state snapshot: a later **edit** of a
/// folded source appends a post-cutoff event that renders verbatim in the
/// tail, superseding the summary's stale prose without invalidating the
/// checkpoint (the prompt prefix stays byte-stable). A **retraction** of a
/// covered source is the one event that does invalidate it — the prose may
/// mention deleted content, and privacy beats cache.
class SummaryCheckpoint extends Equatable {
  /// Creates a checkpoint. [id] is the summary event id.
  const SummaryCheckpoint({
    required this.id,
    required this.contentDigest,
    required this.coveredSources,
    required this.summaryText,
    this.cutoff,
  });

  /// The summary event's id.
  final String id;

  /// Content-addressed digest of the summary artifact (text + folded prior).
  final String contentDigest;

  /// The sources this checkpoint's prose may mention: `contentEntryId` → the
  /// digest folded for it. Used to detect retractions of covered content; the
  /// tail boundary itself is [cutoff].
  final Map<String, String> coveredSources;

  /// The distilled summary prose.
  final String summaryText;

  /// The last folded event's position — the checkpoint covers every content
  /// event at or before this. Null on a malformed/legacy payload; such a
  /// checkpoint is never selected.
  final EventPosition? cutoff;

  @override
  List<Object?> get props => [
    id,
    contentDigest,
    coveredSources,
    summaryText,
    cutoff,
  ];
}

/// Selects the active checkpoint among the agent's materialized [summaries]
/// given the log's [retractions].
///
/// A summary is a *candidate* only if it has a [SummaryCheckpoint.cutoff] and
/// no covered source was retracted **after** that cutoff (a pre-cutoff
/// retraction was already visible at fold time and its content excluded; a
/// post-cutoff retraction means the prose may still mention deleted content —
/// the checkpoint is discarded and the tail re-expands until the next fold).
/// The active one covers the longest log prefix (greatest cutoff); ties —
/// concurrent folds over the same region — break by lowest
/// `(contentDigest, id)` (ADR 0017 Decision 3). Pure → two devices converge.
SummaryCheckpoint? selectActiveSummary({
  required List<SummaryCheckpoint> summaries,
  required List<RetractionEvent> retractions,
}) {
  SummaryCheckpoint? active;
  for (final summary in summaries) {
    final cutoff = summary.cutoff;
    if (cutoff == null) continue;
    final invalidated = retractions.any(
      (r) =>
          r.position.isAfter(cutoff) &&
          summary.coveredSources.containsKey(r.contentEntryId),
    );
    if (invalidated) continue;
    if (active == null ||
        cutoff.compareTo(active.cutoff!) > 0 ||
        (cutoff.compareTo(active.cutoff!) == 0 &&
            _tieKey(summary).compareTo(_tieKey(active)) < 0)) {
      active = summary;
    }
  }
  return active;
}

String _tieKey(SummaryCheckpoint summary) =>
    '${summary.contentDigest}|${summary.id}';

/// One rendered line of the verbatim tail: a captured source plus whether the
/// event superseded an earlier one (rendered as an `edited` tag).
class TailLine extends Equatable {
  /// Creates a tail line.
  const TailLine({required this.source, this.edited = false});

  /// The captured source content at this event.
  final RenderedSource source;

  /// True when this event superseded an earlier capture of the same source.
  final bool edited;

  @override
  List<Object?> get props => [source, edited];
}

/// Assembles the captured task log a wake reads: the active summary prose
/// (when present) followed by the verbatim [tail] in event order (ADR 0017
/// Decision 6 stable-prefix ordering — summary before tail). Each tail line is
/// rendered once and never re-rendered: edits append new lines, so between
/// folds the assembled log only ever grows at the end.
///
/// Pure function of its inputs. Returns the empty string when there is neither
/// a summary nor any tail, so callers can omit the section entirely.
String assembleCompactedTaskLog({
  required List<TailLine> tail,
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
    for (final line in tail) {
      buffer.writeln(
        renderCompactedSourceLine(line.source, edited: line.edited),
      );
    }
  }
  return buffer.toString().trimRight();
}

/// Renders one captured source as the single line the compacted task log uses:
/// `- [iso8601] (entryType[, edited][ · loggedDuration]) body`, where the body
/// falls back to the audio transcript when the text is empty and the duration
/// tag is omitted when it carries no information (`00:00`/absent). [edited]
/// marks an event that supersedes an earlier capture of the same source.
///
/// Shared by [assembleCompactedTaskLog] (the prompt's verbatim tail) and the
/// LLM summarizer (the fold input), so what gets distilled matches what the
/// prompt shows.
String renderCompactedSourceLine(RenderedSource source, {bool edited = false}) {
  final type = source.content['entryType'] ?? 'entry';
  final text = source.content['text'] ?? '';
  final transcript = source.content['audioTranscript'];
  final rawBody = (text is String && text.isNotEmpty)
      ? text
      : (transcript is String ? transcript : '');
  final body = rawBody.trim();
  final editedTag = edited ? ', edited' : '';
  // Keep the per-entry time evidence when it carries information.
  final duration = source.content['loggedDuration'];
  final durationTag =
      (duration is String && duration.isNotEmpty && duration != '00:00')
      ? ' · $duration'
      : '';
  return '- [${source.sourceCreatedAt.toIso8601String()}] '
      '($type$editedTag$durationTag) $body';
}
