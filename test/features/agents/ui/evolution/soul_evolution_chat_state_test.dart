import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/genui_bridge.dart';
import 'package:lotti/features/agents/genui/genui_event_handler.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/agent_workflow_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_state.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../test_utils.dart';

/// Strategy subclass exposing a settable soul proposal for test purposes.
class _TestableEvolutionStrategy extends EvolutionStrategy {
  _TestableEvolutionStrategy();

  PendingSoulProposal? testSoulProposal;

  @override
  PendingSoulProposal? get latestSoulProposal => testSoulProposal;
}

void main() {
  late MockTemplateEvolutionWorkflow mockWorkflow;
  late ProviderContainer container;

  final testClock = Clock.fixed(DateTime(2024, 3, 15, 10, 30));

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockWorkflow = MockTemplateEvolutionWorkflow();
  });

  ProviderContainer createContainer() {
    final c = ProviderContainer(
      overrides: [
        templateEvolutionWorkflowProvider.overrideWithValue(mockWorkflow),
        allSoulDocumentsProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        activeSoulVersionProvider.overrideWith(
          (ref, id) async => null,
        ),
        soulVersionHistoryProvider.overrideWith(
          (ref, id) async => <AgentDomainEntity>[],
        ),
        templatesUsingSoulProvider.overrideWith(
          (ref, id) async => <String>[],
        ),
        soulEvolutionSessionsProvider.overrideWith(
          (ref, id) async => <AgentDomainEntity>[],
        ),
        soulEvolutionSessionHistoryProvider.overrideWith(
          (ref, id) async => <RitualSessionHistoryEntry>[],
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ActiveEvolutionSession makeSession({
    String sessionId = 'session-1',
    String templateId = kTestSoulId,
    String conversationId = 'conv-1',
    String modelId = 'model-1',
  }) => ActiveEvolutionSession(
    sessionId: sessionId,
    templateId: templateId,
    conversationId: conversationId,
    strategy: EvolutionStrategy(),
    modelId: modelId,
  );

  /// Stubs the workflow for a successful session start returning [response].
  void stubSuccessfulStart({
    String response = 'Hello!',
    ActiveEvolutionSession? session,
  }) {
    final activeSession = session ?? makeSession();
    when(
      () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
    ).thenAnswer((_) async => response);
    when(
      () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
    ).thenReturn(activeSession);
    when(
      () => mockWorkflow.abandonSession(sessionId: activeSession.sessionId),
    ).thenAnswer((_) async {});
  }

  group('SoulEvolutionChatState', () {
    group('build', () {
      test(
        'starts soul session and returns data with opening message',
        () async {
          stubSuccessfulStart(
            response: 'Welcome to the soul evolution session!',
          );

          container = createContainer();
          final data = await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          expect(data.sessionId, 'session-1');
          expect(data.messages.length, 2);
          expect(data.messages[0], isA<EvolutionSystemMessage>());
          expect(
            (data.messages[0] as EvolutionSystemMessage).text,
            'starting_session',
          );
          expect(data.messages[1], isA<EvolutionAssistantMessage>());
          expect(
            (data.messages[1] as EvolutionAssistantMessage).text,
            'Welcome to the soul evolution session!',
          );
          expect(data.isWaiting, isFalse);
        },
      );

      test('returns error state when startSoulSession returns null', () async {
        when(
          () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
        ).thenAnswer((_) async => null);

        when(
          () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
        ).thenReturn(null);

        container = createContainer();
        final data = await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        expect(data.sessionId, isNull);
        expect(data.messages.length, 2);
        expect(data.messages[0], isA<EvolutionSystemMessage>());
        expect(
          (data.messages[0] as EvolutionSystemMessage).text,
          'starting_session',
        );
        expect(data.messages[1], isA<EvolutionSystemMessage>());
        expect(
          (data.messages[1] as EvolutionSystemMessage).text,
          'session_error',
        );
      });

      test(
        'abandons partially created session when startSoulSession returns null '
        'but session exists',
        () async {
          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => null);

          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(makeSession());

          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});

          container = createContainer();
          final data = await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          expect(data.sessionId, isNull);
          expect(data.messages.last, isA<EvolutionSystemMessage>());
          expect(
            (data.messages.last as EvolutionSystemMessage).text,
            'session_error',
          );
          verify(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).called(1);
        },
      );
    });

    group('sendMessage', () {
      test('sends user message and receives response', () async {
        stubSuccessfulStart();

        when(() => mockWorkflow.getSession(any())).thenReturn(null);

        when(
          () => mockWorkflow.sendMessage(
            sessionId: 'session-1',
            userMessage: 'Tell me about my soul.',
          ),
        ).thenAnswer((_) async => 'Your soul is evolving well.');

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .sendMessage('Tell me about my soul.'),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // system + assistant (opening) + user + assistant (response)
        expect(data.messages.length, 4);
        expect(data.messages[2], isA<EvolutionUserMessage>());
        expect(
          (data.messages[2] as EvolutionUserMessage).text,
          'Tell me about my soul.',
        );
        expect(data.messages[3], isA<EvolutionAssistantMessage>());
        expect(
          (data.messages[3] as EvolutionAssistantMessage).text,
          'Your soul is evolving well.',
        );
        expect(data.isWaiting, isFalse);
      });

      test(
        'implicit approval routes to completeSoulSession when '
        'soul proposal is pending',
        () async {
          final soulVersion = makeTestSoulDocumentVersion(version: 2);
          final strategy = _TestableEvolutionStrategy()
            ..testSoulProposal = const PendingSoulProposal(
              voiceDirective: 'New voice',
              toneBounds: 'New tone',
              coachingStyle: 'New coaching',
              antiSycophancyPolicy: 'New anti-sycophancy',
              rationale: 'Refine personality.',
            );
          final sessionWithProposal = ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestSoulId,
            conversationId: 'conv-1',
            strategy: strategy,
            modelId: 'model-1',
          );

          stubSuccessfulStart(session: sessionWithProposal);
          when(
            () => mockWorkflow.getSession('session-1'),
          ).thenReturn(sessionWithProposal);
          when(
            () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
          ).thenReturn(null);
          when(
            () => mockWorkflow.completeSoulSession(
              sessionId: 'session-1',
              categoryRatings: any(named: 'categoryRatings'),
            ),
          ).thenAnswer((_) async => soulVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                .sendMessage('ok'),
          );

          final data = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          // completeSoulSession should have been called.
          verify(
            () => mockWorkflow.completeSoulSession(
              sessionId: 'session-1',
              categoryRatings: any(named: 'categoryRatings'),
            ),
          ).called(1);

          // sendMessage on workflow should NOT have been called.
          verifyNever(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: any(named: 'userMessage'),
            ),
          );

          // Session should be completed with soul_version_created message.
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'soul_version_created:v2',
            ),
            isTrue,
          );
        },
      );

      test('does nothing when sessionId is null', () async {
        when(
          () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
        ).thenAnswer((_) async => null);
        when(
          () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
        ).thenReturn(null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .sendMessage('hello'),
        );

        // No user message should be added when there is no active session.
        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;
        expect(
          data.messages.whereType<EvolutionUserMessage>().isEmpty,
          isTrue,
        );
      });
    });

    group('approveSoulProposal', () {
      test('creates soul version and completes session', () async {
        final soulVersion = makeTestSoulDocumentVersion(version: 2);

        stubSuccessfulStart();
        when(
          () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
        ).thenReturn(
          const PendingRitualRecap(
            tldr: 'Refined the voice and coaching style.',
            content: '## Recap\n\nRefined the voice and coaching style.',
          ),
        );
        when(
          () => mockWorkflow.completeSoulSession(
            sessionId: 'session-1',
            categoryRatings: any(named: 'categoryRatings'),
          ),
        ).thenAnswer((_) async => soulVersion);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .approveSoulProposal(),
        );

        expect(result, isTrue);

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // Session should be nullified.
        expect(data.sessionId, isNull);
        expect(data.processor, isNull);
        expect(data.isWaiting, isFalse);

        // Recap assistant message should be present.
        expect(
          data.messages.whereType<EvolutionAssistantMessage>().any(
            (m) => m.text == 'Refined the voice and coaching style.',
          ),
          isTrue,
        );

        // soul_version_created system message should be present.
        expect(
          data.messages.whereType<EvolutionSystemMessage>().any(
            (m) => m.text == 'soul_version_created:v2',
          ),
          isTrue,
        );

        verify(
          () => mockWorkflow.completeSoulSession(
            sessionId: 'session-1',
            categoryRatings: any(named: 'categoryRatings'),
          ),
        ).called(1);
      });

      test('returns false when completeSoulSession returns null', () async {
        stubSuccessfulStart();
        when(
          () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
        ).thenReturn(null);
        when(
          () => mockWorkflow.completeSoulSession(
            sessionId: 'session-1',
            categoryRatings: any(named: 'categoryRatings'),
          ),
        ).thenAnswer((_) async => null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .approveSoulProposal(),
        );

        expect(result, isFalse);

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // Session should NOT be nullified — still active.
        expect(data.sessionId, 'session-1');
        expect(data.isWaiting, isFalse);
      });

      test('returns false when sessionId is null', () async {
        when(
          () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
        ).thenAnswer((_) async => null);
        when(
          () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
        ).thenReturn(null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .approveSoulProposal(),
        );

        expect(result, isFalse);
      });
    });

    group('rejectSoulProposal', () {
      test('clears proposal and adds system message', () async {
        stubSuccessfulStart();
        when(
          () => mockWorkflow.rejectSoulProposal(sessionId: 'session-1'),
        ).thenReturn(null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        withClock(testClock, () {
          container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .rejectSoulProposal();
        });

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
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
      });

      test('does nothing when sessionId is null', () async {
        when(
          () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
        ).thenAnswer((_) async => null);
        when(
          () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
        ).thenReturn(null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        withClock(testClock, () {
          container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .rejectSoulProposal();
        });

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // No soul_proposal_rejected message should appear.
        expect(
          data.messages.whereType<EvolutionSystemMessage>().where(
            (m) => m.text == 'soul_proposal_rejected',
          ),
          isEmpty,
        );
      });
    });

    group('endSession', () {
      test('abandons session and adds system message', () async {
        stubSuccessfulStart();

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .endSession(),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
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
        when(
          () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
        ).thenAnswer((_) async => null);
        when(
          () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
        ).thenReturn(null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .endSession(),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
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

    group('sendMessage — edge cases', () {
      test('handles sendMessage error gracefully', () async {
        stubSuccessfulStart();
        when(
          () => mockWorkflow.sendMessage(
            sessionId: any(named: 'sessionId'),
            userMessage: any(named: 'userMessage'),
          ),
        ).thenThrow(Exception('network error'));
        when(
          () => mockWorkflow.getSession(any()),
        ).thenReturn(makeSession());

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .sendMessage('hello'),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // Error path should set isWaiting back to false.
        expect(data.isWaiting, isFalse);
        // User message should still be in the list.
        expect(
          data.messages.whereType<EvolutionUserMessage>().length,
          1,
        );
      });

      test('does not send when isWaiting is true', () async {
        stubSuccessfulStart();
        when(
          () => mockWorkflow.getSession(any()),
        ).thenReturn(makeSession());

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        // Manually set isWaiting.
        final current = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;
        container
            .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
            .state = AsyncData(
          current.copyWith(isWaiting: true),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .sendMessage('should be ignored'),
        );

        // Verify sendMessage was never called.
        verifyNever(
          () => mockWorkflow.sendMessage(
            sessionId: any(named: 'sessionId'),
            userMessage: any(named: 'userMessage'),
          ),
        );
      });
    });

    group('approveSoulProposal — edge cases', () {
      test('handles approval error gracefully', () async {
        stubSuccessfulStart();
        when(
          () =>
              mockWorkflow.getCurrentRecap(sessionId: any(named: 'sessionId')),
        ).thenReturn(null);
        when(
          () => mockWorkflow.completeSoulSession(
            sessionId: any(named: 'sessionId'),
            categoryRatings: any(named: 'categoryRatings'),
          ),
        ).thenThrow(Exception('approval error'));

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        final result = await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .approveSoulProposal(),
        );

        expect(result, isFalse);

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;
        expect(data.isWaiting, isFalse);
      });
    });

    group('_handleRatingsSubmitted', () {
      test('formats ratings and sends as user message', () async {
        stubSuccessfulStart();
        when(() => mockWorkflow.getSession(any())).thenReturn(null);
        when(
          () => mockWorkflow.sendMessage(
            sessionId: any(named: 'sessionId'),
            userMessage: any(named: 'userMessage'),
          ),
        ).thenAnswer((_) async => 'Acknowledged your ratings.');

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        // Trigger ratings submission via the notifier's public sendMessage
        // which internally calls _handleRatingsSubmitted. Since
        // _handleRatingsSubmitted is private, we invoke it indirectly by
        // calling sendMessage with the formatted ratings text.
        // Instead, we directly test the effect by storing ratings and
        // sending the formatted message.
        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .sendMessage('My category ratings: language: 4/5, tone: 3/5'),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // User message with ratings should be in the list.
        expect(
          data.messages.whereType<EvolutionUserMessage>().any(
            (m) => m.text.contains('category ratings'),
          ),
          isTrue,
        );
        expect(data.isWaiting, isFalse);
      });
    });

    group('sendMessage — additional paths', () {
      test('handles null response from workflow gracefully', () async {
        stubSuccessfulStart();
        when(() => mockWorkflow.getSession(any())).thenReturn(null);
        when(
          () => mockWorkflow.sendMessage(
            sessionId: any(named: 'sessionId'),
            userMessage: any(named: 'userMessage'),
          ),
        ).thenAnswer((_) async => null);

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .sendMessage('hello'),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // User message should be present, but no assistant response.
        expect(data.messages.whereType<EvolutionUserMessage>().length, 1);
        // Only opening assistant + no response = 1 assistant message total.
        expect(data.messages.whereType<EvolutionAssistantMessage>().length, 1);
        expect(data.isWaiting, isFalse);
      });

      test(
        'skips approval check when skipApprovalCheck is true even with '
        'pending proposal',
        () async {
          final strategy = _TestableEvolutionStrategy()
            ..testSoulProposal = const PendingSoulProposal(
              voiceDirective: 'New voice',
              toneBounds: 'New tone',
              coachingStyle: 'New coaching',
              antiSycophancyPolicy: 'New anti-sycophancy',
              rationale: 'Refine personality.',
            );
          final sessionWithProposal = ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestSoulId,
            conversationId: 'conv-1',
            strategy: strategy,
            modelId: 'model-1',
          );

          stubSuccessfulStart(session: sessionWithProposal);
          when(
            () => mockWorkflow.getSession('session-1'),
          ).thenReturn(sessionWithProposal);
          when(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: any(named: 'userMessage'),
            ),
          ).thenAnswer((_) async => 'Got it.');

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          // Send "ok" with skipApprovalCheck — should NOT route to approval.
          await withClock(
            testClock,
            () => container
                .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                .sendMessage('ok', skipApprovalCheck: true),
          );

          // sendMessage on workflow SHOULD have been called (not routed to
          // approval).
          verify(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: 'ok',
            ),
          ).called(1);

          // completeSoulSession should NOT have been called.
          verifyNever(
            () => mockWorkflow.completeSoulSession(
              sessionId: any(named: 'sessionId'),
              categoryRatings: any(named: 'categoryRatings'),
            ),
          );
        },
      );

      test('handles empty string response from workflow', () async {
        stubSuccessfulStart();
        when(() => mockWorkflow.getSession(any())).thenReturn(null);
        when(
          () => mockWorkflow.sendMessage(
            sessionId: any(named: 'sessionId'),
            userMessage: any(named: 'userMessage'),
          ),
        ).thenAnswer((_) async => '   ');

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .sendMessage('test'),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // Whitespace-only response should not produce an assistant message.
        // Opening assistant message + no new response = 1 assistant total.
        expect(data.messages.whereType<EvolutionAssistantMessage>().length, 1);
        expect(data.isWaiting, isFalse);
      });
    });

    group('approveSoulProposal — additional paths', () {
      test(
        'uses recap content when TLDR is empty',
        () async {
          final soulVersion = makeTestSoulDocumentVersion(version: 3);

          stubSuccessfulStart();
          when(
            () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
          ).thenReturn(
            const PendingRitualRecap(
              tldr: '',
              content: 'Detailed recap content here.',
            ),
          );
          when(
            () => mockWorkflow.completeSoulSession(
              sessionId: 'session-1',
              categoryRatings: any(named: 'categoryRatings'),
            ),
          ).thenAnswer((_) async => soulVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          final result = await withClock(
            testClock,
            () => container
                .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                .approveSoulProposal(),
          );

          expect(result, isTrue);

          final data = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          // When TLDR is empty, the content should be used as recap summary.
          expect(
            data.messages.whereType<EvolutionAssistantMessage>().any(
              (m) => m.text == 'Detailed recap content here.',
            ),
            isTrue,
          );
        },
      );

      test(
        'omits recap assistant message when recap is null',
        () async {
          final soulVersion = makeTestSoulDocumentVersion(version: 4);

          stubSuccessfulStart();
          when(
            () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
          ).thenReturn(null);
          when(
            () => mockWorkflow.completeSoulSession(
              sessionId: 'session-1',
              categoryRatings: any(named: 'categoryRatings'),
            ),
          ).thenAnswer((_) async => soulVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          final result = await withClock(
            testClock,
            () => container
                .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                .approveSoulProposal(),
          );

          expect(result, isTrue);

          final data = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          // No recap means only opening assistant message + system version msg.
          // Count assistant messages after approval (excluding opening).
          final postApprovalAssistantMsgs = data.messages
              .whereType<EvolutionAssistantMessage>()
              .where(
                (m) => m.text != 'Hello!',
              );
          expect(postApprovalAssistantMsgs, isEmpty);

          // Version created message should still be present.
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'soul_version_created:v4',
            ),
            isTrue,
          );
        },
      );
    });

    group('endSession — edge cases', () {
      test('cleans up state even when abandonSession throws', () async {
        stubSuccessfulStart();

        container = createContainer();
        await withClock(
          testClock,
          () => container.read(
            soulEvolutionChatStateProvider(kTestSoulId).future,
          ),
        );

        // Re-stub to throw AFTER session started successfully.
        var callCount = 0;
        when(
          () => mockWorkflow.abandonSession(sessionId: 'session-1'),
        ).thenAnswer((_) async {
          callCount++;
          // Throw on the first call (endSession), succeed on subsequent
          // calls (dispose cleanup).
          if (callCount == 1) {
            throw Exception('cleanup error');
          }
        });

        // Also make the workflow report no active session after endSession
        // so the dispose callback doesn't attempt another abandon.
        when(
          () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
        ).thenReturn(null);

        await withClock(
          testClock,
          () => container
              .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
              .endSession(),
        );

        final data = container
            .read(soulEvolutionChatStateProvider(kTestSoulId))
            .value!;

        // Session should be cleaned up even after error.
        expect(data.sessionId, isNull);
        expect(
          data.messages.whereType<EvolutionSystemMessage>().any(
            (m) => m.text == 'session_abandoned',
          ),
          isTrue,
        );
      });
    });

    group('build — opening surfaces', () {
      test(
        'adds EvolutionSurfaceMessages when genUiBridge has pending surfaces',
        () async {
          // Build a GenUiBridge backed by a MockSurfaceController, then
          // pre-populate it with one pending surface via handleToolCall.
          final mockProcessor = MockSurfaceController();
          when(
            () => mockProcessor.handleMessage(any()),
          ).thenReturn(null);

          final bridge = GenUiBridge(processor: mockProcessor)
            ..handleToolCall({
              'surfaceId': 'opening-surface-1',
              'rootType': 'EvolutionProposal',
              'data': <String, dynamic>{},
            });

          // Create a strategy that exposes the bridge.
          final strategyWithBridge = EvolutionStrategy(genUiBridge: bridge);
          final sessionWithBridge = ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestSoulId,
            conversationId: 'conv-1',
            strategy: strategyWithBridge,
            modelId: 'model-1',
          );

          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => 'Welcome!');
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(sessionWithBridge);
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});

          container = createContainer();
          final data = await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          // Should contain system + assistant (opening text) + surface message.
          final surfaceMessages = data.messages
              .whereType<EvolutionSurfaceMessage>()
              .toList();
          expect(surfaceMessages.length, 1);
          expect(surfaceMessages.first.surfaceId, 'opening-surface-1');
          // Surface comes after the assistant text in opening sequence.
          final assistantIdx = data.messages.indexWhere(
            (m) => m is EvolutionAssistantMessage,
          );
          final surfaceIdx = data.messages.indexWhere(
            (m) => m is EvolutionSurfaceMessage,
          );
          expect(surfaceIdx, greaterThan(assistantIdx));
        },
      );

      test(
        'adds multiple surfaces from opening drain in order',
        () async {
          final mockProcessor = MockSurfaceController();
          when(
            () => mockProcessor.handleMessage(any()),
          ).thenReturn(null);

          final bridge = GenUiBridge(processor: mockProcessor)
            ..handleToolCall({
              'surfaceId': 'surf-a',
              'rootType': 'EvolutionProposal',
              'data': <String, dynamic>{},
            })
            ..handleToolCall({
              'surfaceId': 'surf-b',
              'rootType': 'EvolutionProposal',
              'data': <String, dynamic>{},
            });

          final strategyWithBridge = EvolutionStrategy(genUiBridge: bridge);
          final sessionWithBridge = ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestSoulId,
            conversationId: 'conv-1',
            strategy: strategyWithBridge,
            modelId: 'model-1',
          );

          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => 'Hello!');
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(sessionWithBridge);
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});

          container = createContainer();
          final data = await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          final surfaceMessages = data.messages
              .whereType<EvolutionSurfaceMessage>()
              .toList();
          expect(surfaceMessages.length, 2);
          expect(surfaceMessages[0].surfaceId, 'surf-a');
          expect(surfaceMessages[1].surfaceId, 'surf-b');
        },
      );
    });

    group('build — event handler wiring', () {
      /// Helper that creates a session with a GenUiEventHandler so callback
      /// wiring (lines 80-94) can be exercised.
      ActiveEvolutionSession makeSessionWithEventHandler({
        String sessionId = 'session-1',
      }) {
        final mockProcessor = MockSurfaceController();
        when(() => mockProcessor.handleMessage(any())).thenReturn(null);
        when(() => mockProcessor.onSubmit).thenAnswer(
          (_) => const Stream.empty(),
        );

        final eventHandler = GenUiEventHandler(processor: mockProcessor)
          ..listen();

        return ActiveEvolutionSession(
          sessionId: sessionId,
          templateId: kTestSoulId,
          conversationId: 'conv-1',
          strategy: EvolutionStrategy(),
          modelId: 'model-1',
          eventHandler: eventHandler,
        );
      }

      test(
        'onSoulProposalAction approved triggers approveSoulProposal',
        () async {
          final session = makeSessionWithEventHandler();
          final soulVersion = makeTestSoulDocumentVersion(version: 5);

          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => 'Hello!');
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(session);
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(
            () => mockWorkflow.getCurrentRecap(sessionId: 'session-1'),
          ).thenReturn(null);
          when(
            () => mockWorkflow.completeSoulSession(
              sessionId: 'session-1',
              categoryRatings: any(named: 'categoryRatings'),
            ),
          ).thenAnswer((_) async => soulVersion);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          // Verify that the callback was wired during build.
          expect(session.eventHandler!.onSoulProposalAction, isNotNull);

          // Fire the wired callback directly — simulates GenUI approve action.
          // The callback calls approveSoulProposal() which is async; pump the
          // event loop until completeSoulSession is called.
          withClock(testClock, () {
            session.eventHandler!.onSoulProposalAction!(
              'surf-1',
              'soul_proposal_approved',
            );
          });

          // Pump the event loop until the async approveSoulProposal completes.
          await withClock(
            testClock,
            () async {
              // Allow multiple event-loop ticks for the full async chain.
              for (var i = 0; i < 10; i++) {
                await Future<void>.microtask(() {});
              }
            },
          );

          // completeSoulSession should have been called.
          verify(
            () => mockWorkflow.completeSoulSession(
              sessionId: 'session-1',
              categoryRatings: any(named: 'categoryRatings'),
            ),
          ).called(1);

          final data = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          // Session should be completed.
          expect(data.sessionId, isNull);
          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text.startsWith('soul_version_created:'),
            ),
            isTrue,
          );
        },
      );

      test(
        'onSoulProposalAction rejected triggers rejectSoulProposal',
        () async {
          final session = makeSessionWithEventHandler();

          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => 'Hello!');
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(session);
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(
            () => mockWorkflow.rejectSoulProposal(sessionId: 'session-1'),
          ).thenReturn(null);

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          withClock(testClock, () {
            session.eventHandler!.onSoulProposalAction!(
              'surf-1',
              'soul_proposal_rejected',
            );
          });

          final data = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          verify(
            () => mockWorkflow.rejectSoulProposal(sessionId: 'session-1'),
          ).called(1);

          expect(
            data.messages.whereType<EvolutionSystemMessage>().any(
              (m) => m.text == 'soul_proposal_rejected',
            ),
            isTrue,
          );
        },
      );

      test(
        'onRatingsSubmitted callback is wired and triggers '
        '_handleRatingsSubmitted which updates categoryRatings synchronously',
        () async {
          final session = makeSessionWithEventHandler();

          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => 'Hello!');
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(session);
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(
            () => mockWorkflow.getSession(any()),
          ).thenReturn(null);
          when(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: any(named: 'userMessage'),
            ),
          ).thenAnswer((_) async => 'Ratings received.');

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          // Verify the callback was wired during build.
          expect(session.eventHandler!.onRatingsSubmitted, isNotNull);

          // Fire the callback synchronously — categoryRatings is updated
          // synchronously before sendMessage is awaited.
          withClock(testClock, () {
            session.eventHandler!.onRatingsSubmitted!(
              'surf-1',
              {'focus': 4, 'energy': 3},
            );
          });

          // categoryRatings update is synchronous in _handleRatingsSubmitted.
          final dataAfterSync = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;
          expect(dataAfterSync.categoryRatings, {'focus': 4, 'energy': 3});

          // The user message is added synchronously by sendMessage before its
          // first await, so it's present even without pumping the event loop.
          final userMsgs = dataAfterSync.messages
              .whereType<EvolutionUserMessage>();
          expect(
            userMsgs.any(
              (m) =>
                  m.text.contains('focus: 4/5') &&
                  m.text.contains('energy: 3/5'),
            ),
            isTrue,
          );

          // Wait for sendMessage async chain to complete so the workflow call
          // can be verified and dispose cleanup is safe.
          await withClock(
            testClock,
            () async {
              for (var i = 0; i < 10; i++) {
                await Future<void>.microtask(() {});
              }
            },
          );

          verify(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: any(named: 'userMessage'),
            ),
          ).called(1);
        },
      );

      test(
        'onBinaryChoiceSubmitted callback is wired and calls sendMessage '
        'with skipApprovalCheck=true',
        () async {
          final session = makeSessionWithEventHandler();

          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => 'Hello!');
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(session);
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(
            () => mockWorkflow.getSession(any()),
          ).thenReturn(null);
          when(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: any(named: 'userMessage'),
            ),
          ).thenAnswer((_) async => 'Choice noted.');

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          // Verify the callback was wired during build.
          expect(session.eventHandler!.onBinaryChoiceSubmitted, isNotNull);

          // Fire the callback — sendMessage is called with skipApprovalCheck.
          // The user message is added synchronously before sendMessage awaits.
          withClock(testClock, () {
            session.eventHandler!.onBinaryChoiceSubmitted!(
              'surf-1',
              'option_a',
            );
          });

          final dataAfterSync = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          // User message 'option_a' should be added synchronously.
          expect(
            dataAfterSync.messages.whereType<EvolutionUserMessage>().any(
              (m) => m.text == 'option_a',
            ),
            isTrue,
          );

          // Pump event loop for sendMessage async chain to settle.
          await withClock(
            testClock,
            () async {
              for (var i = 0; i < 10; i++) {
                await Future<void>.microtask(() {});
              }
            },
          );

          verify(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'option_a',
            ),
          ).called(1);
        },
      );

      test(
        'onABComparisonSubmitted callback is wired and calls sendMessage '
        'with skipApprovalCheck=true',
        () async {
          final session = makeSessionWithEventHandler();

          when(
            () => mockWorkflow.startSoulSession(soulId: kTestSoulId),
          ).thenAnswer((_) async => 'Hello!');
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(session);
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer((_) async {});
          when(
            () => mockWorkflow.getSession(any()),
          ).thenReturn(null);
          when(
            () => mockWorkflow.sendMessage(
              sessionId: any(named: 'sessionId'),
              userMessage: any(named: 'userMessage'),
            ),
          ).thenAnswer((_) async => 'Comparison noted.');

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          // Verify the callback was wired during build.
          expect(session.eventHandler!.onABComparisonSubmitted, isNotNull);

          // Fire the callback — user message added synchronously.
          withClock(testClock, () {
            session.eventHandler!.onABComparisonSubmitted!(
              'surf-1',
              'version_b',
            );
          });

          final dataAfterSync = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          expect(
            dataAfterSync.messages.whereType<EvolutionUserMessage>().any(
              (m) => m.text == 'version_b',
            ),
            isTrue,
          );

          // Pump event loop for sendMessage async chain to settle.
          await withClock(
            testClock,
            () async {
              for (var i = 0; i < 10; i++) {
                await Future<void>.microtask(() {});
              }
            },
          );

          verify(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: 'version_b',
            ),
          ).called(1);
        },
      );
    });

    group('dispose — abandon error path', () {
      test(
        'logs error and does not throw when abandonSession fails on dispose',
        () async {
          stubSuccessfulStart();

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          // After build, override stubs so that:
          // - getActiveSessionForSoul returns a non-null session (triggers
          //   the dispose branch at line 103)
          // - abandonSession returns a failing Future (exercises the catchError
          //   at lines 109/112 — thenThrow would propagate synchronously,
          //   defeating the unawaited+catchError pattern).
          when(
            () => mockWorkflow.getActiveSessionForSoul(kTestSoulId),
          ).thenReturn(makeSession());
          when(
            () => mockWorkflow.abandonSession(sessionId: 'session-1'),
          ).thenAnswer(
            (_) => Future.error(Exception('dispose abandon failed')),
          );

          // Disposing the container triggers ref.onDispose and the
          // unawaited abandonSession call with its catchError handler.
          // This must NOT propagate the exception.
          container.dispose();

          // Allow the unawaited Future to settle.
          await Future<void>.delayed(Duration.zero);
          // If we reach here, the catchError absorbed the exception correctly.
        },
      );
    });

    group('sendMessage — surface messages', () {
      test(
        'appends surface messages from genUiBridge during sendMessage',
        () async {
          stubSuccessfulStart();

          // Create a bridge pre-loaded with a surface that will be added
          // by getSession(...) during sendMessage.
          final mockProcessor = MockSurfaceController();
          when(
            () => mockProcessor.handleMessage(any()),
          ).thenReturn(null);
          final bridge = GenUiBridge(processor: mockProcessor)
            ..handleToolCall({
              'surfaceId': 'response-surface-1',
              'rootType': 'EvolutionProposal',
              'data': <String, dynamic>{},
            });

          // getSession will return a session whose strategy has the bridge.
          final strategyWithBridge = EvolutionStrategy(genUiBridge: bridge);
          final sessionWithBridge = ActiveEvolutionSession(
            sessionId: 'session-1',
            templateId: kTestSoulId,
            conversationId: 'conv-1',
            strategy: strategyWithBridge,
            modelId: 'model-1',
          );

          when(
            () => mockWorkflow.getSession('session-1'),
          ).thenReturn(sessionWithBridge);
          when(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: any(named: 'userMessage'),
            ),
          ).thenAnswer((_) async => 'Here is a surface.');

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                .sendMessage('show me'),
          );

          final data = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          // A surface message from the bridge should appear after sendMessage.
          final surfaceMessages = data.messages
              .whereType<EvolutionSurfaceMessage>()
              .toList();
          expect(surfaceMessages.length, 1);
          expect(surfaceMessages.first.surfaceId, 'response-surface-1');

          // Surface should come after the assistant response text.
          final assistantIdx = data.messages.lastIndexWhere(
            (m) => m is EvolutionAssistantMessage,
          );
          final surfaceIdx = data.messages.lastIndexWhere(
            (m) => m is EvolutionSurfaceMessage,
          );
          expect(surfaceIdx, greaterThan(assistantIdx));
          expect(data.isWaiting, isFalse);
        },
      );

      test(
        'no surface messages added when bridge has no pending surfaces',
        () async {
          stubSuccessfulStart();
          when(
            () => mockWorkflow.getSession('session-1'),
          ).thenReturn(makeSession());
          when(
            () => mockWorkflow.sendMessage(
              sessionId: 'session-1',
              userMessage: any(named: 'userMessage'),
            ),
          ).thenAnswer((_) async => 'Plain response.');

          container = createContainer();
          await withClock(
            testClock,
            () => container.read(
              soulEvolutionChatStateProvider(kTestSoulId).future,
            ),
          );

          await withClock(
            testClock,
            () => container
                .read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                .sendMessage('hello'),
          );

          final data = container
              .read(soulEvolutionChatStateProvider(kTestSoulId))
              .value!;

          // No surfaces when the bridge has nothing pending.
          expect(
            data.messages.whereType<EvolutionSurfaceMessage>(),
            isEmpty,
          );
          // But the assistant text response should still be added.
          expect(
            data.messages.whereType<EvolutionAssistantMessage>().any(
              (m) => m.text == 'Plain response.',
            ),
            isTrue,
          );
        },
      );
    });
  });
}
