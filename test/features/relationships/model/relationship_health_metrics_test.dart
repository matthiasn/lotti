import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';

void main() {
  AgentReportEntity report(Map<String, Object?> provenance) =>
      AgentDomainEntity.agentReport(
            id: 'report-1',
            agentId: 'relationship_agent:person-1',
            scope: 'current',
            createdAt: DateTime(2026, 8, 16),
            vectorClock: null,
            content: 'briefing',
            provenance: provenance,
          )
          as AgentReportEntity;

  test('parses band, rationale and confidence from report provenance', () {
    final metrics = relationshipHealthMetricsFromReport(
      report({
        RelationshipReportProvenanceKeys.healthBand: 'needsAttention',
        RelationshipReportProvenanceKeys.healthRationale:
            'Two strained calls in a row, per your own sentiments.',
        RelationshipReportProvenanceKeys.healthConfidence: 0.8,
      }),
    )!;
    expect(metrics.band, RelationshipHealthBand.needsAttention);
    expect(metrics.rationale, contains('strained calls'));
    expect(metrics.confidence, 0.8);
  });

  test('tolerates varied wire spellings of the band', () {
    for (final raw in [
      'needs-attention',
      'Needs Attention',
      'NEEDSATTENTION',
    ]) {
      expect(
        relationshipHealthMetricsFromProvenance({
          RelationshipReportProvenanceKeys.healthBand: raw,
          RelationshipReportProvenanceKeys.healthRationale: 'evidence',
        })?.band,
        RelationshipHealthBand.needsAttention,
        reason: raw,
      );
    }
  });

  test('an unknown band or missing rationale yields no verdict — a chip '
      'never renders from malformed provenance', () {
    expect(
      relationshipHealthMetricsFromProvenance({
        RelationshipReportProvenanceKeys.healthBand: 'flourishing',
        RelationshipReportProvenanceKeys.healthRationale: 'evidence',
      }),
      isNull,
    );
    expect(
      relationshipHealthMetricsFromProvenance({
        RelationshipReportProvenanceKeys.healthBand: 'steady',
        RelationshipReportProvenanceKeys.healthRationale: '   ',
      }),
      isNull,
    );
    expect(relationshipHealthMetricsFromProvenance(const {}), isNull);
  });

  test('an out-of-range confidence is dropped, not clamped', () {
    final metrics = relationshipHealthMetricsFromProvenance({
      RelationshipReportProvenanceKeys.healthBand: 'thriving',
      RelationshipReportProvenanceKeys.healthRationale: 'evidence',
      RelationshipReportProvenanceKeys.healthConfidence: 7,
    })!;
    expect(metrics.confidence, isNull);
  });
}
