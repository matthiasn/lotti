import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';

/// Snapshot of task metadata used for redundancy checks.
///
/// Each field is nullable: `null` means the current value is unknown or unset.
typedef TaskMetadataSnapshot = ({
  String? title,
  String? status,
  String? priority,
  int? estimateMinutes,
  String? dueDate,
});

/// Callback that resolves the current metadata of the task being operated on.
///
/// Returns `null` if the task cannot be found.
typedef ResolveTaskMetadata = Future<TaskMetadataSnapshot?> Function();

/// Filters redundant change proposals so that the LLM receives feedback
/// instead of the user seeing no-op suggestions.
///
/// Two categories of redundancy are handled:
///
/// 1. **Batch tools** (checklist updates): detected inside [ChangeSetBuilder]
///    and reported via [BatchAddResult.redundant]. This class formats the
///    response via [formatBatchResponse].
///
/// 2. **Non-batch deferred tools** (priority, estimate, due date, status,
///    title): detected by comparing the proposed value against the current
///    task metadata via [checkTaskMetadataRedundancy].
class ChangeProposalFilter {
  const ChangeProposalFilter._();

  /// Build a [TaskMetadataSnapshot] from a [JournalDb] lookup.
  ///
  /// Returns `null` if the entity is not a [Task].
  ///
  /// **String coupling:** The `status` and `priority` fields use
  /// `TaskStatus.toDbString` and `TaskPriority.short` respectively. These
  /// must match the string values the LLM sends as tool arguments (e.g.
  /// `"OPEN"`, `"P1"`). If those representations ever diverge, redundancy
  /// checks will silently become no-ops (never match).
  static Future<TaskMetadataSnapshot?> resolveTaskMetadata(
    JournalDb journalDb,
    String taskId,
  ) async {
    final entity = await journalDb.journalEntityById(taskId);
    if (entity is! Task) return null;
    final data = entity.data;
    return (
      title: data.title,
      status: data.status.toDbString,
      priority: data.priority.short,
      estimateMinutes: data.estimate?.inMinutes,
      dueDate: formatIsoDate(data.due),
    );
  }

  /// Format the LLM response for a batch tool call result.
  ///
  /// Includes information about queued, skipped, and redundant items so the
  /// LLM can adjust its context.
  static String formatBatchResponse(BatchAddResult result) {
    final parts = <String>[];

    if (result.added > 0 || (result.skipped == 0 && result.redundant == 0)) {
      parts.add(
        'Proposal queued for user review '
        '(${result.added} item(s) queued).',
      );
    }

    if (result.skipped > 0) {
      parts.add('${result.skipped} malformed item(s) skipped.');
    }

    if (result.redundant > 0) {
      final details = result.redundantDetails.join('; ');
      parts.add(
        'Skipped ${result.redundant} redundant update(s): $details.',
      );
    }

    return parts.join('\n');
  }

  /// Check whether a non-batch deferred tool proposal is redundant against
  /// the current task metadata.
  ///
  /// Returns a feedback message for the LLM if the proposal is redundant,
  /// or `null` if the proposal should be kept.
  static String? checkTaskMetadataRedundancy(
    String toolName,
    Map<String, dynamic> args,
    TaskMetadataSnapshot snapshot,
  ) {
    switch (toolName) {
      case TaskAgentToolNames.updateTaskEstimate:
        final minutes = args['minutes'];
        if (minutes is int && snapshot.estimateMinutes == minutes) {
          return 'Skipped: estimate is already $minutes minutes.';
        }
      case TaskAgentToolNames.updateTaskPriority:
        final priority = args['priority'];
        if (priority is String && snapshot.priority == priority) {
          return 'Skipped: priority is already $priority.';
        }
      case TaskAgentToolNames.updateTaskDueDate:
        final dueDate = args['dueDate'];
        if (dueDate is String && snapshot.dueDate == dueDate) {
          return 'Skipped: due date is already $dueDate.';
        }
      case TaskAgentToolNames.setTaskStatus:
        final status = args['status'];
        if (status is String && snapshot.status == status) {
          return 'Skipped: status is already $status.';
        }
      case TaskAgentToolNames.setTaskTitle:
        final title = args['title'];
        if (title is String && snapshot.title == title) {
          return 'Skipped: title is already "$title".';
        }
    }
    return null;
  }
}
