part of 'day_page.dart';

/// The block editor's actions beyond an edit: remove, link, unlink, create a
/// task. Each writes through the day agent, reloads the plan in place and
/// says what happened; a failure says so and changes nothing.
extension _DayPageBlockActions on _DayPageState {
  DayBlockEditActions _blockActionsFor(TimeBlock block) {
    final taskId = block.taskId?.trim();
    final linked = taskId != null && taskId.isNotEmpty;
    final calendar = block.type == TimeBlockType.cal;
    final taskable = !calendar && block.type != TimeBlockType.buffer;
    return DayBlockEditActions(
      onOpenTask: linked
          ? () => nav_service.beamToNamed('/tasks/$taskId')
          : null,
      onUnlinkTask: linked && taskable ? () => _unlinkBlock(block) : null,
      onLinkTask: !linked && taskable ? () => _linkBlock(block) : null,
      onCreateTask: !linked && taskable
          ? () => _createTaskForBlock(block)
          : null,
      onRemove: calendar ? null : () => _removeBlock(block),
    );
  }

  Future<void> _removeBlock(TimeBlock block) async {
    final done = await _runBlockAction(
      () => ref
          .read(dayAgentProvider)
          .removeBlock(plan: widget.draft, blockId: block.id),
    );
    if (!done || !mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.dailyOsNextBlockRemoved,
      action: ToastAction(
        label: context.messages.designSystemUndoLabel,
        onPressed: () async {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          await _runBlockAction(
            () => ref
                .read(dayAgentProvider)
                .restoreBlock(plan: widget.draft, blockId: block.id),
          );
        },
      ),
      countdown: true,
      replaceCurrent: true,
    );
  }

  Future<void> _linkBlock(TimeBlock block) async {
    final task = await ref.read(dayBlockTaskPickerProvider)(context);
    if (task == null || !mounted) return;
    final done = await _runBlockAction(
      () => ref
          .read(dayAgentProvider)
          .linkBlockToTask(
            plan: widget.draft,
            blockId: block.id,
            taskId: task.meta.id,
          ),
    );
    if (!done || !mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.dailyOsNextBlockLinked,
      replaceCurrent: true,
    );
  }

  Future<void> _unlinkBlock(TimeBlock block) async {
    final done = await _runBlockAction(
      () => ref
          .read(dayAgentProvider)
          .unlinkBlockFromTask(plan: widget.draft, blockId: block.id),
    );
    if (!done || !mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.dailyOsNextBlockUnlinked,
      replaceCurrent: true,
    );
  }

  Future<void> _createTaskForBlock(TimeBlock block) async {
    String? taskId;
    final done = await _runBlockAction(() async {
      final created = await ref
          .read(dayAgentProvider)
          .createTaskForBlock(plan: widget.draft, blockId: block.id);
      taskId = created.taskId;
    });
    if (!done || !mounted) return;
    final id = taskId;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: context.messages.dailyOsNextBlockTaskCreated,
      action: id == null
          ? null
          : ToastAction(
              label: context.messages.dailyOsNextBlockEditOpenTask,
              onPressed: () => nav_service.beamToNamed('/tasks/$id'),
            ),
      replaceCurrent: true,
    );
  }

  /// Runs [write], then reloads the plan. Returns false — after an error
  /// toast — when the write fails.
  Future<bool> _runBlockAction(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.dailyOsNextBlockEditFailed,
          replaceCurrent: true,
        );
      }
      return false;
    }
    ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
    return true;
  }
}
