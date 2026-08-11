import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_chat_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoalChatService extends Mock implements GoalChatService {}

void main() {
  test('composer copyWith can retain an explicit failure', () {
    final state = const GoalChatComposerState().copyWith(
      failedMessage: 'Keep me honest.',
    );

    expect(state.failedMessage, 'Keep me honest.');
  });

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
    final container = ProviderContainer(
      overrides: [goalChatServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
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
    expect(container.read(goalChatControllerProvider('goal-1')).draft, isEmpty);
    expect(
      container.read(goalChatControllerProvider('goal-1')).failedMessage,
      isNull,
    );
    expect(attempts, 2);
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
      final container = ProviderContainer(
        overrides: [
          goalChatServiceProvider.overrideWithValue(service),
          activeGoalNudgesProvider.overrideWith((ref) async {
            bannerReads++;
            return [];
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeGoalNudgesProvider.future);
      expect(bannerReads, 1);

      final controller = container.read(
        goalChatControllerProvider('goal-1').notifier,
      )..updateDraft('New banner please.');
      await controller.send();
      await container.read(activeGoalNudgesProvider.future);

      expect(bannerReads, 2);
    },
  );
}
