import 'dart:convert';

import 'package:matrix/matrix.dart';

/// Helpers for the Matrix streaming pipeline.
///
/// Pure functions extracted from MatrixStreamConsumer for easier testing.

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
