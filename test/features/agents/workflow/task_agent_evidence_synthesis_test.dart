import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/task_agent_evidence_synthesis.dart';

void main() {
  group('TaskAgentEvidenceSynthesis', () {
    test('keeps report layout flexible while enforcing grounding', () {
      const directive =
          '${TaskAgentEvidenceSynthesis.reportDirective}'
          '${TaskAgentEvidenceSynthesis.systemDirective}';

      expect(
        directive,
        allOf(
          contains('Write free-form Markdown'),
          contains('headings are optional'),
          contains('Never create a section merely'),
          contains('A checked item proves only'),
          contains('previous report'),
          contains('Report prose is not a substitute'),
        ),
      );
      expect(
        directive,
        allOf(
          contains('Mutation coverage:'),
          contains('latest deadline or date and its purpose'),
          contains('Never name such a concept'),
          contains('A user checkmark alone proves no outcome'),
          contains('not Markdown structure or voice'),
        ),
      );
      expect(
        TaskAgentEvidenceSynthesis.mistralSystemDirective,
        contains('never say that the fix recurred, reverted, or failed'),
      );
    });

    test('appends the evidence scope to the existing tool description', () {
      final description = TaskAgentEvidenceSynthesis.updateReportDescription(
        'Publish the report.',
      );

      expect(description, startsWith('Publish the report.'));
      expect(description, contains('matching successful'));
      expect(description, contains('tool call'));
      expect(description, contains('stale report claims'));
      expect(description, contains('out-of-scope concepts completely'));
    });

    test('aligns field guidance without changing or mutating schema shape', () {
      final base = <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'oneLiner': <String, dynamic>{
            'type': 'string',
            'description': 'Original one-liner.',
          },
          'tldr': <String, dynamic>{
            'type': 'string',
            'description': 'Original TLDR.',
          },
          'content': <String, dynamic>{
            'type': 'string',
            'description': 'Original content.',
          },
        },
        'required': <String>['oneLiner', 'tldr', 'content'],
        'additionalProperties': false,
      };

      final optimized = TaskAgentEvidenceSynthesis.updateReportParameters(base);
      final optimizedProperties =
          optimized['properties']! as Map<String, dynamic>;
      final baseProperties = base['properties']! as Map<String, dynamic>;

      expect(optimized['type'], base['type']);
      expect(optimized['required'], base['required']);
      expect(
        optimized['additionalProperties'],
        base['additionalProperties'],
      );
      expect(optimizedProperties.keys, baseProperties.keys);
      for (final name in baseProperties.keys) {
        final optimizedProperty =
            optimizedProperties[name]! as Map<String, dynamic>;
        final baseProperty = baseProperties[name]! as Map<String, dynamic>;
        expect(optimizedProperty['type'], baseProperty['type']);
      }
      expect(
        (optimizedProperties['content']!
            as Map<String, dynamic>)['description'],
        contains('free-form Markdown'),
      );
      expect(
        (optimizedProperties['content']!
            as Map<String, dynamic>)['description'],
        contains('omit Progress or Achieved entirely'),
      );
      expect(
        (baseProperties['content']! as Map<String, dynamic>)['description'],
        'Original content.',
      );
    });

    test('selects only the matching model-family examples', () {
      final mistral = TaskAgentEvidenceSynthesis.systemDirectiveForModel(
        'mistral-small-4-119b-instruct',
      );
      final qwen = TaskAgentEvidenceSynthesis.systemDirectiveForModel(
        'Qwen3.5-122B-A10B',
      );
      final generic = TaskAgentEvidenceSynthesis.systemDirectiveForModel(
        'glm-5.2',
      );

      expect(mistral, contains('Examples of the boundary:'));
      expect(mistral, contains('Maybe revisit catering later'));
      expect(qwen, isNot(contains('Maybe revisit catering later')));
      expect(qwen, contains(TaskAgentEvidenceSynthesis.systemDirective));
      expect(qwen, contains('## Scope Erasure'));
      expect(generic, TaskAgentEvidenceSynthesis.systemDirective);
      expect(
        TaskAgentEvidenceSynthesis.usesCompactScaffold(
          'mistral-small-4-119b-instruct',
        ),
        isTrue,
      );
      expect(
        TaskAgentEvidenceSynthesis.usesCompactScaffold('Qwen3.5-122B-A10B'),
        isTrue,
      );
      expect(
        TaskAgentEvidenceSynthesis.usesCompactScaffold('glm-5.2'),
        isFalse,
      );
    });

    test('selects free-form Qwen and deadline-safe Mistral reports', () {
      final mistral = TaskAgentEvidenceSynthesis.reportDirectiveForModel(
        'mistral-small-4-119b-instruct',
      );
      final qwen = TaskAgentEvidenceSynthesis.reportDirectiveForModel(
        'qwen3.5-122b-a10b',
      );

      expect(mistral, contains('Include only sections that'));
      expect(mistral, contains('include it and state what it is for'));
      expect(qwen, contains('Write free-form Markdown'));
      expect(qwen, contains('headings are optional'));
    });
  });
}
