import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Removes a task, returning `true` once it is gone.
typedef ProjectTaskRemover = Future<bool> Function(String taskId);

/// What a confirmed proposal changed, kept so it can be put back.
class _AppliedProposal {
  const _AppliedProposal({this.createdTaskId, this.previousStatus});

  final String? createdTaskId;
  final ProjectStatus? previousStatus;
}

/// Applies, rejects and undoes the project agent's proposed changes.
///
/// [confirm] and [reject] delegate to the change set confirmation service.
/// A confirmed proposal's effect is remembered for this session — the task a
/// `create_task` created, the status an `update_project_status` replaced —
/// so [undo] can put the project back before it reopens the proposal.
/// Rejections have no effect to revert, so their undo only reopens the
/// item. Nothing here is invalidated by hand: the confirmation service
/// persists through the agent sync service, whose update stream the pending
/// read watches.
class ProjectProposalService {
  ProjectProposalService({
    required this.confirmation,
    required this.projectRepository,
    required this.taskRemover,
    this.domainLogger,
  });

  final ChangeSetConfirmationService confirmation;
  final ProjectRepository projectRepository;
  final ProjectTaskRemover taskRemover;
  final DomainLogger? domainLogger;

  final _applied = <String, _AppliedProposal>{};

  static const _sub = 'ProjectProposal';

  static String _key(ChangeSetEntity changeSet, int itemIndex) =>
      '${changeSet.id}:$itemIndex';

  /// Confirms the item at [itemIndex], remembering what it changed.
  Future<ToolExecutionResult> confirm(
    ChangeSetEntity changeSet,
    int itemIndex,
  ) async {
    final item = changeSet.items[itemIndex];
    ProjectStatus? previousStatus;
    if (item.toolName == ProjectAgentToolNames.updateProjectStatus) {
      final project = await projectRepository.getProjectById(
        changeSet.taskId,
      );
      previousStatus = project?.data.status;
    }
    final result = await confirmation.confirmItem(changeSet, itemIndex);
    if (result.success) {
      _applied[_key(changeSet, itemIndex)] = _AppliedProposal(
        createdTaskId: item.toolName == ProjectAgentToolNames.createTask
            ? result.mutatedEntityId
            : null,
        previousStatus: previousStatus,
      );
    }
    return result;
  }

  /// Rejects the item at [itemIndex] without applying anything.
  Future<bool> reject(ChangeSetEntity changeSet, int itemIndex) =>
      confirmation.rejectItem(changeSet, itemIndex);

  /// Whether [undo] can still put the item at [itemIndex] back: always for a
  /// rejection, and for a confirmation only while this session remembers
  /// what it changed.
  bool canUndo(ChangeSetEntity changeSet, int itemIndex) =>
      switch (changeSet.items[itemIndex].status) {
        ChangeItemStatus.rejected => true,
        ChangeItemStatus.confirmed => _applied.containsKey(
          _key(changeSet, itemIndex),
        ),
        _ => false,
      };

  /// Reverts what confirming the item at [itemIndex] did — the created task
  /// is removed, the replaced status restored and its history entry dropped
  /// — then reopens the item. Returns `false`, leaving the item decided,
  /// when any step fails.
  Future<bool> undo(ChangeSetEntity changeSet, int itemIndex) async {
    final key = _key(changeSet, itemIndex);
    final applied = _applied[key];
    if (applied?.createdTaskId case final taskId?) {
      if (!await taskRemover(taskId)) {
        _log('Undo left task $taskId in place', changeSet);
        return false;
      }
    }
    if (applied?.previousStatus case final status?) {
      final project = await projectRepository.getProjectById(
        changeSet.taskId,
      );
      if (project == null) return false;
      final history = [...project.data.statusHistory];
      if (history.isNotEmpty && history.last == status) history.removeLast();
      final restored = await projectRepository.updateProject(
        project.copyWith(
          data: project.data.copyWith(status: status, statusHistory: history),
        ),
      );
      if (!restored) {
        _log('Undo could not restore the project status', changeSet);
        return false;
      }
    }
    final reopened = await confirmation.reopenItem(changeSet, itemIndex);
    if (reopened) _applied.remove(key);
    return reopened;
  }

  void _log(String message, ChangeSetEntity changeSet) {
    domainLogger?.log(
      LogDomain.agentWorkflow,
      '$message (change set ${DomainLogger.sanitizeId(changeSet.id)})',
      subDomain: _sub,
    );
  }
}
