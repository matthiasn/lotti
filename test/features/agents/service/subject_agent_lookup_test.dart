import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/subject_agent_lookup.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';

void main() {
  late MockAgentRepository repository;
  late MockAgentService agentService;
  late SubjectAgentResolver resolver;

  const subjectId = 'subject-1';
  final createdAt = DateTime(2026, 8, 14, 9);

  AgentLink link({
    required String type,
    required String fromId,
    String toId = subjectId,
    DateTime? at,
  }) {
    final stamp = at ?? createdAt;
    return AgentLink.basic(
      id: '$type-$fromId',
      fromId: fromId,
      toId: toId,
      createdAt: stamp,
      updatedAt: stamp,
      vectorClock: null,
    );
  }

  /// Stubs every subject link type as empty, so each test only declares the
  /// one type it cares about.
  void stubNoLinks() {
    for (final type in subjectAgentLinkTypes) {
      when(
        () => repository.getLinksTo(any(), type: type),
      ).thenAnswer((_) async => []);
    }
  }

  void stubLinks(String type, List<AgentLink> links) {
    when(
      () => repository.getLinksTo(subjectId, type: type),
    ).thenAnswer((_) async => links);
  }

  setUp(() {
    repository = MockAgentRepository();
    agentService = MockAgentService();
    resolver = SubjectAgentResolver(repository, agentService);
    stubNoLinks();
  });

  group('link-type coverage', () {
    test('the walked types are exactly the entity kinds that own agents', () {
      expect(subjectAgentLinkTypes, [
        AgentLinkTypes.agentTask,
        AgentLinkTypes.agentProject,
        AgentLinkTypes.agentEvent,
        AgentLinkTypes.agentRelationship,
      ]);
    });

    // A day agent's subject is a date key, not an entity a recording can hang
    // off; admitting it would let a date string resolve someone else's agent.
    test('day agents are deliberately excluded', () {
      expect(subjectAgentLinkTypes, isNot(contains(AgentLinkTypes.agentDay)));
    });

    for (final type in subjectAgentLinkTypes) {
      test('resolves the agent behind an $type link', () async {
        final agent = makeTestIdentity(agentId: 'agent-for-$type');
        stubLinks(type, [link(type: type, fromId: 'agent-for-$type')]);
        when(
          () => agentService.getAgent('agent-for-$type'),
        ).thenAnswer((_) async => agent);

        expect(await resolver(subjectId), agent);
      });
    }
  });

  group('no agent', () {
    test('returns null when the subject carries no link at all', () async {
      expect(await resolver(subjectId), isNull);
      verifyNever(() => agentService.getAgent(any()));
    });

    // The entity *has* an agent; it just is not loadable. Falling through to
    // the next link type here would attach a foreign agent to the subject.
    test('returns null — not the next kind — when the link dangles', () async {
      stubLinks(AgentLinkTypes.agentTask, [
        link(type: AgentLinkTypes.agentTask, fromId: 'gone'),
      ]);
      stubLinks(AgentLinkTypes.agentRelationship, [
        link(type: AgentLinkTypes.agentRelationship, fromId: 'other'),
      ]);
      when(() => agentService.getAgent('gone')).thenAnswer((_) async => null);

      expect(await resolver(subjectId), isNull);
      verifyNever(() => agentService.getAgent('other'));
    });
  });

  group('resolution order', () {
    test('stops at the first type that has a link', () async {
      final taskAgent = makeTestIdentity(agentId: 'task-agent');
      stubLinks(AgentLinkTypes.agentTask, [
        link(type: AgentLinkTypes.agentTask, fromId: 'task-agent'),
      ]);
      stubLinks(AgentLinkTypes.agentRelationship, [
        link(type: AgentLinkTypes.agentRelationship, fromId: 'rel-agent'),
      ]);
      when(
        () => agentService.getAgent('task-agent'),
      ).thenAnswer((_) async => taskAgent);

      expect(await resolver(subjectId), taskAgent);
      verifyNever(
        () => repository.getLinksTo(
          subjectId,
          type: AgentLinkTypes.agentRelationship,
        ),
      );
    });

    // Same tiebreak as the task path: newest link wins, ties broken by id.
    test('picks the primary link when a subject carries several', () async {
      final newer = makeTestIdentity(agentId: 'newer');
      stubLinks(AgentLinkTypes.agentRelationship, [
        link(
          type: AgentLinkTypes.agentRelationship,
          fromId: 'older',
          at: createdAt.subtract(const Duration(days: 1)),
        ),
        link(
          type: AgentLinkTypes.agentRelationship,
          fromId: 'newer',
          at: createdAt,
        ),
      ]);
      when(() => agentService.getAgent('newer')).thenAnswer((_) async => newer);

      expect(await resolver(subjectId), newer);
      verifyNever(() => agentService.getAgent('older'));
    });
  });

  group('provider', () {
    test('builds the resolver from the agent repository and service', () {
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          agentServiceProvider.overrideWithValue(agentService),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(subjectAgentResolverProvider),
        isA<SubjectAgentResolver>(),
      );
    });
  });
}
