import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../test_utils.dart';

void main() {
  late MockTemplateEvolutionWorkflow mockWorkflow;
  late ProviderContainer container;

  final testClock = Clock.fixed(DateTime(2024, 3, 15, 10, 30));
  final testVersion = makeTestTemplateVersion();

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockWorkflow = MockTemplateEvolutionWorkflow();
  });

  ProviderContainer createContainer({
    FutureOr<AgentDomainEntity?> Function(Ref, String)? versionOverride,
  }) {
    final c = ProviderContainer(
      overrides: [
        templateEvolutionWorkflowProvider.overrideWithValue(mockWorkflow),
        activeTemplateVersionProvider.overrideWith(
          versionOverride ?? (ref, id) async => testVersion,
        ),
        agentTemplatesProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        templatePerformanceMetricsProvider.overrideWith(
          (ref, id) async => makeTestMetrics(),
        ),
        templateVersionHistoryProvider.overrideWith(
          (ref, id) async => <AgentDomainEntity>[],
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('EvolutionChatState', () {
    group('build', () {
      test('starts session and returns data with opening message', () async {
        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => 'Welcome to the evolution session!');

        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(
          ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestTemplateId,
            conversationId: 'conv-1',
            strategy: EvolutionStrategy(),
            modelId: 'model-1',
          ),
        );

        when(() => mockWorkflow.getCurrentProposal(sessionId: 'session-1'))
            .thenReturn(null);

        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        expect(data.sessionId, 'session-1');
        expect(data.messages.length, 2);
        expect(data.messages[0], isA<EvolutionSystemMessage>());
        expect(data.messages[1], isA<EvolutionAssistantMessage>());
        expect(
          (data.messages[1] as EvolutionAssistantMessage).text,
          'Welcome to the evolution session!',
        );
        expect(data.isWaiting, isFalse);
        expect(data.proposal, isNull);
        expect(data.currentDirectives, 'You are a helpful agent.');
      });

      test('returns error state when startSession returns null', () async {
        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => null);

        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(null);

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        expect(data.sessionId, isNull);
        expect(data.messages.length, 2);
        expect(data.messages[1], isA<EvolutionSystemMessage>());
        expect(
          (data.messages[1] as EvolutionSystemMessage).text,
          'session_error',
        );
      });

      test('includes proposal if opening response contains one', () async {
        const testProposal = PendingProposal(
          directives: 'new directives',
          rationale: 'better performance',
        );

        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => 'Here is my proposal.');

        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(
          ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestTemplateId,
            conversationId: 'conv-1',
            strategy: EvolutionStrategy(),
            modelId: 'model-1',
          ),
        );

        when(() => mockWorkflow.getCurrentProposal(sessionId: 'session-1'))
            .thenReturn(testProposal);

        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        expect(data.proposal, testProposal);
        expect(data.messages.length, 3);
        expect(data.messages[2], isA<EvolutionProposalMessage>());
      });
    });

    group('sendMessage', () {
      test('adds user message and assistant response', () async {
        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => 'Hello!');

        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(
          ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestTemplateId,
            conversationId: 'conv-1',
            strategy: EvolutionStrategy(),
            modelId: 'model-1',
          ),
        );

        when(() => mockWorkflow.getCurrentProposal(sessionId: 'session-1'))
            .thenReturn(null);

        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});

        when(
          () => mockWorkflow.sendMessage(
            sessionId: 'session-1',
            userMessage: 'Improve error handling',
          ),
        ).thenAnswer((_) async => 'I suggest adding retries.');

        container = createContainer();
        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .sendMessage('Improve error handling'),
        );

        final data =
            container.read(evolutionChatStateProvider(kTestTemplateId)).value!;

        // system + assistant (opening) + user + assistant (response)
        expect(data.messages.length, 4);
        expect(data.messages[2], isA<EvolutionUserMessage>());
        expect(
          (data.messages[2] as EvolutionUserMessage).text,
          'Improve error handling',
        );
        expect(data.messages[3], isA<EvolutionAssistantMessage>());
        expect(
          (data.messages[3] as EvolutionAssistantMessage).text,
          'I suggest adding retries.',
        );
        expect(data.isWaiting, isFalse);
      });
    });

    group('rejectProposal', () {
      test('removes proposal messages and adds rejection system message',
          () async {
        const testProposal = PendingProposal(
          directives: 'new',
          rationale: 'better',
        );

        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => 'Here is a proposal.');

        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(
          ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestTemplateId,
            conversationId: 'conv-1',
            strategy: EvolutionStrategy(),
            modelId: 'model-1',
          ),
        );

        when(() => mockWorkflow.getCurrentProposal(sessionId: 'session-1'))
            .thenReturn(testProposal);

        when(() => mockWorkflow.rejectProposal(sessionId: 'session-1'))
            .thenReturn(null);

        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});

        container = createContainer();
        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        withClock(testClock, () {
          container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .rejectProposal();
        });

        final data =
            container.read(evolutionChatStateProvider(kTestTemplateId)).value!;

        expect(data.proposal, isNull);
        // No proposal messages should remain
        expect(
          data.messages.whereType<EvolutionProposalMessage>().toList(),
          isEmpty,
        );
        // Should have a rejection system message
        final systemMessages =
            data.messages.whereType<EvolutionSystemMessage>().toList();
        expect(
          systemMessages.any((m) => m.text == 'proposal_rejected'),
          isTrue,
        );
      });
    });
  });

  group('EvolutionChatData', () {
    test('copyWith preserves unchanged fields', () {
      const data = EvolutionChatData(
        sessionId: 'session-1',
        messages: [],
        currentDirectives: 'original',
      );

      final updated = data.copyWith(isWaiting: true);

      expect(updated.sessionId, 'session-1');
      expect(updated.messages, isEmpty);
      expect(updated.isWaiting, isTrue);
      expect(updated.currentDirectives, 'original');
    });

    test('copyWith sets proposal to null via function', () {
      const proposal = PendingProposal(
        directives: 'd',
        rationale: 'r',
      );
      const data = EvolutionChatData(
        messages: [],
        proposal: proposal,
      );

      final updated = data.copyWith(proposal: () => null);
      expect(updated.proposal, isNull);
    });
  });
}
