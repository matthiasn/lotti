import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_one_liner_provider.g.dart';

/// Fetches the AI-generated one-liner subtitle for a task from its agent
/// report.
///
/// Watches [agentUpdateStreamProvider] so the value refreshes automatically
/// when the agent report changes (e.g. after an agent run completes).
/// Auto-disposes when the list item scrolls off-screen.
@riverpod
Future<String?> taskOneLiner(Ref ref, String taskId) async {
  ref.watch(agentUpdateStreamProvider(taskId));
  final repository = ref.watch(agentRepositoryProvider);
  final reports = await repository.getLatestTaskReportsForTaskIds([taskId]);
  final oneLiner = reports[taskId]?.oneLiner?.trim();
  if (oneLiner != null && oneLiner.isNotEmpty) {
    return oneLiner;
  }
  return null;
}
