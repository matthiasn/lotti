import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';

/// Daily OS's title hook (registered in journal's
/// `taskTitleChangedHooksProvider`): a planned block carries its task's title,
/// so a renamed task renames its blocks.
Future<void> Function(String taskId, String title) dailyOsTaskTitleSync(
  Ref ref,
) =>
    (taskId, title) => ref
        .read(dayAgentPlanServiceProvider)
        .syncTaskTitle(taskId: taskId, title: title);
