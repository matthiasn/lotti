import 'dart:convert';

import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart' as tu;
import 'package:matrix/matrix.dart';

/// Helpers for the Matrix streaming pipeline.
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
/// by diagnostics when a journal update is skipped for older/equal payloads.
String ignoredReasonFromStatus(String status) {
  if (status.contains('a_gt_a') || status.contains('a_gt_b')) {
    return 'older';
  }
  if (status.contains('equal')) {
    return 'equal';
  }
  return 'unknown';
}

/// Builds a live-scan slice from timeline events.
///
/// - Sorts chronologically ascending
/// - If [lastEventId] is present: returns events strictly after it
/// - Otherwise returns the last [tailLimit] events
/// - Applies timestamp cutoff when [lastTimestamp] is provided
/// - Deduplicates by eventId preserving order
List<Event> buildLiveScanSlice({
  required List<Event> timelineEvents,
  required String? lastEventId,
  required int tailLimit,
  required num? lastTimestamp,
  required Duration tsGate,
}) {
  final events = List<Event>.from(timelineEvents)
    ..sort(TimelineEventOrdering.compare);
  final idx = tu.findLastIndexByEventId(events, lastEventId);
  var slice = idx >= 0
      ? events.sublist(idx + 1)
      : (events.isEmpty
          ? events
          : events.sublist(
              (events.length - tailLimit).clamp(0, events.length),
            ));
  if (slice.isNotEmpty && lastTimestamp != null) {
    final cutoff = lastTimestamp.toInt() - tsGate.inMilliseconds;
    slice = slice
        .where((e) => TimelineEventOrdering.timestamp(e) >= cutoff)
        .toList();
  }
  return tu.dedupEventsByIdPreserveOrder(slice);
}

/// Filters a list of events to optionally drop older/equal sync payloads while
/// preserving attachments and any events with retry attempts.
///
/// - When [dropOldSyncPayloads] is false, returns [events] unchanged.
/// - When true, a sync payload event is kept only if it is strictly newer than
///   ([lastTimestamp], [lastEventId]) or when [hasAttempts] returns true for
///   its eventId. Non‑payload events (attachments) are always kept.
/// - Invokes [onSkipped] each time a payload is dropped (for metrics).
List<Event> filterSyncPayloadsByMonotonic({
  required List<Event> events,
  required bool dropOldSyncPayloads,
  required num? lastTimestamp,
  required String? lastEventId,
  required bool Function(String eventId) hasAttempts,
  void Function()? onSkipped,
}) {
  if (!dropOldSyncPayloads) return events;
  final kept = <Event>[];
  for (final e in events) {
    if (!isLikelySyncPayloadEvent(e)) {
      kept.add(e);
      continue;
    }
    final ts = TimelineEventOrdering.timestamp(e);
    final newer = TimelineEventOrdering.isNewer(
      candidateTimestamp: ts,
      candidateEventId: e.eventId,
      latestTimestamp: lastTimestamp,
      latestEventId: lastEventId,
    );
    if (!newer && !hasAttempts(e.eventId)) {
      onSkipped?.call();
      continue;
    }
    kept.add(e);
  }
  return kept;
}
