import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';

/// What a glance at a task shows before opening it: the task, and what its
/// agent's latest report says about it.
@immutable
class TaskPreview {
  const TaskPreview({required this.task, this.oneLiner, this.tldr});

  final Task task;

  /// The report's one-line subtitle; null when there is none.
  final String? oneLiner;

  /// The report's TL;DR, markdown; null when there is none.
  final String? tldr;

  /// The task's own notes, trimmed; null when it has none. What a preview
  /// shows when no report has been written yet.
  String? get notes => _nonEmpty(task.entryText?.plainText);

  @override
  bool operator ==(Object other) =>
      other is TaskPreview &&
      other.task == task &&
      other.oneLiner == oneLiner &&
      other.tldr == tldr;

  @override
  int get hashCode => Object.hash(task, oneLiner, tldr);
}

String? _nonEmpty(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The preview of task `taskId`, or null when it is gone — deleted, or not a
/// task at all.
///
/// Refreshes whenever a notification names the task, which a new report, a
/// rename and a status change all do.
final FutureProviderFamily<TaskPreview?, String> taskPreviewProvider =
    FutureProvider.autoDispose.family<TaskPreview?, String>(
      taskPreview,
      name: 'taskPreviewProvider',
    );

Future<TaskPreview?> taskPreview(Ref ref, String taskId) async {
  ref.watch(agentUpdateStreamProvider(taskId));
  final task = await ref.watch(journalDbProvider).journalEntityById(taskId);
  if (task is! Task || task.meta.deletedAt != null) return null;
  final reports = await ref
      .watch(agentRepositoryProvider)
      .getLatestTaskReportsForTaskIds([taskId]);
  final report = reports[taskId];
  return TaskPreview(
    task: task,
    oneLiner: _nonEmpty(report?.oneLiner),
    tldr: _nonEmpty(report?.tldr),
  );
}
