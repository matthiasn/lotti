import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';

import '../../agents/test_utils.dart';

void main() {
  group('projectHealthMetricsFromProvenance', () {
    test('parses agent-authored health fields', () {
      final metrics = projectHealthMetricsFromProvenance({
        ProjectAgentReportProvenanceKeys.healthBand: 'at_risk',
        ProjectAgentReportProvenanceKeys.healthRationale:
            'A key dependency is still slipping.',
        ProjectAgentReportProvenanceKeys.healthConfidence: 0.76,
      });

      expect(metrics, isNotNull);
      expect(metrics!.band, ProjectHealthBand.atRisk);
      expect(metrics.rationale, 'A key dependency is still slipping.');
      expect(metrics.confidence, 0.76);
    });

    test('returns null when the band is missing', () {
      final metrics = projectHealthMetricsFromProvenance({
        ProjectAgentReportProvenanceKeys.healthRationale:
            'The agent forgot to set the band.',
      });

      expect(metrics, isNull);
    });

    test('returns null when the rationale is blank', () {
      final metrics = projectHealthMetricsFromProvenance({
        ProjectAgentReportProvenanceKeys.healthBand: 'watch',
        ProjectAgentReportProvenanceKeys.healthRationale: '   ',
      });

      expect(metrics, isNull);
    });

    test('normalizes human-readable band strings', () {
      final metrics = projectHealthMetricsFromProvenance({
        ProjectAgentReportProvenanceKeys.healthBand: 'On Track',
        ProjectAgentReportProvenanceKeys.healthRationale:
            'The plan is holding.',
      });

      expect(metrics, isNotNull);
      expect(metrics!.band, ProjectHealthBand.onTrack);
    });

    test('ignores invalid confidence values', () {
      final metrics = projectHealthMetricsFromProvenance({
        ProjectAgentReportProvenanceKeys.healthBand: 'blocked',
        ProjectAgentReportProvenanceKeys.healthRationale:
            'Work is paused pending approval.',
        ProjectAgentReportProvenanceKeys.healthConfidence: 1.4,
      });

      expect(metrics, isNotNull);
      expect(metrics!.confidence, isNull);
    });
  });

  group('projectHealthMetricsFromReport', () {
    test('reads the latest agent-authored health from report provenance', () {
      final report = makeTestReport(
        provenance: {
          ProjectAgentReportProvenanceKeys.healthBand: 'surviving',
          ProjectAgentReportProvenanceKeys.healthRationale:
              'The project exists, but the plan is still thin.',
        },
      );

      final metrics = projectHealthMetricsFromReport(report);

      expect(metrics, isNotNull);
      expect(metrics!.band, ProjectHealthBand.surviving);
      expect(
        metrics.rationale,
        'The project exists, but the plan is still thin.',
      );
    });
  });
}
