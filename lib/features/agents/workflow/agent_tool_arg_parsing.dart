import 'dart:convert';

import 'package:lotti/features/agents/model/agent_enums.dart';

/// Parses raw agent tool-call arguments into a JSON map.
///
/// Accepts a plain JSON object, an empty/`{}` payload (→ empty map), or JSON
/// wrapped in a markdown ```json fence. Shared by every conversation strategy
/// (task / project / event) so the parsing rules — and their edge cases — live
/// in exactly one place.
///
/// The raw input is never embedded in the thrown [FormatException]: tool
/// arguments can carry user-authored content that may be routed to logs.
Map<String, dynamic> parseAgentToolArguments(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '{}') return {};

  // Try a direct parse first.
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}

  // Handle markdown-wrapped JSON. Guard the decode so a malformed fence falls
  // through to the sanitized exception below rather than letting jsonDecode
  // throw a FormatException that embeds the raw (possibly user-authored) source.
  final markdownRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
  final match = markdownRegex.firstMatch(trimmed);
  if (match != null) {
    try {
      final inner = match.group(1)!.trim();
      final decoded = jsonDecode(inner);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to the sanitized exception below.
    }
  }

  throw const FormatException('Cannot parse tool arguments');
}

/// Shared, lenient parsing of `record_observations` priority/category enum
/// strings (case- and underscore-insensitive), mixed into the strategies whose
/// observation handling is identical (event + project). Keeping it here means
/// the enum-string mapping is sourced from [ObservationPriority] /
/// [ObservationCategory] in one place instead of being re-typed per strategy.
mixin ObservationRecordParsing {
  ObservationPriority parseObservationPriority(String? raw) {
    if (raw == null) return ObservationPriority.routine;
    final normalized = raw.trim().toLowerCase();
    for (final value in ObservationPriority.values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    return ObservationPriority.routine;
  }

  ObservationCategory parseObservationCategory(String? raw) {
    if (raw == null) return ObservationCategory.operational;
    final normalized = raw.trim().replaceAll('_', '').toLowerCase();
    for (final value in ObservationCategory.values) {
      if (value.name.toLowerCase() == normalized) return value;
    }
    return ObservationCategory.operational;
  }
}
