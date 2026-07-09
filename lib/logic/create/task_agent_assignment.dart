import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';

/// Outcome of applying category-default Task Agent creation to a task.
enum TaskAgentAssignmentStatus {
  /// A Task Agent was created for the task.
  assigned,

  /// No assignment was attempted because the category has no default template
  /// or the task/category relationship was incomplete.
  skipped,

  /// Assignment was attempted but failed.
  failed,
}

/// Structured result returned by [assignCategoryDefaultTaskAgent].
class TaskAgentAssignmentResult {
  /// Creates a result.
  const TaskAgentAssignmentResult({
    required this.status,
    this.agent,
    this.error,
    this.stackTrace,
  });

  /// Assignment created [agent].
  const TaskAgentAssignmentResult.assigned(AgentIdentityEntity agent)
    : this(status: TaskAgentAssignmentStatus.assigned, agent: agent);

  /// Assignment was intentionally skipped.
  const TaskAgentAssignmentResult.skipped()
    : this(status: TaskAgentAssignmentStatus.skipped);

  /// Assignment failed with [error].
  const TaskAgentAssignmentResult.failed(Object error, StackTrace stackTrace)
    : this(
        status: TaskAgentAssignmentStatus.failed,
        error: error,
        stackTrace: stackTrace,
      );

  /// Assignment status.
  final TaskAgentAssignmentStatus status;

  /// Created Task Agent identity, when status is `assigned`.
  final AgentIdentityEntity? agent;

  /// Failure object, when status is `failed`.
  final Object? error;

  /// Failure stack, when status is `failed`.
  final StackTrace? stackTrace;

  /// Whether a Task Agent was created.
  bool get assigned => status == TaskAgentAssignmentStatus.assigned;
}

/// Creates the category's default Task Agent for [task], when configured.
///
/// This is the shared default-assignment path used by manual task creation and
/// Daily OS capture-created tasks. Failures are captured in the returned result
/// so callers can decide whether and how to report them without duplicating the
/// task/category/template checks.
Future<TaskAgentAssignmentResult> assignCategoryDefaultTaskAgent({
  required TaskAgentService service,
  required Task task,
  required CategoryDefinition? category,
  bool awaitContent = true,
}) async {
  final categoryId = task.meta.categoryId;
  final templateId = category?.defaultTemplateId;
  if (category == null || categoryId == null || templateId == null) {
    return const TaskAgentAssignmentResult.skipped();
  }

  try {
    final agent = await service.createTaskAgent(
      taskId: task.meta.id,
      templateId: templateId,
      profileId: category.defaultProfileId,
      allowedCategoryIds: {categoryId},
      awaitContent: awaitContent,
    );
    return TaskAgentAssignmentResult.assigned(agent);
  } catch (e, s) {
    return TaskAgentAssignmentResult.failed(e, s);
  }
}
