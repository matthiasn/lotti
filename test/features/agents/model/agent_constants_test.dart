import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';

void main() {
  group('AgentKinds', () {
    test('projectAgent constant has expected value', () {
      expect(AgentKinds.projectAgent, equals('project_agent'));
    });

    test('dayAgent constant has expected value', () {
      expect(AgentKinds.dayAgent, equals('day_agent'));
    });

    test('all kind constants are distinct', () {
      final kinds = [
        AgentKinds.taskAgent,
        AgentKinds.dayAgent,
        AgentKinds.templateImprover,
        AgentKinds.projectAgent,
        AgentKinds.goalAgent,
        AgentKinds.relationshipAgent,
      ];
      expect(kinds.toSet().length, equals(kinds.length));
    });
  });

  test('the visible conversation carrier keeps its durable tool name', () {
    expect(
      AgentConversationToolNames.replyToUser,
      equals('reply_to_user'),
    );
  });

  group('AgentLinkTypes', () {
    test('agentProject constant has expected value', () {
      expect(AgentLinkTypes.agentProject, equals('agent_project'));
    });

    test('capture reconcile constants have expected values', () {
      expect(
        AgentLinkTypes.captureToParsedItem,
        equals('capture_to_parsed_item'),
      );
      expect(AgentLinkTypes.parsedItemToTask, equals('parsed_item_to_task'));
      expect(AgentLinkTypes.captureToPlan, equals('capture_to_plan'));
    });

    test('all link type constants are distinct', () {
      final types = [
        AgentLinkTypes.basic,
        AgentLinkTypes.agentState,
        AgentLinkTypes.messagePrev,
        AgentLinkTypes.messagePayload,
        AgentLinkTypes.toolEffect,
        AgentLinkTypes.agentTask,
        AgentLinkTypes.captureToParsedItem,
        AgentLinkTypes.parsedItemToTask,
        AgentLinkTypes.captureToPlan,
        AgentLinkTypes.templateAssignment,
        AgentLinkTypes.improverTarget,
        AgentLinkTypes.agentProject,
        AgentLinkTypes.agentRelationship,
        AgentLinkTypes.soulAssignment,
      ];
      expect(types.toSet().length, equals(types.length));
    });
  });

  group('relationship agent deterministic ids (ADR 0059 Decision 2)', () {
    test('agent, link, and register ids derive from the relationship — '
        'two devices marking the same person converge on one agent', () {
      expect(
        relationshipAgentIdFor('person-1'),
        'relationship_agent:person-1',
      );
      expect(
        relationshipAgentLinkId(relationshipAgentIdFor('person-1')),
        'agent_relationship:relationship_agent:person-1',
      );
      expect(
        relationshipHealthId(relationshipAgentIdFor('person-1')),
        'relationship_health:relationship_agent:person-1',
      );
    });
  });

  group('AgentEntityTypes', () {
    test('capture reconcile constants use the locked type tags', () {
      expect(AgentEntityTypes.capture, equals('day_capture'));
      expect(AgentEntityTypes.parsedItem, equals('parsed_capture_item'));
      expect(AgentEntityTypes.dayPlan, equals('day_plan'));
    });
  });
}
