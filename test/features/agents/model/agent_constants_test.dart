import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

void main() {
  group('AgentKinds', () {
    test('projectAgent constant has expected value', () {
      expect(AgentKinds.projectAgent, equals('project_agent'));
    });

    test('all kind constants are distinct', () {
      final kinds = [
        AgentKinds.taskAgent,
        AgentKinds.templateImprover,
        AgentKinds.projectAgent,
      ];
      expect(kinds.toSet().length, equals(kinds.length));
    });
  });

  group('AgentLinkTypes', () {
    test('agentProject constant has expected value', () {
      expect(AgentLinkTypes.agentProject, equals('agent_project'));
    });

    test('all link type constants are distinct', () {
      final types = [
        AgentLinkTypes.basic,
        AgentLinkTypes.agentState,
        AgentLinkTypes.messagePrev,
        AgentLinkTypes.messagePayload,
        AgentLinkTypes.toolEffect,
        AgentLinkTypes.agentTask,
        AgentLinkTypes.templateAssignment,
        AgentLinkTypes.improverTarget,
        AgentLinkTypes.agentProject,
      ];
      expect(types.toSet().length, equals(types.length));
    });
  });

  group('AgentTemplateKind', () {
    test('projectAgent enum value exists', () {
      expect(
        AgentTemplateKind.values,
        contains(AgentTemplateKind.projectAgent),
      );
    });

    test('projectAgent name is "projectAgent"', () {
      expect(AgentTemplateKind.projectAgent.name, equals('projectAgent'));
    });

    test('parseEnumByName resolves projectAgent from camelCase', () {
      final result = parseEnumByName(
        AgentTemplateKind.values,
        'projectAgent',
      );
      expect(result, equals(AgentTemplateKind.projectAgent));
    });

    test('parseEnumByName resolves project_agent from snake_case', () {
      final result = parseEnumByName(
        AgentTemplateKind.values,
        'project_agent',
      );
      expect(result, equals(AgentTemplateKind.projectAgent));
    });
  });
}
