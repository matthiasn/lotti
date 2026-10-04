import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_tool_dispatcher.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Removes a task, returning `true` once it is gone.
typedef ProjectTaskRemover = Future<bool> Function(String taskId);

/// What a confirmed proposal changed, kept so it can be put back.
class _AppliedProposal {
  const _AppliedProposal({
    required this.effectKey,
    this.createdTaskId,
    this.previousStatus,
  });

  /// The effect key the confirmation applied the item under
  /// (`ChangeItemEffect.effectKeyIn`): the Undo puts back only this
  /// decision, not a later one synced from another device (ADR 0097).
  final String effectKey;
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
    // The key the item was claimed under, read from the persisted set: the
    // caller's snapshot may predate an Undo on another device that rekeyed
    // it.
    String? claimedKey;
    final result = await confirmation.confirmItem(
      changeSet,
      itemIndex,
      onClaimed: (key) => claimedKey = key,
    );
    if (result.success && claimedKey != null) {
      _applied[_key(changeSet, itemIndex)] = _AppliedProposal(
        effectKey: claimedKey!,
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
  /// what it changed — and the item still shows that confirmation, not a
  /// later one synced from another device.
  bool canUndo(ChangeSetEntity changeSet, int itemIndex) {
    final item = changeSet.items[itemIndex];
    return switch (item.status) {
      ChangeItemStatus.rejected => true,
      ChangeItemStatus.confirmed =>
        _applied[_key(changeSet, itemIndex)]?.effectKey ==
            item.effectKeyIn(changeSet.id, itemIndex),
      _ => false,
    };
  }

  /// Reverts what confirming the item at [itemIndex] did — the created task
  /// is removed, or the replaced status restored and its history entry
  /// dropped — and then reopens it. The item stays confirmed while the
  /// revert runs, so it cannot be confirmed again beside the effect being
  /// taken back (see [ChangeSetConfirmationService.reopenItem]). A refused
  /// revert changes nothing and returns `false`, leaving the memo for
  /// another try. So does a reopen that fails after the revert: the revert
  /// is idempotent — a task already removed reports removed, a status
  /// already restored needs no restore — so the retry reopens the item.
  Future<bool> undo(ChangeSetEntity changeSet, int itemIndex) async {
    final key = _key(changeSet, itemIndex);
    final applied = _applied[key];
    final reopened = await confirmation.reopenItem(
      changeSet,
      itemIndex,
      revert: applied == null
          ? null
          : () => _revert(applied, changeSet, itemIndex),
      effectKey: applied?.effectKey,
    );
    if (reopened) _applied.remove(key);
    return reopened;
  }

  Future<bool> _revert(
    _AppliedProposal applied,
    ChangeSetEntity changeSet,
    int itemIndex,
  ) async {
    if (applied.createdTaskId case final taskId?) {
      if (!await taskRemover(taskId)) {
        _log('Undo left task $taskId in place', changeSet);
        return false;
      }
    }
    if (applied.previousStatus case final previous?) {
      return _restoreStatus(previous, changeSet, itemIndex);
    }
    return true;
  }

  /// Restores [previous] only when the project still looks the way the
  /// confirmed tool left it: its status is the proposal's target and the
  /// newest history entry is [previous]. A status that moved on since — sync,
  /// another editor — is left alone, and the undo is refused rather than
  /// overwriting it with stale data. A tool that found the project already
  /// in its target status changed nothing, so there is nothing to restore.
  Future<bool> _restoreStatus(
    ProjectStatus previous,
    ChangeSetEntity changeSet,
    int itemIndex,
  ) async {
    final project = await projectRepository.getProjectById(changeSet.taskId);
    if (project == null) {
      _log('Undo found no project to restore', changeSet);
      return false;
    }
    final data = project.data;
    if (ProjectToolDispatcher.isSameSemanticStatus(data.status, previous)) {
      return true;
    }
    final args = changeSet.items[itemIndex].args;
    final target = switch (args['status']) {
      final String raw => ProjectToolDispatcher.parseProjectStatus(
        raw,
        reason: args['reason'] as String?,
        now: clock.now(),
      ),
      _ => null,
    };
    final history = [...data.statusHistory];
    final untouched =
        target != null &&
        ProjectToolDispatcher.isSameSemanticStatus(data.status, target) &&
        history.isNotEmpty &&
        history.last == previous;
    if (!untouched) {
      _log('Undo left the project status alone: it moved since', changeSet);
      return false;
    }
    history.removeLast();
    final restored = await projectRepository.updateProject(
      project.copyWith(
        data: data.copyWith(status: previous, statusHistory: history),
      ),
    );
    if (!restored) _log('Undo could not restore the project status', changeSet);
    return restored;
  }

  void _log(String message, ChangeSetEntity changeSet) {
    domainLogger?.log(
      LogDomain.agentWorkflow,
      '$message (change set ${DomainLogger.sanitizeId(changeSet.id)})',
      subDomain: _sub,
    );
  }
}
