import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/model/report_health_band.dart';

/// User-facing health bands for project overviews.
enum ProjectHealthBand {
  surviving,
  onTrack,
  watch,
  atRisk,
  blocked,
}

/// The user-facing health summary parsed from a project-agent report: the
/// [band], a free-text [rationale], and an optional model [confidence] in
/// `[0, 1]`.
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

/// Parses project health bands from canonical and slightly varied wire
/// values (the shared `report_health_band.dart` rules).
ProjectHealthBand? parseProjectHealthBand(String raw) => parseReportHealthBand(
  raw,
  {for (final band in ProjectHealthBand.values) band.name: band},
);

/// Parses a confidence value (0–1) from a number or string — the shared
/// fails-closed rules of `report_health_band.dart`.
double? parseHealthConfidence(Object? value) =>
    parseReportHealthConfidence(value);
