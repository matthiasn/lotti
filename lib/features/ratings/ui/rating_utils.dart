/// Maps a normalized [value] to its matching option label.
///
/// When [values] is provided, uses the actual stored values for matching.
/// Otherwise falls back to assuming evenly spaced values across 0.0-1.0
/// (e.g. 3 options → 0.0, 0.5, 1.0) for old data without stored values.
/// Matching uses a 0.01 tolerance; when nothing matches it returns the value
/// as a rounded percentage string (e.g. "35%") so callers always get text.
String findOptionLabel(
  double value,
  List<String> labels, {
  List<double>? values,
}) {
  final count = labels.length;
  for (var i = 0; i < count; i++) {
    final expectedValue = values != null && i < values.length
        ? values[i]
        : (count == 1 ? 0.5 : i / (count - 1));
    if ((expectedValue - value).abs() < 0.01) {
      return labels[i];
    }
  }
  return '${(value * 100).round()}%';
}
