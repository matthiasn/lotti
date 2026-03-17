import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';

void main() {
  group('ProjectAgentToolNames', () {
    test('constants have expected values', () {
      expect(
        ProjectAgentToolNames.updateProjectReport,
        equals('update_project_report'),
      );
      expect(
        ProjectAgentToolNames.recordObservations,
        equals('record_observations'),
      );
      expect(
        ProjectAgentToolNames.recommendNextSteps,
        equals('recommend_next_steps'),
      );
      expect(
        ProjectAgentToolNames.updateProjectStatus,
        equals('update_project_status'),
      );
      expect(
        ProjectAgentToolNames.createTask,
        equals('create_task'),
      );
    });
  });

  group('projectAgentTools', () {
    test('contains exactly 5 tool definitions', () {
      expect(projectAgentTools, hasLength(5));
    });

    test('all tools have non-empty name and description', () {
      for (final tool in projectAgentTools) {
        expect(tool.name, isNotEmpty, reason: 'Tool name must not be empty');
        expect(
          tool.description,
          isNotEmpty,
          reason: 'Tool description must not be empty for ${tool.name}',
        );
      }
    });

    test(
      'all tools have object-type parameter schemas with required fields',
      () {
        for (final tool in projectAgentTools) {
          expect(
            tool.parameters['type'],
            equals('object'),
            reason: '${tool.name} parameters must be type=object',
          );
          expect(
            tool.parameters['properties'],
            isA<Map<String, dynamic>>(),
            reason: '${tool.name} must have properties',
          );
          expect(
            tool.parameters['required'],
            isA<List<dynamic>>(),
            reason: '${tool.name} must have required list',
          );
          final required = tool.parameters['required'] as List;
          expect(
            required,
            isNotEmpty,
            reason: '${tool.name} must require at least one parameter',
          );
        }
      },
    );

    test('tool names are unique', () {
      final names = projectAgentTools.map((t) => t.name).toList();
      expect(names.toSet().length, equals(names.length));
    });

    group('update_project_report', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = projectAgentTools.firstWhere(
          (t) => t.name == ProjectAgentToolNames.updateProjectReport,
        );
      });

      test('has correct name and mentions report in description', () {
        expect(tool.name, equals('update_project_report'));
        expect(tool.description, contains('report'));
      });

      test('requires markdown parameter and accepts optional tldr', () {
        final properties = tool.parameters['properties'] as Map;
        final markdownProp = properties['markdown'] as Map;
        expect(markdownProp['type'], equals('string'));
        final tldrProp = properties['tldr'] as Map;
        expect(tldrProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('markdown'));
      });
    });

    group('record_observations', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = projectAgentTools.firstWhere(
          (t) => t.name == ProjectAgentToolNames.recordObservations,
        );
      });

      test('has correct name', () {
        expect(tool.name, equals('record_observations'));
      });

      test('requires observations array with oneOf (string or object)', () {
        final properties = tool.parameters['properties'] as Map;
        final obsProp = properties['observations'] as Map;
        expect(obsProp['type'], equals('array'));
        final items = obsProp['items'] as Map;
        expect(items['oneOf'], isA<List<dynamic>>());
        final oneOf = items['oneOf'] as List<dynamic>;
        expect(oneOf, hasLength(2));

        // First variant: plain string
        expect((oneOf[0] as Map)['type'], equals('string'));

        // Second variant: structured object
        final objectVariant = oneOf[1] as Map;
        expect(objectVariant['type'], equals('object'));
        final objProps = objectVariant['properties'] as Map;
        expect((objProps['text'] as Map)['type'], equals('string'));
        expect(
          (objProps['priority'] as Map)['enum'],
          containsAll(['routine', 'notable', 'critical']),
        );
        expect(
          (objProps['category'] as Map)['enum'],
          containsAll([
            'grievance',
            'excellence',
            'templateImprovement',
            'operational',
          ]),
        );
        expect(objectVariant['required'], contains('text'));

        expect(tool.parameters['required'], contains('observations'));
      });
    });

    group('recommend_next_steps', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = projectAgentTools.firstWhere(
          (t) => t.name == ProjectAgentToolNames.recommendNextSteps,
        );
      });

      test('has correct name and mentions next steps', () {
        expect(tool.name, equals('recommend_next_steps'));
        expect(tool.description, contains('next steps'));
      });

      test('requires steps array with structured objects', () {
        final properties = tool.parameters['properties'] as Map;
        final stepsProp = properties['steps'] as Map;
        expect(stepsProp['type'], equals('array'));
        final items = stepsProp['items'] as Map;
        expect(items['type'], equals('object'));
        final itemProps = items['properties'] as Map;
        expect((itemProps['title'] as Map)['type'], equals('string'));
        expect((itemProps['rationale'] as Map)['type'], equals('string'));
        expect(
          (itemProps['priority'] as Map)['enum'],
          containsAll(['high', 'medium', 'low']),
        );
        expect(items['required'], containsAll(['title', 'rationale']));
        expect(tool.parameters['required'], contains('steps'));
      });
    });

    group('update_project_status', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = projectAgentTools.firstWhere(
          (t) => t.name == ProjectAgentToolNames.updateProjectStatus,
        );
      });

      test('has correct name and mentions deferred', () {
        expect(tool.name, equals('update_project_status'));
        expect(tool.description, contains('deferred'));
      });

      test('requires status and reason parameters', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['status'] as Map)['type'], equals('string'));
        expect((properties['reason'] as Map)['type'], equals('string'));
        expect(
          tool.parameters['required'],
          containsAll(['status', 'reason']),
        );
      });
    });

    group('create_task', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = projectAgentTools.firstWhere(
          (t) => t.name == ProjectAgentToolNames.createTask,
        );
      });

      test('has correct name and mentions deferred', () {
        expect(tool.name, equals('create_task'));
        expect(tool.description, contains('deferred'));
      });

      test('requires title and has optional description and priority', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['title'] as Map)['type'], equals('string'));
        expect(
          (properties['description'] as Map)['type'],
          equals('string'),
        );
        expect(
          (properties['priority'] as Map)['enum'],
          containsAll(['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']),
        );
        expect(tool.parameters['required'], contains('title'));
        expect(tool.parameters['required'], isNot(contains('description')));
        expect(tool.parameters['required'], isNot(contains('priority')));
      });
    });
  });

  group('projectDeferredTools', () {
    test('contains exactly 3 deferred tool names', () {
      expect(projectDeferredTools, hasLength(3));
    });

    test(
      'includes recommend_next_steps, update_project_status, create_task',
      () {
        expect(
          projectDeferredTools,
          containsAll([
            ProjectAgentToolNames.recommendNextSteps,
            ProjectAgentToolNames.updateProjectStatus,
            ProjectAgentToolNames.createTask,
          ]),
        );
      },
    );

    test('does not include immediate tools', () {
      expect(
        projectDeferredTools,
        isNot(contains(ProjectAgentToolNames.updateProjectReport)),
      );
      expect(
        projectDeferredTools,
        isNot(contains(ProjectAgentToolNames.recordObservations)),
      );
    });
  });
}
