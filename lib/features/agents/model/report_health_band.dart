/// Shared parsing for report-provenance health bands (the ADR 0040
/// consequence: a second consumer of the pattern forces the helper out of
/// `project_health_metrics.dart` instead of a copy).
///
/// A band rides on an agent report's provenance as three keys — the band
/// name, a free-text rationale, and an optional confidence — and every
/// consumer parses them with the same tolerance: band names normalize
/// case/punctuation before matching, confidence accepts numbers or numeric
/// strings and fails closed outside `[0, 1]`.
library;

/// Matches [raw] against [bandsByName] after normalizing case and
/// stripping non-letters, so `on-track`, `onTrack` and `On Track` are one
/// wire value. Returns null for anything else — an unknown band never
/// becomes a rendered chip.
T? parseReportHealthBand<T>(String raw, Map<String, T> bandsByName) {
  final normalized = raw.trim().toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  for (final entry in bandsByName.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return null;
}

/// Parses a confidence value (0–1) from a number or string.
///
/// Returns `null` for `null`, non-finite values (e.g. NaN, infinity),
/// or values outside the 0–1 range.
double? parseReportHealthConfidence(Object? value) {
  if (value == null) return null;
  final parsed = switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 1) {
    return null;
  }
  return parsed;
}
