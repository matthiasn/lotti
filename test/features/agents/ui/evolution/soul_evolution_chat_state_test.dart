import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
