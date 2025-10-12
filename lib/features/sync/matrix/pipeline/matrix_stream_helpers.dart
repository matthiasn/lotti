import 'dart:convert';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:matrix/matrix.dart';

/// Helpers for Matrix streaming pipeline.
///
/// Pure functions extracted from MatrixStreamConsumer for easier testing.

/// Attempts to decode a Matrix event's text content (base64 JSON) and
/// return the `runtimeType` field when present.
String? extractRuntimeTypeFromEvent(Event ev) {
  try {
    final txt = ev.text;
    if (txt.isEmpty) return null;
    final decoded = utf8.decode(base64.decode(txt));
    final obj = json.decode(decoded);
    if (obj is Map<String, dynamic>) {
      final rt = obj['runtimeType'];
      return rt is String ? rt : null;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Extracts a JSON path from a `journalEntity` payload carried in the event
/// text (base64 JSON). Returns null when not present or not a journal entity.
String? extractJsonPathFromEvent(Event ev) {
  try {
    final txt = ev.text;
    if (txt.isEmpty) return null;
    final decoded = utf8.decode(base64.decode(txt));
    final obj = json.decode(decoded);
    if (obj is Map<String, dynamic>) {
      final rt = obj['runtimeType'];
      if (rt == 'journalEntity') {
        final jp = obj['jsonPath'];
        return jp is String ? jp : null;
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Returns true if the provided base64 text decodes to JSON Map with a
/// string `runtimeType`. Used to detect sync payloads when `msgtype` is
/// missing (fallback path).
bool isLikelySyncPayloadText(String base64Text) {
  try {
    if (base64Text.isEmpty) return false;
    final decoded = utf8.decode(base64.decode(base64Text));
    final obj = json.decode(decoded);
    return obj is Map<String, dynamic> && obj['runtimeType'] is String;
  } catch (_) {
    return false;
  }
}

/// Safely checks whether an event likely contains a sync payload in its text
/// by reading `e.text` and delegating to [isLikelySyncPayloadText]. Any
/// exceptions thrown by the mock or SDK getter are treated as non-sync.
bool isLikelySyncPayloadEvent(Event e) {
  try {
    return isLikelySyncPayloadText(e.text);
  } catch (_) {
    return false;
  }
}

/// Adds an entry to a ring buffer-like list with a maximum size, evicting the
/// oldest entry when the size limit is exceeded.
void ringBufferAdd(List<String> buffer, String entry, int maxSize) {
  buffer.add(entry);
  if (buffer.length > maxSize) {
    buffer.removeAt(0);
  }
}

/// Returns whether the marker should advance from the last processed
/// timestamp/id given a candidate timestamp/id using TimelineEventOrdering.
bool shouldAdvanceMarker({
  required num candidateTimestamp,
  required String candidateEventId,
  required num? lastTimestamp,
  required String? lastEventId,
}) {
  if (lastTimestamp == null || lastEventId == null) return true;
  return TimelineEventOrdering.isNewer(
    candidateTimestamp: candidateTimestamp,
    candidateEventId: candidateEventId,
    latestTimestamp: lastTimestamp,
    latestEventId: lastEventId,
  );
}

/// Computes the delay for the next scan given an optional earliestNextDue
/// and the current time. If earliestNextDue is null or <= now, returns the
/// default delay.
Duration computeNextScanDelay(
  DateTime now,
  DateTime? earliestNextDue, {
  Duration defaultDelay = const Duration(milliseconds: 200),
}) {
  if (earliestNextDue != null && earliestNextDue.isAfter(now)) {
    return earliestNextDue.difference(now);
  }
  return defaultDelay;
}

/// Converts a vector clock status string into a concise ignored reason used
/// by diagnostics when rowsAffected == 0 and not a concurrent conflict.
String ignoredReasonFromStatus(String status) {
  if (status.contains('a_gt_a') || status.contains('a_gt_b')) {
    return 'older';
  }
  if (status.contains('equal')) {
    return 'equal';
  }
  return 'unknown';
}
