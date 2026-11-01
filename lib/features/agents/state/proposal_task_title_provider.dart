import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/service_providers.dart';

/// The title of task `taskId`, for a proposal that names the task by id
/// alone — an agent's `link_task`, whose args are kept to the relation and
/// the target id so that repeats share a fingerprint. Null when the task is
/// gone, is not a task, or has no title.
///
/// Read at render time and never written back into the proposal: it only
/// lets the row say, in the reader's language, which task it means.
/// Refreshes when a notification names the task, so a rename shows.
final FutureProviderFamily<String?, String> proposalTaskTitleProvider =
    FutureProvider.autoDispose.family<String?, String>(
      proposalTaskTitle,
      name: 'proposalTaskTitleProvider',
    );

Future<String?> proposalTaskTitle(Ref ref, String taskId) async {
  ref.watch(agentUpdateStreamProvider(taskId));
  final entity = await ref.watch(journalDbProvider).journalEntityById(taskId);
  if (entity is! Task || entity.meta.deletedAt != null) return null;
  final title = entity.data.title.trim();
  return title.isEmpty ? null : title;
}
