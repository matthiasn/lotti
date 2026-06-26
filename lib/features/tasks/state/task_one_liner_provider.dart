import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';

/// Fetches the AI-generated one-liner subtitle for a task from its agent
/// report.
///
/// Watches [agentUpdateStreamProvider] so the value refreshes automatically
/// when the agent report changes (e.g. after an agent run completes).
/// Auto-disposes when the list item scrolls off-screen.
final FutureProviderFamily<String?, String> taskOneLinerProvider =
    FutureProvider.autoDispose.family<String?, String>(
      taskOneLiner,
      name: 'taskOneLinerProvider',
    );
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
