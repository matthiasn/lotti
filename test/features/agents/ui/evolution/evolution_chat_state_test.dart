import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:lotti/features/agents/genui/genui_event_handler.dart';
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

      test('abandons session when startSession returns null but session exists',
          () async {
        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => null);

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

        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        expect(data.sessionId, isNull);
        expect(data.messages.last, isA<EvolutionSystemMessage>());
        expect(
          (data.messages.last as EvolutionSystemMessage).text,
          'session_error',
        );
        // Verify the session was abandoned so it doesn't block future starts.
        verify(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .called(1);
      });

      test('does not add proposal message (proposals handled via GenUI)',
          () async {
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
            .thenReturn(null);

        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        // Only system + assistant messages, no proposal message variant.
        expect(data.messages.length, 2);
        expect(data.messages[0], isA<EvolutionSystemMessage>());
        expect(data.messages[1], isA<EvolutionAssistantMessage>());
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

        when(() => mockWorkflow.getSession(any())).thenReturn(null);

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
      test('adds rejection system message', () async {
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
            .thenReturn(null);

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

        // Should have a rejection system message
        final systemMessages =
            data.messages.whereType<EvolutionSystemMessage>().toList();
        expect(
          systemMessages.any((m) => m.text == 'proposal_rejected'),
          isTrue,
        );
      });
    });

    group('GenUI surface drain', () {
      test('drains surface IDs from opening turn into messages', () async {
        final processor = A2uiMessageProcessor(
          catalogs: [buildEvolutionCatalog()],
        );
        final bridge = GenUiBridge(processor: processor)
          ..handleToolCall({
            'surfaceId': 'surf-opening-1',
            'rootType': 'MetricsSummary',
            'data': {
              'totalWakes': 10,
              'successRate': 0.9,
              'failureCount': 1,
            },
          });

        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => 'Here are your metrics.');
        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(
          ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestTemplateId,
            conversationId: 'conv-1',
            strategy: EvolutionStrategy(genUiBridge: bridge),
            modelId: 'model-1',
            processor: processor,
            genUiBridge: bridge,
            eventHandler: GenUiEventHandler(processor: processor)..listen(),
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

        // system + assistant + surface
        expect(data.messages.length, 3);
        expect(data.messages[2], isA<EvolutionSurfaceMessage>());
        expect(
          (data.messages[2] as EvolutionSurfaceMessage).surfaceId,
          'surf-opening-1',
        );
        expect(data.processor, isNotNull);
      });

      test('drains surface IDs after sendMessage', () async {
        final processor = A2uiMessageProcessor(
          catalogs: [buildEvolutionCatalog()],
        );
        final bridge = GenUiBridge(processor: processor);
        final session = ActiveEvolutionSession(
          sessionId: 'session-1',
          templateId: kTestTemplateId,
          conversationId: 'conv-1',
          strategy: EvolutionStrategy(genUiBridge: bridge),
          modelId: 'model-1',
          processor: processor,
          genUiBridge: bridge,
          eventHandler: GenUiEventHandler(processor: processor)..listen(),
        );

        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => 'Hello!');
        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(session);
        when(() => mockWorkflow.getCurrentProposal(sessionId: 'session-1'))
            .thenReturn(null);
        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});
        when(
          () => mockWorkflow.sendMessage(
            sessionId: 'session-1',
            userMessage: 'Show me metrics',
          ),
        ).thenAnswer((_) async {
          // Simulate the workflow creating a surface during the response.
          bridge.handleToolCall({
            'surfaceId': 'surf-response-1',
            'rootType': 'MetricsSummary',
            'data': {
              'totalWakes': 5,
              'successRate': 1.0,
              'failureCount': 0,
            },
          });
          return 'Here are your metrics.';
        });
        when(() => mockWorkflow.getSession('session-1')).thenReturn(session);

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
              .sendMessage('Show me metrics'),
        );

        final data =
            container.read(evolutionChatStateProvider(kTestTemplateId)).value!;

        // system + assistant(opening) + user + assistant(response) + surface
        expect(data.messages.length, 5);
        expect(data.messages[4], isA<EvolutionSurfaceMessage>());
        expect(
          (data.messages[4] as EvolutionSurfaceMessage).surfaceId,
          'surf-response-1',
        );
      });
    });

    group('GenUI proposal actions', () {
      test('proposal_rejected callback routes through rejectProposal',
          () async {
        final processor = A2uiMessageProcessor(
          catalogs: [buildEvolutionCatalog()],
        );
        final bridge = GenUiBridge(processor: processor);
        final eventHandler = GenUiEventHandler(processor: processor)..listen();

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
            strategy: EvolutionStrategy(genUiBridge: bridge),
            modelId: 'model-1',
            processor: processor,
            genUiBridge: bridge,
            eventHandler: eventHandler,
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

        eventHandler.onProposalAction?.call('surface-1', 'proposal_rejected');

        final data =
            container.read(evolutionChatStateProvider(kTestTemplateId)).value!;
        expect(
          data.messages
              .whereType<EvolutionSystemMessage>()
              .any((m) => m.text == 'proposal_rejected'),
          isTrue,
        );
        verify(() => mockWorkflow.rejectProposal(sessionId: 'session-1'))
            .called(1);
      });

      test('proposal_approved callback routes through approveProposal',
          () async {
        final processor = A2uiMessageProcessor(
          catalogs: [buildEvolutionCatalog()],
        );
        final bridge = GenUiBridge(processor: processor);
        final eventHandler = GenUiEventHandler(processor: processor)..listen();

        const testProposal = PendingProposal(
          directives: 'new directives',
          rationale: 'better performance',
        );
        final approvedVersion = makeTestTemplateVersion(version: 2);

        when(() => mockWorkflow.startSession(templateId: kTestTemplateId))
            .thenAnswer((_) async => 'Here is my proposal.');
        when(() => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId))
            .thenReturn(
          ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestTemplateId,
            conversationId: 'conv-1',
            strategy: EvolutionStrategy(genUiBridge: bridge),
            modelId: 'model-1',
            processor: processor,
            genUiBridge: bridge,
            eventHandler: eventHandler,
          ),
        );
        when(() => mockWorkflow.getCurrentProposal(sessionId: 'session-1'))
            .thenReturn(testProposal);
        when(
          () => mockWorkflow.approveProposal(
            sessionId: 'session-1',
          ),
        ).thenAnswer((_) async => approvedVersion);
        when(() => mockWorkflow.abandonSession(sessionId: 'session-1'))
            .thenAnswer((_) async {});

        container = createContainer();
        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).future),
        );

        eventHandler.onProposalAction?.call('surface-1', 'proposal_approved');
        await Future<void>.value();

        final data =
            container.read(evolutionChatStateProvider(kTestTemplateId)).value!;
        expect(
          data.messages
              .whereType<EvolutionSystemMessage>()
              .any((m) => m.text == 'session_completed:2'),
          isTrue,
        );
        verify(
          () => mockWorkflow.approveProposal(
            sessionId: 'session-1',
          ),
        ).called(1);
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

    test('copyWith sets currentDirectives to null via function', () {
      const data = EvolutionChatData(
        messages: [],
        currentDirectives: 'some directives',
      );

      final updated = data.copyWith(currentDirectives: () => null);
      expect(updated.currentDirectives, isNull);
    });
  });
}
