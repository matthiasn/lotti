import 'dart:math' as math;

import 'package:matrix/matrix.dart';

/// Computes a jittered exponential backoff.
Duration computeExponentialBackoff(
  int attempts, {
  Duration base = const Duration(milliseconds: 200),
  Duration max = const Duration(seconds: 10),
  double jitterFraction = 0.2,
  math.Random? random,
}) {
  final baseMs = base.inMilliseconds;
  final maxMs = max.inMilliseconds;
  final raw = baseMs * math.pow(2, attempts);
  final clamped = raw.clamp(baseMs.toDouble(), maxMs.toDouble());
  if (jitterFraction == 0) {
    return Duration(milliseconds: clamped.round());
  }
  final rnd = random ?? math.Random();
  final jitter = 1 + (jitterFraction * (rnd.nextDouble() * 2 - 1));
  final jittered =
      (clamped * jitter).clamp(baseMs.toDouble(), maxMs.toDouble());
  return Duration(milliseconds: jittered.round());
}

/// Finds the last index of an event by its ID in an ordered list, or -1.
int findLastIndexByEventId(List<Event> ordered, String? id) {
  if (id == null) return -1;
  for (var i = ordered.length - 1; i >= 0; i--) {
    if (ordered[i].eventId == id) return i;
  }
  return -1;
}

/// Returns a new list containing only events strictly after [lastId].
List<Event> sliceAfterMarker(List<Event> ordered, String? lastId) {
  final idx = findLastIndexByEventId(ordered, lastId);
  return idx >= 0 ? ordered.sublist(idx + 1) : ordered;
}

/// Deduplicates events by eventId while preserving the original order.
List<Event> dedupEventsByIdPreserveOrder(List<Event> events) {
  final seen = <String>{};
  final result = <Event>[];
  for (final e in events) {
    if (seen.add(e.eventId)) {
      result.add(e);
    }
  }
  return result;
}

/// Whether an event should have its attachment prefetched before processing.
bool shouldPrefetchAttachment(Event e, String? currentUserId) {
  final mime = e.attachmentMimetype;
  if (mime.isEmpty) return false;
  // Prefetch media and JSON descriptors for cross-device hydration.
  final isSupported = mime.startsWith('image/') ||
      mime.startsWith('audio/') ||
      mime.startsWith('video/') ||
      mime == 'application/json';
  // Sender-agnostic: downloading again is safe due to atomic dedupe and
  // enables cross-device sync for self-sent messages.
  return isSupported;
}
