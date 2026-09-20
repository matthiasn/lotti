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

  test('parses band and rationale from report provenance', () {
    final metrics = relationshipHealthMetricsFromReport(
      report({
        RelationshipReportProvenanceKeys.healthBand: 'needsAttention',
        RelationshipReportProvenanceKeys.healthRationale:
            'Two strained calls in a row, per your own sentiments.',
      }),
    )!;
    expect(metrics.band, RelationshipHealthBand.needsAttention);
    expect(metrics.rationale, contains('strained calls'));
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

  // Briefings written before the confidence was retired still carry the key.
  // Reading one must not fail, and must not resurrect the field either.
  test('a briefing that still carries a confidence reads as any other', () {
    final metrics = relationshipHealthMetricsFromProvenance({
      RelationshipReportProvenanceKeys.healthBand: 'thriving',
      RelationshipReportProvenanceKeys.healthRationale: 'evidence',
      'relationship_health_confidence': 0.8,
    })!;
    expect(metrics.band, RelationshipHealthBand.thriving);
    expect(metrics.rationale, 'evidence');
  });
}
