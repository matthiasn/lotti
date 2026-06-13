import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  group('task planning, attention & reporting tool definitions', () {
    group('get_related_task_details', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.getRelatedTaskDetails,
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals(TaskAgentToolNames.getRelatedTaskDetails));
        expect(tool.description, contains('related task'));
        expect(tool.description, contains('same parent project'));
      });

      test('requires a string taskId parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final taskIdProp = properties['taskId'] as Map;
        expect(taskIdProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('taskId'));
      });
    });

    group('request_attention', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.requestAttention,
        );
      });

      test('has correct name and planner-facing description', () {
        expect(tool.name, equals(TaskAgentToolNames.requestAttention));
        expect(tool.description, contains('day planner'));
        expect(tool.description, contains('Attention Requests'));
      });

      test('requires bounded claim fields', () {
        final required = tool.parameters['required'] as List;
        expect(
          required,
          containsAll([
            'requestedMinutes',
            'impact',
            'urgency',
            'energyFit',
            'rationale',
          ]),
        );

        final properties = tool.parameters['properties'] as Map;
        final minutes = properties['requestedMinutes'] as Map;
        expect(minutes['type'], equals('integer'));
        expect(minutes['minimum'], equals(1));
        expect(minutes['maximum'], equals(1440));
        final impact = properties['impact'] as Map;
        expect(impact['minimum'], equals(1));
        expect(impact['maximum'], equals(5));
        final urgency = properties['urgency'] as Map;
        expect(urgency['minimum'], equals(1));
        expect(urgency['maximum'], equals(5));
      });

      test('declares energy and scope enums', () {
        final properties = tool.parameters['properties'] as Map;
        expect(
          (properties['energyFit'] as Map)['enum'],
          equals(['low', 'neutral', 'high']),
        );
        expect(
          (properties['scopeKind'] as Map)['enum'],
          equals(['day', 'dateRange', 'deadline', 'recurrence']),
        );
      });

      test('is immediate, not a user-confirmed deferred tool', () {
        expect(
          AgentToolRegistry.deferredTools,
          isNot(contains(TaskAgentToolNames.requestAttention)),
        );
      });
    });

    group('resolve_attention_request', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.resolveAttentionRequest,
        );
      });

      test('has correct name and maintenance description', () {
        expect(tool.name, equals(TaskAgentToolNames.resolveAttentionRequest));
        expect(tool.description, contains('own active attention requests'));
        expect(tool.description, contains('request_attention'));
      });

      test('requires request id, status, and reason', () {
        final required = tool.parameters['required'] as List;
        expect(required, containsAll(['requestId', 'status', 'reason']));

        final properties = tool.parameters['properties'] as Map;
        expect((properties['requestId'] as Map)['type'], equals('string'));
        expect((properties['reason'] as Map)['maxLength'], equals(500));
      });

      test('declares safe task-agent disposition statuses', () {
        final properties = tool.parameters['properties'] as Map;
        expect(
          (properties['status'] as Map)['enum'],
          equals([
            'withdrawn',
            'satisfied',
            'partiallySatisfied',
            'deferred',
          ]),
        );
      });

      test('is immediate, not a user-confirmed deferred tool', () {
        expect(
          AgentToolRegistry.deferredTools,
          isNot(contains(TaskAgentToolNames.resolveAttentionRequest)),
        );
      });
    });

    group('update_report', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'update_report',
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals('update_report'));
        expect(tool.description, contains('report'));
      });

      test('requires oneLiner, tldr, and content parameters', () {
        final properties = tool.parameters['properties'] as Map;
        final oneLinerProp = properties['oneLiner'] as Map;
        expect(oneLinerProp['type'], equals('string'));
        final tldrProp = properties['tldr'] as Map;
        expect(tldrProp['type'], equals('string'));
        final contentProp = properties['content'] as Map;
        expect(contentProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('oneLiner'));
        expect(tool.parameters['required'], contains('tldr'));
        expect(tool.parameters['required'], contains('content'));
        expect(properties.containsKey('markdown'), isFalse);
      });
    });

    group('record_observations', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'record_observations',
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals('record_observations'));
        expect(tool.description, contains('observations'));
      });

      test('requires an array observations parameter with object items', () {
        final properties = tool.parameters['properties'] as Map;
        final obsProp = properties['observations'] as Map;
        expect(obsProp['type'], equals('array'));

        final items = obsProp['items'] as Map;
        expect(items['type'], equals('object'));
        expect(items['required'], contains('text'));

        final itemProps = items['properties'] as Map;
        expect((itemProps['text'] as Map)['type'], equals('string'));
        expect((itemProps['priority'] as Map)['type'], equals('string'));
        expect(
          (itemProps['priority'] as Map)['enum'],
          containsAll(['routine', 'notable', 'critical']),
        );
        expect((itemProps['category'] as Map)['type'], equals('string'));
        expect(
          (itemProps['category'] as Map)['enum'],
          containsAll([
            'grievance',
            'excellence',
            'template_improvement',
            'operational',
          ]),
        );

        expect(tool.parameters['required'], contains('observations'));
      });
    });

    group('retract_suggestions tool', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.retractSuggestions,
        );
      });

      test('has correct name', () {
        expect(tool.name, equals(TaskAgentToolNames.retractSuggestions));
        expect(tool.name, equals('retract_suggestions'));
      });

      test('requires proposals array', () {
        final required = tool.parameters['required'] as List;
        expect(required, contains('proposals'));
      });

      test('proposals array has minItems: 1', () {
        final properties = tool.parameters['properties'] as Map;
        final proposalsProp = properties['proposals'] as Map;
        expect(proposalsProp['type'], equals('array'));
        expect(proposalsProp['minItems'], equals(1));
      });

      test('proposals items require fingerprint and reason', () {
        final properties = tool.parameters['properties'] as Map;
        final proposalsProp = properties['proposals'] as Map;
        final itemSchema = proposalsProp['items'] as Map;
        final itemRequired = itemSchema['required'] as List;
        expect(itemRequired, containsAll(['fingerprint', 'reason']));
      });

      test('reason has minLength: 1 and maxLength: 500', () {
        final properties = tool.parameters['properties'] as Map;
        final proposalsProp = properties['proposals'] as Map;
        final itemSchema = proposalsProp['items'] as Map;
        final itemProps = itemSchema['properties'] as Map;
        final reasonProp = itemProps['reason'] as Map;
        expect(reasonProp['type'], equals('string'));
        expect(reasonProp['minLength'], equals(1));
        expect(reasonProp['maxLength'], equals(500));
      });

      test('fingerprint is a string property', () {
        final properties = tool.parameters['properties'] as Map;
        final proposalsProp = properties['proposals'] as Map;
        final itemSchema = proposalsProp['items'] as Map;
        final itemProps = itemSchema['properties'] as Map;
        expect((itemProps['fingerprint'] as Map)['type'], equals('string'));
      });

      test('is not in deferredTools (immediate retraction)', () {
        expect(
          AgentToolRegistry.deferredTools,
          isNot(contains(TaskAgentToolNames.retractSuggestions)),
        );
      });
    });
  });
}
