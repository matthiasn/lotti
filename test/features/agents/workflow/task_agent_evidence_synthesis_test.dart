import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/task_agent_evidence_synthesis.dart';

void main() {
  group('TaskAgentEvidenceSynthesis', () {
    test('uses compact grounding for the exact Flash candidates', () {
      for (final model in ['deepseek-v4.1-flash', 'GLM-5.3-Flash']) {
        expect(TaskAgentEvidenceSynthesis.usesCompactScaffold(model), isTrue);
        expect(
          TaskAgentEvidenceSynthesis.systemDirectiveForModel(model),
          contains('A task\nstatus, action list, or user checkmark is not'),
        );
        expect(
          TaskAgentEvidenceSynthesis.systemDirectiveForModel(model),
          contains('Omit absent\nmetadata completely'),
        );
      }
      for (final model in ['deepseek-v4-flash-0731', 'glm-5.3', 'glm-5.2']) {
        expect(TaskAgentEvidenceSynthesis.usesCompactScaffold(model), isFalse);
        expect(
          TaskAgentEvidenceSynthesis.systemDirectiveForModel(model),
          TaskAgentEvidenceSynthesis.systemDirective,
        );
      }
    });

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
          contains('do not add the umbrella goal'),
        ),
      );
      expect(directive, contains('Praise or a positive reaction alone'));
      expect(directive, contains('does not establish completion or approval'));
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
      expect(description, contains('Tool receipts'));
      expect(description, contains('Do not turn proposal confirmation'));
      expect(description, contains('Preserve current dates and estimates'));
      expect(
        description,
        contains('Omit retired or superseded metadata values'),
      );
      expect(description, contains('test each conditional section'));
      expect(description, contains('decision the user can make now'));
    });

    test(
      'resolves implementation references before adding checklist steps',
      () {
        final description = TaskAgentEvidenceSynthesis.toolDescription(
          'add_multiple_checklist_items',
          'Add checklist actions.',
        );
        expect(description, startsWith('Add checklist actions.'));
        expect(
          description,
          contains('Resolve references such as "implement it"'),
        );
        expect(description, contains('one implementation action'));
        expect(description, contains('Keep distinct reviews'));
      },
    );

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
      final contentDescription =
          (optimizedProperties['content']!
              as Map<String, dynamic>)['description'];
      expect(contentDescription, contains('active report directive'));
      expect(contentDescription, contains('heading must be present'));
      expect(contentDescription, contains('with its exact spelling'));
      expect(contentDescription, contains('inline link elsewhere'));
      expect(
        (baseProperties['content']! as Map<String, dynamic>)['description'],
        'Original content.',
      );
    });

    test('selects only the exact evaluated model profiles', () {
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
      expect(
        TaskAgentEvidenceSynthesis.usesCompactScaffold('qwen3.6:35b-a3b'),
        isFalse,
      );
      expect(
        TaskAgentEvidenceSynthesis.systemDirectiveForModel(
          'mistral-medium-latest',
        ),
        TaskAgentEvidenceSynthesis.systemDirective,
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
