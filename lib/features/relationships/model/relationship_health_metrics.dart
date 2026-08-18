import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/report_health_band.dart';

/// User-facing relationship health bands (ADR 0040 Decision 3), parsed
/// from briefing-report provenance exactly like `ProjectHealthMetrics` —
/// through the shared `report_health_band.dart` rules.
enum RelationshipHealthBand {
  thriving,
  steady,
  needsAttention,
  strained,
}

/// Provenance keys under which the briefing's structured health verdict
/// rides on the report entity (the `ProjectAgentReportProvenanceKeys`
/// pattern: structured facts as provenance, never reparsed from markdown).
abstract final class RelationshipReportProvenanceKeys {
  static const healthBand = 'relationship_health_band';
  static const healthRationale = 'relationship_health_rationale';
  static const healthConfidence = 'relationship_health_confidence';
}

/// The user-facing health summary parsed from a relationship briefing: the
/// [band], a free-text [rationale], and an optional model [confidence] in
/// `[0, 1]`.
@immutable
class RelationshipHealthMetrics {
  const RelationshipHealthMetrics({
    required this.band,
    required this.rationale,
    this.confidence,
  });

  final RelationshipHealthBand band;
  final String rationale;
  final double? confidence;
}

/// Parses the health verdict from a briefing report, or null when the
/// report carries none (or a malformed one — an unknown band never becomes
/// a rendered chip).
RelationshipHealthMetrics? relationshipHealthMetricsFromReport(
  AgentReportEntity report,
) => relationshipHealthMetricsFromProvenance(report.provenance);

/// Parses the health verdict from raw report provenance.
RelationshipHealthMetrics? relationshipHealthMetricsFromProvenance(
  Map<String, Object?> provenance,
) {
  final rawBand = provenance[RelationshipReportProvenanceKeys.healthBand];
  final rawRationale =
      provenance[RelationshipReportProvenanceKeys.healthRationale];
  final band = rawBand is String
      ? parseReportHealthBand(rawBand, {
          for (final band in RelationshipHealthBand.values) band.name: band,
        })
      : null;
  final rationale = rawRationale is String ? rawRationale.trim() : '';
  if (band == null || rationale.isEmpty) return null;
  return RelationshipHealthMetrics(
    band: band,
    rationale: rationale,
    confidence: parseReportHealthConfidence(
      provenance[RelationshipReportProvenanceKeys.healthConfidence],
    ),
  );
}
