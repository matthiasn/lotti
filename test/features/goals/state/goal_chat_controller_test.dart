import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_chat_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoalChatService extends Mock implements GoalChatService {}

void main() {
  test('keeps a failed draft for retry and clears it after success', () async {
    final service = _MockGoalChatService();
    var attempts = 0;
    when(
      () => service.sendMessage(agentId: 'goal-1', text: 'Keep me honest.'),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw const GoalChatTurnException('offline');
    });
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

    await controller.retry();
    expect(container.read(goalChatControllerProvider('goal-1')).draft, isEmpty);
    expect(
      container.read(goalChatControllerProvider('goal-1')).failedMessage,
      isNull,
    );
    expect(attempts, 2);
  });
}
