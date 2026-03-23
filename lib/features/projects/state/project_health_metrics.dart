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
    confidence: _parseConfidence(confidence),
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

double? _parseConfidence(Object? value) {
  final parsed = switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };
  if (parsed == null || parsed < 0 || parsed > 1) return null;
  return parsed;
}
