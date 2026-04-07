import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/agent_workflow_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_state.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../test_utils.dart';

/// Strategy subclass exposing a settable soul proposal for test purposes.
class _TestableEvolutionStrategy extends EvolutionStrategy {
  _TestableEvolutionStrategy({super.genUiBridge});

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

  ActiveEvolutionSession _makeSession({
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
  void _stubSuccessfulStart({
    String response = 'Hello!',
    ActiveEvolutionSession? session,
  }) {
    final activeSession = session ?? _makeSession();
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
          _stubSuccessfulStart(
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
          ).thenReturn(_makeSession());

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
        _stubSuccessfulStart();

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

          _stubSuccessfulStart(session: sessionWithProposal);
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

        _stubSuccessfulStart();
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
        _stubSuccessfulStart();
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
        _stubSuccessfulStart();
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
        _stubSuccessfulStart();

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
  });
}
