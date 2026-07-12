import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/task_agent_evidence_synthesis.dart';

void main() {
  group('TaskAgentEvidenceSynthesis', () {
    test('keeps report layout flexible while enforcing grounding', () {
      expect(
        '${TaskAgentEvidenceSynthesis.reportDirective}'
        '${TaskAgentEvidenceSynthesis.systemDirective}',
        allOf(
          contains('compact current-state report'),
          contains('only sections that'),
          contains('A checked item proves only'),
          contains('Compose `oneLiner`, `tldr`, and'),
          contains('Source material that does not affect an'),
        ),
      );
    });

    test('appends the evidence scope to the existing tool description', () {
      final description = TaskAgentEvidenceSynthesis.updateReportDescription(
        'Publish the report.',
      );

      expect(description, startsWith('Publish the report.'));
      expect(description, contains('active execution constraints'));
      expect(description, contains('outside active scope'));
    });
  });
}
