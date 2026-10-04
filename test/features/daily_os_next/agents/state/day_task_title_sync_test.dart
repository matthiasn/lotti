import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_task_title_sync.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  test('a renamed task renames its planned blocks', () async {
    final planService = MockDayAgentPlanService();
    when(
      () => planService.syncTaskTitle(
        taskId: any(named: 'taskId'),
        title: any(named: 'title'),
      ),
    ).thenAnswer((_) async => 2);
    final probe = Provider(dailyOsTaskTitleSync);
    final container = ProviderContainer(
      overrides: [dayAgentPlanServiceProvider.overrideWithValue(planService)],
    );
    addTearDown(container.dispose);

    await container.read(probe)('task-1', 'Renamed');

    verify(
      () => planService.syncTaskTitle(taskId: 'task-1', title: 'Renamed'),
    ).called(1);
  });
}
