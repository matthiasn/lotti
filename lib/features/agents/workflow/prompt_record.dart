import 'package:lotti/features/agents/projection/input_events.dart';

/// The decoded form of a v2 wake-prompt record (ADR 0020): the prompt's
/// non-derivable halves plus the marker needed to re-derive the log block
/// between them on demand.
class PromptRecord {
  /// Wraps decoded parts. Callers obtain instances from [decodePromptRecord].
  const PromptRecord({
    required this.head,
    required this.tail,
    required this.summaryId,
    required this.until,
    this.wrap = promptRecordWrapPlain,
  });

  /// Prompt text before the log block (live-state render — not derivable).
  final String head;

  /// Prompt text after the log block (volatile tail — not derivable).
  final String tail;

  /// The summary message id of the checkpoint active at the wake, or null
  /// when no checkpoint was active (the whole visible log was verbatim).
  final String? summaryId;

  /// The position of the LAST event rendered in the wake's tail (inclusive
  /// reconstruction bound), or null when the tail was empty. A position —
  /// not the wake timestamp — because events written later in the same wake
  /// (this wake's own observations) share the wake's clock value but were
  /// never in the prompt.
  final EventPosition? until;

  /// How the re-derived log splices between [head] and [tail]:
  /// [promptRecordWrapPlain] inserts the text verbatim;
  /// [promptRecordWrapDayLogSection] re-renders it inside the day payload's
  /// `<day_log>` tagged section;
  /// [promptRecordWrapDayLogJsonLine] re-encodes it as the legacy day payload's
  /// `"dayLog"` JSON field line (kept decodable for already-persisted records).
  final String wrap;
}

/// Verbatim splice (markdown block prompts).
const String promptRecordWrapPlain = 'plain';

/// `<day_log>\n<log>\n</day_log>` splice — the day agent's tagged-plaintext
/// payload (current). The whole derivable section is dropped from storage and
/// re-rendered on reconstruction.
const String promptRecordWrapDayLogSection = 'day-log-section';

/// `  "dayLog": <json-encoded log>,\n` splice — the day agent's LEGACY JSON
/// payload. Retained so v2 records persisted before the tagged-plaintext
/// conversion still reconstruct for the history UI.
const String promptRecordWrapDayLogJsonLine = 'json-day-log-line';

/// Marker value of the `promptFormat` field for v2 records.
const String promptRecordFormatV2 = 'v2';

/// Encodes a v2 wake-prompt record payload: the prompt minus its derivable
/// `## … Log` block (which reconstruction re-derives from the synced event
/// log via the [summaryId]/[until] marker). Storing only the non-derivable
/// halves cuts the per-wake payload by roughly the size of the accumulated
/// history — the log block is exactly the part that grows.
Map<String, Object?> encodePromptRecord({
  required String head,
  required String tail,
  String? summaryId,
  EventPosition? until,
  String wrap = promptRecordWrapPlain,
}) {
  return <String, Object?>{
    'promptFormat': promptRecordFormatV2,
    'head': head,
    'tail': tail,
    if (wrap != promptRecordWrapPlain) 'wrap': wrap,
    'log': <String, Object?>{
      'summaryId': ?summaryId,
      if (until != null)
        'until': <String, Object?>{
          'at': until.at.toIso8601String(),
          'sourceAt': until.sourceAt.toIso8601String(),
          'key': until.key,
        },
    },
  };
}

/// Decodes a payload written by [encodePromptRecord]. Returns null when the
/// payload is not a v2 prompt record (e.g. a legacy `{'text': …}` blob),
/// so callers can fall through to the plain-text path.
PromptRecord? decodePromptRecord(Map<String, Object?> content) {
  if (content['promptFormat'] != promptRecordFormatV2) return null;
  final head = content['head'];
  final tail = content['tail'];
  if (head is! String || tail is! String) return null;

  String? summaryId;
  EventPosition? until;
  final log = content['log'];
  if (log is Map) {
    final rawSummaryId = log['summaryId'];
    if (rawSummaryId is String) summaryId = rawSummaryId;
    final rawUntil = log['until'];
    if (rawUntil is Map) {
      final at = rawUntil['at'];
      final sourceAt = rawUntil['sourceAt'];
      final key = rawUntil['key'];
      if (at is String && sourceAt is String && key is String) {
        final parsedAt = DateTime.tryParse(at);
        final parsedSourceAt = DateTime.tryParse(sourceAt);
        if (parsedAt != null && parsedSourceAt != null) {
          until = EventPosition(
            at: parsedAt,
            sourceAt: parsedSourceAt,
            key: key,
          );
        }
      }
    }
  }
  final rawWrap = content['wrap'];
  return PromptRecord(
    head: head,
    tail: tail,
    summaryId: summaryId,
    until: until,
    wrap: rawWrap is String ? rawWrap : promptRecordWrapPlain,
  );
}
