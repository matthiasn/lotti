import 'package:lotti/features/sync/matrix/stats.dart';

/// Builds a stable signature string for the provided [stats]. Used to
/// deduplicate emissions to listeners when nothing semantically changed.
String buildMatrixStatsSignature(MatrixStats stats) {
  return _buildSignature(stats.messageCounts, sentCount: stats.sentCount);
}

/// Nullable convenience wrapper around [buildMatrixStatsSignature].
String? matrixStatsSignature(MatrixStats? stats) {
  if (stats == null) return null;
  return buildMatrixStatsSignature(stats);
}

/// Builds a deterministic signature for metrics map payloads. Keys are sorted
/// to avoid ordering differences across runs.
String buildMetricsMapSignature(Map<String, int> metrics) {
  return _buildSignature(metrics);
}

/// Nullable convenience wrapper around [buildMetricsMapSignature].
String? metricsMapSignature(Map<String, int>? metrics) {
  if (metrics == null || metrics.isEmpty) return null;
  return buildMetricsMapSignature(metrics);
}

String _buildSignature(
  Map<String, int> map, {
  int? sentCount,
}) {
  final keys = map.keys.toList()..sort();
  final buffer = StringBuffer();
  if (sentCount != null) {
    buffer
      ..write('sent=')
      ..write(sentCount)
      ..write(';');
  }
  for (final key in keys) {
    buffer
      ..write(key)
      ..write('=')
      ..write(map[key] ?? 0)
      ..write(';');
  }
  return buffer.toString();
}
