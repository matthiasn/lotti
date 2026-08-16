import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';

void main() {
  test('every goal route lives under the unified Goals tab root', () {
    expect(goalsRootPath, '/goals');
    expect(goalCreatePath, '/goals/create');
    expect(goalDetailPath('goal-1'), '/goals/details/goal-1');
    expect(goalChatPath('goal-1'), '/goals/details/goal-1/chat');
    expect(goalEditPath('goal-1'), '/goals/details/goal-1/edit');
  });

  test('the derived routes match the GoalsLocation path patterns for any '
      'agent id', () {
    // The detail/chat/edit shapes must slot into `/goals/details/:agentId`
    // (+ `/chat` | `/edit`) — an id is a single path segment.
    const agentId = '123e4567-e89b-12d3-a456-426614174000';
    expect(goalDetailPath(agentId), '/goals/details/$agentId');
    expect(
      goalChatPath(agentId),
      '${goalDetailPath(agentId)}/chat',
    );
    expect(
      goalEditPath(agentId),
      '${goalDetailPath(agentId)}/edit',
    );
  });
}
