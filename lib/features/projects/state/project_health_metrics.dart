import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';

/// User-facing health bands for project overviews.
enum ProjectHealthBand {
  surviving,
  onTrack,
  watch,
  atRisk,
  blocked,
}

extension ProjectHealthBandSeverity on ProjectHealthBand {
  /// Lower values represent worse health for dashboard sorting.
  int get severityRank => switch (this) {
    ProjectHealthBand.blocked => 0,
    ProjectHealthBand.atRisk => 1,
    ProjectHealthBand.watch => 2,
    ProjectHealthBand.surviving => 3,
    ProjectHealthBand.onTrack => 4,
  };
}

@immutable
class ProjectHealthMetrics {
  const ProjectHealthMetrics({
    required this.band,
    required this.rationale,
    this.confidence,
  });

  final ProjectHealthBand band;
  final String rationale;
  final double? confidence;
}

/// Parses the user-facing project health from an agent-authored report.
ProjectHealthMetrics? projectHealthMetricsFromReport(AgentReportEntity report) {
  return projectHealthMetricsFromProvenance(report.provenance);
}

/// Parses the user-facing project health from report provenance.
ProjectHealthMetrics? projectHealthMetricsFromProvenance(
  Map<String, Object?> provenance,
) {
  final rawBand = provenance[ProjectAgentReportProvenanceKeys.healthBand];
  final rawRationale =
      provenance[ProjectAgentReportProvenanceKeys.healthRationale];
  final confidence =
      provenance[ProjectAgentReportProvenanceKeys.healthConfidence];

  final band = rawBand is String ? parseProjectHealthBand(rawBand) : null;
  final rationale = rawRationale is String ? rawRationale.trim() : '';

  if (band == null || rationale.isEmpty) return null;

  return ProjectHealthMetrics(
    band: band,
    rationale: rationale,
    confidence: parseHealthConfidence(confidence),
  );
}

/// Parses project health bands from canonical and slightly varied wire values.
ProjectHealthBand? parseProjectHealthBand(String raw) {
  final normalized = raw.trim().toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  return switch (normalized) {
    'surviving' => ProjectHealthBand.surviving,
    'ontrack' => ProjectHealthBand.onTrack,
    'watch' => ProjectHealthBand.watch,
    'atrisk' => ProjectHealthBand.atRisk,
    'blocked' => ProjectHealthBand.blocked,
    _ => null,
  };
}

/// Parses a confidence value (0–1) from a number or string.
///
/// Returns `null` for `null`, non-finite values (e.g. NaN, infinity),
/// or values outside the 0–1 range.
double? parseHealthConfidence(Object? value) {
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

/// Compares health bands for list sorting while keeping missing health last.
int compareProjectHealthBands(
  ProjectHealthBand? left,
  ProjectHealthBand? right, {
  bool worstFirst = true,
}) {
  if (left == null || right == null) {
    if (left == null && right == null) return 0;
    return left == null ? 1 : -1;
  }

  final order = left.severityRank.compareTo(right.severityRank);
  return worstFirst ? order : -order;
}
