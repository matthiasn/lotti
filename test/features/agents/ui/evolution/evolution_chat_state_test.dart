import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:glados/glados.dart' as glados;
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

  ActiveEvolutionSession makeSession({String sessionId = 'session-1'}) =>
      ActiveEvolutionSession(
        sessionId: sessionId,
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model-1',
      );

  /// Stubs the canonical successful session start: startSession returns
  /// [response], the active session resolves, no current proposal, and
  /// abandonSession is a no-op. Re-stub individual calls after this for
  /// test-specific behavior (mocktail last-wins).
  void stubSuccessfulStart({
    String response = 'Hello!',
    ActiveEvolutionSession? session,
  }) {
    final activeSession = session ?? makeSession();
    when(
      () => mockWorkflow.startSession(templateId: kTestTemplateId),
    ).thenAnswer((_) async => response);
    when(
      () => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId),
    ).thenReturn(activeSession);
    when(
      () => mockWorkflow.getCurrentProposal(
        sessionId: activeSession.sessionId,
      ),
    ).thenReturn(null);
    when(
      () => mockWorkflow.abandonSession(sessionId: activeSession.sessionId),
    ).thenAnswer((_) async {});
  }

  /// Stubs the failed session start: startSession resolves null and no
  /// active session exists.
  void stubNullStart() {
    when(
      () => mockWorkflow.startSession(templateId: kTestTemplateId),
    ).thenAnswer((_) async => null);
    when(
      () => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId),
    ).thenReturn(null);
  }

  group('EvolutionChatState', () {
    group('build', () {
      test('starts session and returns data with opening message', () async {
        stubSuccessfulStart(response: 'Welcome to the evolution session!');
        container = createContainer();
        final data = await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
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
      });

      test('returns error state when startSession returns null', () async {
        stubNullStart();

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        expect(data.sessionId, isNull);
        expect(data.messages.length, 2);
        expect(data.messages[1], isA<EvolutionSystemMessage>());
        expect(
          (data.messages[1] as EvolutionSystemMessage).text,
          'session_error',
        );
      });

      test(
        'abandons session when startSession returns null but session exists',
        () async {
          when(
            () => mockWorkflow.startSession(templateId: kTestTemplateId),
          ).thenAnswer((_) async => null);

          when(
            () => mockWorkflow.getActiveSessionForTemplate(kTestTemplateId),
          ).thenReturn(
            makeSession(),
          );
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});

          container = createContainer();
          final data = await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          expect(data.sessionId, isNull);
          expect(data.messages.last, isA<EvolutionSystemMessage>());
          expect(
            (data.messages.last as EvolutionSystemMessage).text,
            'session_error',
          );
          // Verify the session was abandoned so it doesn't block future starts.
          verify(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).called(1);
        },
      );

      test(
        'does not add proposal message (proposals handled via GenUI)',
        () async {
          stubSuccessfulStart(response: 'Here is my proposal.');
          container = createContainer();
          final data = await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          // Only system + assistant messages, no proposal message variant.
          expect(data.messages.length, 2);
          expect(data.messages[0], isA<EvolutionSystemMessage>());
          expect(data.messages[1], isA<EvolutionAssistantMessage>());
        },
      );

      test(
        'suppresses opening assistant bubble when a proposal surface is rendered',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor)
            ..handleToolCall({
              'surfaceId': 'surf-opening-proposal',
              'rootType': 'EvolutionProposal',
              'data': {
                'generalDirective': 'new general',
                'reportDirective': 'new report',
                'rationale': 'Because this is better.',
                'currentGeneralDirective': 'old general',
                'currentReportDirective': 'old report',
              },
            });

          stubSuccessfulStart(
            response: 'Here is my proposal rationale.',
            session: ActiveEvolutionSession(
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
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenReturn(
            const PendingProposal(
              generalDirective: 'new general',
              reportDirective: 'new report',
              rationale: 'Because this is better.',
            ),
          );

          container = createContainer();
          final data = await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          expect(data.messages.length, 2);
          expect(data.messages[0], isA<EvolutionSystemMessage>());
          expect(data.messages[1], isA<EvolutionSurfaceMessage>());
        },
      );

      test(
        'abandons the active session on dispose, swallowing failures',
        () async {
          stubSuccessfulStart(response: 'Welcome!');
          // Fail the abandon on dispose to exercise the catchError log branch.
          // Return a failing Future (not a sync throw) so the production
          // `.catchError` handler is the one that catches it.
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) => Future<void>.error(Exception('abandon failed')));

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          // Disposing the provider runs ref.onDispose, which abandons the
          // still-active session. The failing future must be swallowed
          // (logged via catchError) without surfacing an error.
          container.invalidate(evolutionChatStateProvider(kTestTemplateId));
          await Future<void>.value();

          verify(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).called(1);
        },
      );
    });

    group('sendMessage', () {
      test('adds user message and assistant response', () async {
        stubSuccessfulStart();
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
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .sendMessage('Improve error handling'),
        );

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;

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

      test(
        'suppresses assistant response when the same turn renders a proposal surface',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          var rebuildProposalLookupCount = 0;
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

          stubSuccessfulStart(
            session: session,
          );
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenAnswer((_) {
            rebuildProposalLookupCount += 1;
            return rebuildProposalLookupCount <= 2
                ? null
                : const PendingProposal(
                    generalDirective: 'new directives',
                    reportDirective: '',
                    rationale: 'Better fit for the user.',
                  );
          });
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'continue',
            ),
          ).thenAnswer((_) async {
            bridge.handleToolCall({
              'surfaceId': 'surf-proposal-1',
              'rootType': 'EvolutionProposal',
              'data': {
                'generalDirective': 'new directives',
                'reportDirective': '',
                'rationale': 'Better fit for the user.',
                'currentGeneralDirective': 'old directives',
                'currentReportDirective': '',
              },
            });
            return 'Better fit for the user.';
          });
          when(() => mockWorkflow.getSession('session-1')).thenReturn(session);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(evolutionChatStateProvider(kTestTemplateId).notifier)
                .sendMessage('continue'),
          );

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;

          expect(data.messages.length, 4);
          expect(data.messages[2], isA<EvolutionUserMessage>());
          expect(
            (data.messages[2] as EvolutionUserMessage).text,
            'continue',
          );
          expect(data.messages[3], isA<EvolutionSurfaceMessage>());
        },
      );

      test(
        'treats ok as implicit approval when a proposal is pending',
        () async {
          final approvedVersion = makeTestTemplateVersion(version: 2);
          const recap = PendingRitualRecap(
            tldr:
                'We tightened the report rules and removed the broken list markup.',
            content: '## Recap\n\nWe tightened the report rules.',
          );

          stubSuccessfulStart(response: 'Please review this proposal.');
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenReturn(
            const PendingProposal(
              generalDirective: 'new directives',
              reportDirective: '',
              rationale: 'Better fit for the user.',
            ),
          );
          when(
            () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
          ).thenReturn(recap);
          when(
            () => mockWorkflow.approveProposal(
              sessionId: 'session-1',
            ),
          ).thenAnswer((_) async => approvedVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(evolutionChatStateProvider(kTestTemplateId).notifier)
                .sendMessage('ok'),
          );

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;

          expect(data.messages.length, 5);
          expect(data.messages[2], isA<EvolutionUserMessage>());
          expect((data.messages[2] as EvolutionUserMessage).text, 'ok');
          expect(data.messages[3], isA<EvolutionAssistantMessage>());
          expect(
            (data.messages[3] as EvolutionAssistantMessage).text,
            recap.tldr,
          );
          expect(data.messages[4], isA<EvolutionSystemMessage>());
          expect(
            (data.messages[4] as EvolutionSystemMessage).text,
            'session_completed:2',
          );

          verifyNever(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: any(named: 'userMessage'),
            ),
          );
          verify(
            () => mockWorkflow.approveProposal(
              sessionId: 'session-1',
            ),
          ).called(1);
        },
      );

      test(
        'falls back to recap content when the recap tldr is blank',
        () async {
          final approvedVersion = makeTestTemplateVersion(version: 2);
          // Whitespace-only tldr forces the fallback to recap content.
          const recap = PendingRitualRecap(
            tldr: '   ',
            content: '## Recap\n\nFalling back to the full recap content.',
          );

          stubSuccessfulStart(response: 'Please review this proposal.');
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenReturn(
            const PendingProposal(
              generalDirective: 'new directives',
              reportDirective: '',
              rationale: 'Better fit for the user.',
            ),
          );
          when(
            () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
          ).thenReturn(recap);
          when(
            () => mockWorkflow.approveProposal(
              sessionId: 'session-1',
            ),
          ).thenAnswer((_) async => approvedVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(evolutionChatStateProvider(kTestTemplateId).notifier)
                .approveProposal(),
          );

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;

          // The assistant bubble uses the trimmed recap content, not the
          // blank tldr.
          final assistantMessages = data.messages
              .whereType<EvolutionAssistantMessage>()
              .toList();
          expect(
            assistantMessages.any((m) => m.text == recap.content.trim()),
            isTrue,
          );
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'session_completed:2',
            ),
            isTrue,
          );
        },
      );

      test(
        'skipApprovalCheck bypasses implicit approval even when proposal is pending',
        () async {
          stubSuccessfulStart(response: 'Please review this proposal.');
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenReturn(
            const PendingProposal(
              generalDirective: 'new directives',
              reportDirective: '',
              rationale: 'Better fit for the user.',
            ),
          );
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(() => mockWorkflow.getSession(any())).thenReturn(null);
          when(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'yes',
            ),
          ).thenAnswer((_) async => 'Got it, continuing.');

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(evolutionChatStateProvider(kTestTemplateId).notifier)
                .sendMessage('yes', skipApprovalCheck: true),
          );

          // approveProposal should NOT have been called.
          verifyNever(
            () => mockWorkflow.approveProposal(
              sessionId: any(named: 'sessionId'),
            ),
          );

          // The message should have gone through workflow.sendMessage instead.
          verify(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'yes',
            ),
          ).called(1);

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;

          // system + assistant (opening) + user + assistant (response)
          expect(data.messages.length, 4);
          expect(data.messages[2], isA<EvolutionUserMessage>());
          expect((data.messages[2] as EvolutionUserMessage).text, 'yes');
          expect(data.messages[3], isA<EvolutionAssistantMessage>());
          expect(
            (data.messages[3] as EvolutionAssistantMessage).text,
            'Got it, continuing.',
          );
        },
      );

      test(
        'adds approval_failed system message when implicit approval fails',
        () async {
          stubSuccessfulStart(response: 'Please review this proposal.');
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenReturn(
            const PendingProposal(
              generalDirective: 'new directives',
              reportDirective: '',
              rationale: 'Better fit for the user.',
            ),
          );
          when(
            () => mockWorkflow.approveProposal(
              sessionId: 'session-1',
            ),
          ).thenAnswer((_) async => null);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(evolutionChatStateProvider(kTestTemplateId).notifier)
                .sendMessage('ok'),
          );

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;

          // The last message should be a system message with approval_failed.
          expect(data.messages.last, isA<EvolutionSystemMessage>());
          expect(
            (data.messages.last as EvolutionSystemMessage).text,
            'approval_failed',
          );

          // approveProposal was called but returned null (failure).
          verify(
            () => mockWorkflow.approveProposal(
              sessionId: 'session-1',
            ),
          ).called(1);

          // sendMessage should NOT have been called (approval path, not chat).
          verifyNever(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: any(named: 'userMessage'),
            ),
          );
        },
      );
    });

    group('rejectProposal', () {
      test('adds rejection system message', () async {
        stubSuccessfulStart(response: 'Here is a proposal.');
        when(
          () => mockWorkflow.rejectProposal(sessionId: 'session-1'),
        ).thenReturn(null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        withClock(testClock, () {
          container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .rejectProposal();
        });

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;

        // Should have a rejection system message
        final systemMessages = data.messages
            .whereType<EvolutionSystemMessage>()
            .toList();
        expect(
          systemMessages.any((m) => m.text == 'proposal_rejected'),
          isTrue,
        );

        // lastSurfacedProposalKey should be cleared to null after rejection.
        expect(data.lastSurfacedProposalKey, isNull);
      });
    });

    group('GenUI surface drain', () {
      test('drains surface IDs from opening turn into messages', () async {
        final processor = SurfaceController(
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

        stubSuccessfulStart(
          response: 'Here are your metrics.',
          session: ActiveEvolutionSession(
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

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
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
        final processor = SurfaceController(
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

        stubSuccessfulStart(
          session: session,
        );
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
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .sendMessage('Show me metrics'),
        );

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;

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
      test(
        'proposal_rejected callback routes through rejectProposal',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          final eventHandler = GenUiEventHandler(processor: processor)
            ..listen();

          const testProposal = PendingProposal(
            generalDirective: 'new directives',
            reportDirective: '',
            rationale: 'better performance',
          );

          stubSuccessfulStart(
            response: 'Here is my proposal.',
            session: ActiveEvolutionSession(
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
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenReturn(testProposal);
          when(
            () => mockWorkflow.rejectProposal(sessionId: 'session-1'),
          ).thenReturn(null);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          eventHandler.onProposalAction?.call('surface-1', 'proposal_rejected');

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'proposal_rejected',
            ),
            isTrue,
          );
          verify(
            () => mockWorkflow.rejectProposal(sessionId: 'session-1'),
          ).called(1);
        },
      );

      test(
        'proposal_approved callback routes through approveProposal',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          final eventHandler = GenUiEventHandler(processor: processor)
            ..listen();

          const testProposal = PendingProposal(
            generalDirective: 'new directives',
            reportDirective: '',
            rationale: 'better performance',
          );
          final approvedVersion = makeTestTemplateVersion(version: 2);
          const recap = PendingRitualRecap(
            tldr: 'Short end-of-session recap.',
            content: '## Recap\n\nShort end-of-session recap.',
          );

          stubSuccessfulStart(
            response: 'Here is my proposal.',
            session: ActiveEvolutionSession(
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
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenReturn(testProposal);
          when(
            () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
          ).thenReturn(recap);
          when(
            () => mockWorkflow.approveProposal(
              sessionId: 'session-1',
            ),
          ).thenAnswer((_) async => approvedVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          eventHandler.onProposalAction?.call('surface-1', 'proposal_approved');
          await Future<void>.value();

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;
          expect(
            data.messages.whereType<EvolutionAssistantMessage>().any(
              (m) => m.text == recap.tldr,
            ),
            isTrue,
          );
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'session_completed:2',
            ),
            isTrue,
          );
          verify(
            () => mockWorkflow.approveProposal(
              sessionId: 'session-1',
            ),
          ).called(1);
        },
      );
    });

    group('GenUI soul proposal actions', () {
      test(
        'soul_proposal_approved callback routes through approveSoulProposal',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          final eventHandler = GenUiEventHandler(processor: processor)
            ..listen();
          final soulVersion = makeTestSoulDocumentVersion(version: 4);

          stubSuccessfulStart(
            response: 'Review the soul proposal.',
            session: ActiveEvolutionSession(
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
          when(
            () => mockWorkflow.approveSoulProposal(sessionId: 'session-1'),
          ).thenAnswer((_) async => soulVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          await withClock(testClock, () async {
            eventHandler.onSoulProposalAction?.call(
              'surface-1',
              'soul_proposal_approved',
            );
            await Future<void>.value();
          });

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'soul_version_created:v4',
            ),
            isTrue,
          );
          verify(
            () => mockWorkflow.approveSoulProposal(sessionId: 'session-1'),
          ).called(1);
        },
      );

      test(
        'soul_proposal_rejected callback routes through rejectSoulProposal',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          final eventHandler = GenUiEventHandler(processor: processor)
            ..listen();

          stubSuccessfulStart(
            response: 'Review the soul proposal.',
            session: ActiveEvolutionSession(
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
          when(
            () => mockWorkflow.rejectSoulProposal(sessionId: 'session-1'),
          ).thenReturn(null);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          withClock(testClock, () {
            eventHandler.onSoulProposalAction?.call(
              'surface-1',
              'soul_proposal_rejected',
            );
          });

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'soul_proposal_rejected',
            ),
            isTrue,
          );
          verify(
            () => mockWorkflow.rejectSoulProposal(sessionId: 'session-1'),
          ).called(1);
        },
      );

      test(
        'unknown soul proposal action is ignored',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          final eventHandler = GenUiEventHandler(processor: processor)
            ..listen();

          stubSuccessfulStart(
            response: 'Review the soul proposal.',
            session: ActiveEvolutionSession(
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
          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          withClock(testClock, () {
            eventHandler.onSoulProposalAction?.call('surface-1', 'noop_action');
          });

          // Neither approve nor reject should have been triggered.
          verifyNever(
            () => mockWorkflow.approveSoulProposal(
              sessionId: any(named: 'sessionId'),
            ),
          );
          verifyNever(
            () => mockWorkflow.rejectSoulProposal(
              sessionId: any(named: 'sessionId'),
            ),
          );
        },
      );
    });

    group('GenUI ratings actions', () {
      test(
        'ratings_submitted callback formats ratings and sends message',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          final eventHandler = GenUiEventHandler(processor: processor)
            ..listen();

          stubSuccessfulStart(
            response: 'Let us rate categories.',
            session: ActiveEvolutionSession(
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
          when(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'My category ratings: accuracy: 4/5, tooling: 2/5',
            ),
          ).thenAnswer((_) async => 'Thanks, I will draft a proposal.');
          when(() => mockWorkflow.getSession('session-1')).thenReturn(null);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          eventHandler.onRatingsSubmitted?.call('surface-1', {
            'accuracy': 4,
            'tooling': 2,
          });

          await Future<void>.value();

          verify(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'My category ratings: accuracy: 4/5, tooling: 2/5',
            ),
          ).called(1);
        },
      );

      test(
        'binary choice callback forwards semantic value as user message',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          final eventHandler = GenUiEventHandler(processor: processor)
            ..listen();

          stubSuccessfulStart(
            response: 'Want to rate me?',
            session: ActiveEvolutionSession(
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
          when(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'Yes, show the rating form.',
            ),
          ).thenAnswer((_) async => 'Rendering ratings.');
          when(() => mockWorkflow.getSession('session-1')).thenReturn(null);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          eventHandler.onBinaryChoiceSubmitted?.call(
            'surface-1',
            'Yes, show the rating form.',
          );

          await Future<void>.value();

          verify(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'Yes, show the rating form.',
            ),
          ).called(1);
        },
      );
    });

    group('sendMessage - edge cases', () {
      test('does nothing when isWaiting is already true', () async {
        stubSuccessfulStart();
        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        // Manually set waiting state.
        final notifier = container.read(
          evolutionChatStateProvider(kTestTemplateId).notifier,
        );
        final current = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;
        notifier.state = AsyncData(current.copyWith(isWaiting: true));

        // sendMessage should be a no-op.
        await withClock(testClock, () => notifier.sendMessage('test'));

        verifyNever(
          () => mockWorkflow.sendMessage(
            sessionId: any(named: 'sessionId'),
            userMessage: any(named: 'userMessage'),
          ),
        );
      });

      test('handles null response from workflow', () async {
        stubSuccessfulStart();
        when(() => mockWorkflow.getSession(any())).thenReturn(null);
        when(
          () => mockWorkflow.sendMessage(
            sessionId: 'session-1',
            userMessage: 'test',
          ),
        ).thenAnswer((_) async => null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .sendMessage('test'),
        );

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;

        // system + assistant(opening) + user (no assistant response)
        expect(data.messages.length, 3);
        expect(data.messages[2], isA<EvolutionUserMessage>());
        expect(data.isWaiting, isFalse);
      });

      test('catches errors and clears waiting state', () async {
        stubSuccessfulStart();
        when(
          () => mockWorkflow.sendMessage(
            sessionId: 'session-1',
            userMessage: 'boom',
          ),
        ).thenThrow(Exception('network error'));

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .sendMessage('boom'),
        );

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;
        expect(data.isWaiting, isFalse);
      });

      test('does not append an empty assistant bubble', () async {
        stubSuccessfulStart();
        when(
          () => mockWorkflow.sendMessage(
            sessionId: 'session-1',
            userMessage: 'continue',
          ),
        ).thenAnswer((_) async => '   ');
        when(() => mockWorkflow.getSession('session-1')).thenReturn(null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .sendMessage('continue'),
        );

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;
        expect(data.messages.length, 3);
        expect(data.messages.last, isA<EvolutionUserMessage>());
      });

      test(
        'rebuilds the proposal surface when a proposal exists but no surface was drained',
        () async {
          final processor = SurfaceController(
            catalogs: [buildEvolutionCatalog()],
          );
          final bridge = GenUiBridge(processor: processor);
          var rebuildProposalLookupCount = 0;
          final session = ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestTemplateId,
            conversationId: 'conv-1',
            strategy: EvolutionStrategy(
              genUiBridge: bridge,
              currentGeneralDirective: 'old general',
              currentReportDirective: 'old report',
            ),
            modelId: 'model-1',
            processor: processor,
            genUiBridge: bridge,
            eventHandler: GenUiEventHandler(processor: processor)..listen(),
          );

          stubSuccessfulStart(
            session: session,
          );
          when(
            () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
          ).thenAnswer((_) {
            rebuildProposalLookupCount += 1;
            return rebuildProposalLookupCount <= 2
                ? null
                : const PendingProposal(
                    generalDirective: 'new general',
                    reportDirective: 'new report',
                    rationale: 'Sharper fix.',
                  );
          });
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'now what?',
            ),
          ).thenAnswer((_) async => 'V7 is ready for approval.');
          when(() => mockWorkflow.getSession('session-1')).thenReturn(session);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              evolutionChatStateProvider(kTestTemplateId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(evolutionChatStateProvider(kTestTemplateId).notifier)
                .sendMessage('now what?'),
          );

          final data = container
              .read(evolutionChatStateProvider(kTestTemplateId))
              .value!;
          expect(data.messages.last, isA<EvolutionSurfaceMessage>());
        },
      );
    });

    group('approveProposal - edge cases', () {
      test('returns false when no pending proposal', () async {
        stubSuccessfulStart();
        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .approveProposal(),
        );

        expect(result, isFalse);
      });

      test('returns false when approveProposal returns null version', () async {
        stubSuccessfulStart(response: 'Proposal.');
        when(
          () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
        ).thenReturn(
          const PendingProposal(
            generalDirective: 'new',
            reportDirective: '',
            rationale: 'better',
          ),
        );
        when(
          () => mockWorkflow.approveProposal(sessionId: 'session-1'),
        ).thenAnswer((_) async => null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .approveProposal(),
        );

        expect(result, isFalse);
        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;
        expect(data.isWaiting, isFalse);
      });

      test('catches errors and returns false', () async {
        stubSuccessfulStart(response: 'Proposal.');
        when(
          () => mockWorkflow.getCurrentProposal(sessionId: 'session-1'),
        ).thenReturn(
          const PendingProposal(
            generalDirective: 'new',
            reportDirective: '',
            rationale: 'better',
          ),
        );
        when(
          () => mockWorkflow.approveProposal(sessionId: 'session-1'),
        ).thenThrow(Exception('approve failed'));

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .approveProposal(),
        );

        expect(result, isFalse);
        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;
        expect(data.isWaiting, isFalse);
      });

      test('returns false when sessionId is null', () async {
        stubNullStart();

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .approveProposal(),
        );

        expect(result, isFalse);
      });
    });

    group('endSession', () {
      test('abandons session and adds system message', () async {
        stubSuccessfulStart();
        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .endSession(),
        );

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;

        expect(data.sessionId, isNull);
        expect(data.processor, isNull);
        expect(data.isWaiting, isFalse);
        expect(
          data.messages.whereType<EvolutionSystemMessage>().any(
            (m) => m.text == 'session_abandoned',
          ),
          isTrue,
        );
        verify(
          () => mockWorkflow.abandonSession(sessionId: 'session-1'),
        ).called(greaterThanOrEqualTo(1));
      });

      test('does nothing when sessionId is null', () async {
        stubNullStart();

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .endSession(),
        );

        // No additional messages beyond the error state messages.
        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;
        expect(
          data.messages
              .whereType<EvolutionSystemMessage>()
              .where((m) => m.text == 'session_abandoned')
              .isEmpty,
          isTrue,
        );
      });
    });

    group('rejectProposal - edge cases', () {
      test('does nothing when sessionId is null', () async {
        stubNullStart();

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            evolutionChatStateProvider(kTestTemplateId).future,
          ),
        );

        withClock(testClock, () {
          container
              .read(evolutionChatStateProvider(kTestTemplateId).notifier)
              .rejectProposal();
        });

        final data = container
            .read(evolutionChatStateProvider(kTestTemplateId))
            .value!;
        expect(
          data.messages
              .whereType<EvolutionSystemMessage>()
              .where((m) => m.text == 'proposal_rejected')
              .isEmpty,
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
      );

      final updated = data.copyWith(isWaiting: true);

      expect(updated.sessionId, 'session-1');
      expect(updated.messages, isEmpty);
      expect(updated.isWaiting, isTrue);
    });
  });

  group('approveSoulProposal', () {
    test('adds success system message when soul version is created', () async {
      final soulVersion = makeTestSoulDocumentVersion(version: 3);

      stubSuccessfulStart(response: 'Review the soul proposal.');
      when(
        () => mockWorkflow.approveSoulProposal(sessionId: 'session-1'),
      ).thenAnswer((_) async => soulVersion);

      container = createContainer();
      await withClock(
        testClock,
        () => container.read(
          evolutionChatStateProvider(kTestTemplateId).future,
        ),
      );

      await withClock(
        testClock,
        () => container
            .read(evolutionChatStateProvider(kTestTemplateId).notifier)
            .approveSoulProposal(),
      );

      final data = container
          .read(evolutionChatStateProvider(kTestTemplateId))
          .value!;

      final systemMessages = data.messages
          .whereType<EvolutionSystemMessage>()
          .toList();
      expect(
        systemMessages.any((m) => m.text == 'soul_version_created:v3'),
        isTrue,
      );

      verify(
        () => mockWorkflow.approveSoulProposal(sessionId: 'session-1'),
      ).called(1);
    });

    test('adds failure system message when approve returns null', () async {
      stubSuccessfulStart(response: 'Review the soul proposal.');
      when(
        () => mockWorkflow.approveSoulProposal(sessionId: 'session-1'),
      ).thenAnswer((_) async => null);

      container = createContainer();
      await withClock(
        testClock,
        () => container.read(
          evolutionChatStateProvider(kTestTemplateId).future,
        ),
      );

      await withClock(
        testClock,
        () => container
            .read(evolutionChatStateProvider(kTestTemplateId).notifier)
            .approveSoulProposal(),
      );

      final data = container
          .read(evolutionChatStateProvider(kTestTemplateId))
          .value!;

      final systemMessages = data.messages
          .whereType<EvolutionSystemMessage>()
          .toList();
      expect(
        systemMessages.any((m) => m.text == 'soul_proposal_failed'),
        isTrue,
      );
    });

    test('handles exception without crashing', () async {
      stubSuccessfulStart(response: 'Review the soul proposal.');
      when(
        () => mockWorkflow.approveSoulProposal(sessionId: 'session-1'),
      ).thenThrow(Exception('Soul service error'));

      container = createContainer();
      await withClock(
        testClock,
        () => container.read(
          evolutionChatStateProvider(kTestTemplateId).future,
        ),
      );

      // Should not throw.
      await withClock(
        testClock,
        () => container
            .read(evolutionChatStateProvider(kTestTemplateId).notifier)
            .approveSoulProposal(),
      );

      // State should still be valid — no crash.
      final data = container
          .read(evolutionChatStateProvider(kTestTemplateId))
          .value;
      expect(data, isNotNull);
    });

    test('no-op when session data is null', () async {
      stubNullStart();

      container = createContainer();
      await withClock(
        testClock,
        () => container.read(
          evolutionChatStateProvider(kTestTemplateId).future,
        ),
      );

      // approveSoulProposal should be a no-op when sessionId is null.
      await withClock(
        testClock,
        () => container
            .read(evolutionChatStateProvider(kTestTemplateId).notifier)
            .approveSoulProposal(),
      );

      verifyNever(
        () => mockWorkflow.approveSoulProposal(
          sessionId: any(named: 'sessionId'),
        ),
      );
    });
  });

  group('rejectSoulProposal', () {
    test('adds rejection system message', () async {
      stubSuccessfulStart(response: 'Review the soul proposal.');
      when(
        () => mockWorkflow.rejectSoulProposal(sessionId: 'session-1'),
      ).thenReturn(null);

      container = createContainer();
      await withClock(
        testClock,
        () => container.read(
          evolutionChatStateProvider(kTestTemplateId).future,
        ),
      );

      withClock(testClock, () {
        container
            .read(evolutionChatStateProvider(kTestTemplateId).notifier)
            .rejectSoulProposal();
      });

      final data = container
          .read(evolutionChatStateProvider(kTestTemplateId))
          .value!;

      final systemMessages = data.messages
          .whereType<EvolutionSystemMessage>()
          .toList();
      expect(
        systemMessages.any((m) => m.text == 'soul_proposal_rejected'),
        isTrue,
      );

      verify(
        () => mockWorkflow.rejectSoulProposal(sessionId: 'session-1'),
      ).called(1);
    });

    test('no-op when session data is null', () async {
      stubNullStart();

      container = createContainer();
      await withClock(
        testClock,
        () => container.read(
          evolutionChatStateProvider(kTestTemplateId).future,
        ),
      );

      withClock(testClock, () {
        container
            .read(evolutionChatStateProvider(kTestTemplateId).notifier)
            .rejectSoulProposal();
      });

      verifyNever(
        () => mockWorkflow.rejectSoulProposal(
          sessionId: any(named: 'sessionId'),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Glados properties for the pure helpers (via the debug seams).
  // ---------------------------------------------------------------------------
  group('debugIsImplicitApprovalMessage — properties', () {
    const approvalKeywords = [
      'ok',
      'okay',
      'yes',
      'yep',
      'approve',
      'approved',
      'lgtm',
      'sounds good',
      'looks good',
      'ship it',
    ];
    const decorations = ['', '  ', '!', '!!', '...', '(', ')', ' 👍', '\t'];

    glados.Glados3(
      glados.AnyUtils(glados.any).choose(approvalKeywords),
      glados.AnyUtils(glados.any).choose(decorations),
      glados.AnyUtils(glados.any).choose(decorations),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every keyword matches regardless of surrounding punctuation/whitespace',
      (keyword, prefix, suffix) {
        expect(
          EvolutionChatState.debugIsImplicitApprovalMessage(
            '$prefix$keyword$suffix',
          ),
          isTrue,
          reason: '"$prefix$keyword$suffix"',
        );
        // Case-insensitivity comes with the keyword match.
        expect(
          EvolutionChatState.debugIsImplicitApprovalMessage(
            '$prefix${keyword.toUpperCase()}$suffix',
          ),
          isTrue,
          reason: 'uppercased "$prefix$keyword$suffix"',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.AnyUtils(glados.any).choose(approvalKeywords),
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'a keyword embedded in a longer sentence never matches — the regex '
      'is anchored',
      (keyword) {
        expect(
          EvolutionChatState.debugIsImplicitApprovalMessage(
            'this is not $keyword behavior',
          ),
          isFalse,
          reason: keyword,
        );
        expect(
          EvolutionChatState.debugIsImplicitApprovalMessage(
            '$keyword but please tweak the tone first',
          ),
          isFalse,
          reason: keyword,
        );
      },
      tags: 'glados',
    );
  });

  group('debugProposalKey — properties', () {
    glados.Glados3(
      glados.AnyUtils(glados.any).choose(const ['', '  d1  ', 'directive']),
      glados.AnyUtils(glados.any).choose(const ['', ' r ', 'report\nline2']),
      glados.AnyUtils(glados.any).choose(const ['', '  why  ', 'rationale!']),
      glados.ExploreConfig(numRuns: 80),
    ).test('fingerprint is trim-stable and separator-structured', (
      general,
      report,
      rationale,
    ) {
      final proposal = PendingProposal(
        generalDirective: general,
        reportDirective: report,
        rationale: rationale,
      );
      final key = EvolutionChatState.debugProposalKey(proposal);

      // Trim-stability: padding any field never changes the fingerprint.
      final padded = PendingProposal(
        generalDirective: '  $general\t',
        reportDirective: '\n$report ',
        rationale: ' $rationale  ',
      );
      expect(EvolutionChatState.debugProposalKey(padded), key);

      // Structure: exactly two separators join the three trimmed fields.
      expect('\n---\n'.allMatches(key).length, 2, reason: key);
      expect(
        key.split('\n---\n'),
        [general.trim(), report.trim(), rationale.trim()],
      );
    }, tags: 'glados');
  });
}
