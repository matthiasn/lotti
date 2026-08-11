import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_chat_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockGoalChatService extends Mock implements GoalChatService {}

void main() {
  test('composer copyWith can retain an explicit failure', () {
    final failed = const GoalChatComposerState().copyWith(
      failedMessage: 'Keep me honest.',
      failedMessageId: 'message-1',
    );
    final retained = failed.copyWith(draft: 'Still here');
    final cleared = retained.copyWith(clearFailure: true);

    expect(retained.failedMessage, 'Keep me honest.');
    expect(retained.failedMessageId, 'message-1');
    expect(cleared.failedMessage, isNull);
    expect(cleared.failedMessageId, isNull);
  });

  test(
    'keeps the draft when an unexpected send failure has no turn id',
    () async {
      final service = _MockGoalChatService();
      when(
        () => service.sendMessage(agentId: 'goal-1', text: 'Try this.'),
      ).thenThrow(StateError('database unavailable'));
      final container = ProviderContainer(
        overrides: [goalChatServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        goalChatControllerProvider('goal-1').notifier,
      )..updateDraft('Try this.');

      await controller.send();

      final state = container.read(goalChatControllerProvider('goal-1'));
      expect(state.draft, 'Try this.');
      expect(state.failedMessage, 'Try this.');
      expect(state.failedMessageId, isNull);
    },
  );

  test(
    'retry preserves the durable turn id across typed and unknown errors',
    () async {
      final service = _MockGoalChatService();
      when(
        () => service.sendMessage(agentId: 'goal-1', text: 'Keep trying.'),
      ).thenThrow(
        const GoalChatTurnException('offline', messageId: 'message-1'),
      );
      var retryAttempts = 0;
      when(
        () => service.retryMessage(
          agentId: 'goal-1',
          messageId: 'message-1',
        ),
      ).thenAnswer((_) async {
        retryAttempts++;
        if (retryAttempts == 1) {
          throw const GoalChatTurnException('still offline');
        }
        throw StateError('database unavailable');
      });
      final container = ProviderContainer(
        overrides: [goalChatServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        goalChatControllerProvider('goal-1').notifier,
      )..updateDraft('Keep trying.');
      await controller.send();

      await controller.retry();
      var state = container.read(goalChatControllerProvider('goal-1'));
      expect(state.failedMessage, 'Keep trying.');
      expect(state.failedMessageId, 'message-1');

      await controller.retry();
      state = container.read(goalChatControllerProvider('goal-1'));
      expect(state.draft, 'Keep trying.');
      expect(state.failedMessage, 'Keep trying.');
      expect(state.failedMessageId, 'message-1');
      expect(retryAttempts, 2);
    },
  );

  test('keeps a failed draft for retry and clears it after success', () async {
    final service = _MockGoalChatService();
    var attempts = 0;
    when(
      () => service.sendMessage(agentId: 'goal-1', text: 'Keep me honest.'),
    ).thenAnswer((_) async {
      attempts++;
      throw const GoalChatTurnException(
        'offline',
        messageId: 'message-1',
      );
    });
    when(
      () => service.retryMessage(
        agentId: 'goal-1',
        messageId: 'message-1',
      ),
    ).thenAnswer((_) async => attempts++);
    var chatReads = 0;
    final container = ProviderContainer(
      overrides: [
        goalChatServiceProvider.overrideWithValue(service),
        agentChatProjectionProvider('goal-1').overrideWith((ref) async {
          chatReads++;
          return [];
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(agentChatProjectionProvider('goal-1').future);
    final controller = container.read(
      goalChatControllerProvider('goal-1').notifier,
    );

    await (controller..updateDraft('Keep me honest.')).send();
    expect(
      container.read(goalChatControllerProvider('goal-1')).draft,
      'Keep me honest.',
    );
    expect(
      container.read(goalChatControllerProvider('goal-1')).failedMessage,
      'Keep me honest.',
    );
    expect(
      container.read(goalChatControllerProvider('goal-1')).failedMessageId,
      'message-1',
    );

    await controller.retry();
    await container.read(agentChatProjectionProvider('goal-1').future);
    expect(container.read(goalChatControllerProvider('goal-1')).draft, isEmpty);
    expect(
      container.read(goalChatControllerProvider('goal-1')).failedMessage,
      isNull,
    );
    expect(attempts, 2);
    expect(chatReads, 2);
    verify(
      () => service.retryMessage(
        agentId: 'goal-1',
        messageId: 'message-1',
      ),
    ).called(1);
    verify(
      () => service.sendMessage(agentId: 'goal-1', text: 'Keep me honest.'),
    ).called(1);
  });

  test(
    'empty sends and retries are no-ops while editing clears failure',
    () async {
      final service = _MockGoalChatService();
      final container = ProviderContainer(
        overrides: [goalChatServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        goalChatControllerProvider('goal-1').notifier,
      );

      await controller.send();
      await controller.retry();
      controller.updateDraft('Fresh thought');

      final state = container.read(goalChatControllerProvider('goal-1'));
      expect(state.draft, 'Fresh thought');
      expect(state.failedMessage, isNull);
      verifyNever(
        () => service.sendMessage(
          agentId: any(named: 'agentId'),
          text: any(named: 'text'),
        ),
      );
      verifyNever(
        () => service.retryMessage(
          agentId: any(named: 'agentId'),
          messageId: any(named: 'messageId'),
        ),
      );
    },
  );

  test(
    'a committed chat wake refreshes the active banner projection',
    () async {
      final service = _MockGoalChatService();
      when(
        () =>
            service.sendMessage(agentId: 'goal-1', text: 'New banner please.'),
      ).thenAnswer((_) async {});
      var bannerReads = 0;
      var chatReads = 0;
      final container = ProviderContainer(
        overrides: [
          goalChatServiceProvider.overrideWithValue(service),
          activeGoalNudgesProvider.overrideWith((ref) async {
            bannerReads++;
            return [];
          }),
          agentChatProjectionProvider('goal-1').overrideWith((ref) async {
            chatReads++;
            return [];
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeGoalNudgesProvider.future);
      await container.read(agentChatProjectionProvider('goal-1').future);
      expect(bannerReads, 1);
      expect(chatReads, 1);

      final controller = container.read(
        goalChatControllerProvider('goal-1').notifier,
      )..updateDraft('New banner please.');
      await controller.send();
      await container.read(activeGoalNudgesProvider.future);
      await container.read(agentChatProjectionProvider('goal-1').future);

      expect(bannerReads, 2);
      expect(chatReads, 2);
    },
  );

  test('a committed snooze immediately suppresses only that banner', () async {
    final service = _MockGoalChatService();
    final repository = MockAgentRepository();
    final now = DateTime.utc(2026, 8, 11, 12);
    final until = now.add(const Duration(hours: 3));
    when(
      () => service.sendMessage(agentId: 'goal-1', text: 'Snooze this ad.'),
    ).thenAnswer((_) async {});
    when(
      () => repository.getEntitiesByAgentId(
        'goal-1',
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer(
      (_) async => [
        _nudge(
          id: 'snoozed',
          provenance: {'snoozedUntil': until.toIso8601String()},
        ),
        _nudge(id: 'still-visible'),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        goalChatServiceProvider.overrideWithValue(service),
        agentRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      goalChatControllerProvider('goal-1').notifier,
    )..updateDraft('Snooze this ad.');

    await withClock(Clock.fixed(now), controller.send);

    expect(container.read(locallySnoozedNudgeDeadlinesProvider), {
      'snoozed': until,
    });
  });
}

GoalNudgeEntity _nudge({
  required String id,
  Map<String, String> provenance = const {},
}) =>
    AgentDomainEntity.goalNudge(
          id: id,
          agentId: 'goal-1',
          status: GoalNudgeStatus.active,
          brief: const GoalNudgeBrief(
            headline: 'Keep walking',
            tone: GoalNudgeTone.nudge,
            animation: GoalBannerAnimation.steady,
          ),
          briefDigest: id,
          createdAt: DateTime(2026, 8, 11),
          updatedAt: DateTime(2026, 8, 11),
          vectorClock: null,
          provenance: provenance,
        )
        as GoalNudgeEntity;
