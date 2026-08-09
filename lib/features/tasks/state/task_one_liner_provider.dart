import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/services/db_notification.dart';

/// Stable, de-duplicated task IDs for one batched one-liner lookup.
@immutable
class TaskOneLinerRequest {
  factory TaskOneLinerRequest(Iterable<String> taskIds) {
    final sortedIds = taskIds.toSet().toList()..sort();
    return TaskOneLinerRequest._(List.unmodifiable(sortedIds));
  }

  const TaskOneLinerRequest._(this.taskIds);

  final List<String> taskIds;

  static const _equality = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskOneLinerRequest && _equality.equals(taskIds, other.taskIds);

  @override
  int get hashCode => _equality.hash(taskIds);
}

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

/// Fetches one-liners for a complete linked-task card in one repository call.
///
/// The shared agent notification refreshes the single batch when any report
/// changes, avoiding one database lookup and one stream subscription per row.
final FutureProviderFamily<Map<String, String>, TaskOneLinerRequest>
taskOneLinersProvider = FutureProvider.autoDispose
    .family<Map<String, String>, TaskOneLinerRequest>(
      taskOneLiners,
      name: 'taskOneLinersProvider',
    );
Future<Map<String, String>> taskOneLiners(
  Ref ref,
  TaskOneLinerRequest request,
) async {
  if (request.taskIds.isEmpty) return const {};

  ref.watch(agentUpdateStreamProvider(agentNotification));
  final repository = ref.watch(agentRepositoryProvider);
  final reports = await repository.getLatestTaskReportsForTaskIds(
    request.taskIds,
  );
  final oneLiners = <String, String>{};
  for (final taskId in request.taskIds) {
    final oneLiner = reports[taskId]?.oneLiner?.trim();
    if (oneLiner != null && oneLiner.isNotEmpty) {
      oneLiners[taskId] = oneLiner;
    }
  }
  return Map.unmodifiable(oneLiners);
}
