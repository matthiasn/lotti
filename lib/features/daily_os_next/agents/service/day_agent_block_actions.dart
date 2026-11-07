import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';

/// The user's own actions on one planned block, from the Day surface's block
/// editor: take it off the plan (and put it back, for Undo), tie it to a
/// task, untie it, or turn it into a new task.
///
/// Each is one sync write of the day plan, like the editor's time, title and
/// category edits (`DayAgentPlanEditor.editBlock`), and each keeps the same
/// ownership rules: imported calendar blocks belong to their calendar and are
/// never changed here, buffers are spacing and carry no task, and a
/// task-linked block takes its title from the task.
///
/// Every refusal throws [DayAgentCaptureException].
class DayAgentBlockActions {
  DayAgentBlockActions({
    required this.syncService,
    required this.journalDb,
    required this.reads,
    DayAgentTaskFactory? taskFactory,
    this.onPersistedStateChanged,
  }) : _taskFactory = taskFactory ?? defaultDayAgentTaskFactory;

  final AgentSyncService syncService;
  final JournalDb journalDb;
  final DayAgentPlanReads reads;
  final DayAgentTaskFactory _taskFactory;

  /// Fired with the agent, day and plan ids after every write.
  final void Function(String id)? onPersistedStateChanged;

  /// Takes the block off the plan — the same removal an accepted "drop"
  /// change makes — and returns the plan with the block that left it, which
  /// is what [restoreBlock] needs to undo it.
  Future<({DayPlanEntity plan, PlannedBlock removed})> removeBlock({
    required String agentId,
    required String dayId,
    required String blockId,
  }) => syncService.runInTransaction(() async {
    final (:plan, :block, identity: _) = await _load(
      agentId: agentId,
      dayId: dayId,
      blockId: blockId,
    );
    if (block.type == PlannedBlockType.cal) {
      throw DayAgentCaptureException(
        'block $blockId is calendar-owned — remove it in the source calendar',
      );
    }
    final remaining = [
      for (final candidate in plan.data.plannedBlocks)
        if (candidate.id != blockId) candidate,
    ];
    final saved = await _save(
      agentId: agentId,
      dayId: dayId,
      plan: plan,
      blocks: remaining,
    );
    return (plan: saved, removed: block);
  });

  /// Puts [block] back on the plan, where its own times place it. A block
  /// already on the plan (a repeated Undo, or one restored elsewhere and
  /// synced) leaves the plan as it is.
  Future<DayPlanEntity> restoreBlock({
    required String agentId,
    required String dayId,
    required PlannedBlock block,
  }) => syncService.runInTransaction(() async {
    await reads.requireIdentity(agentId);
    final plan = await _requirePlan(agentId: agentId, dayId: dayId);
    if (plan.data.plannedBlocks.any((candidate) => candidate.id == block.id)) {
      return plan;
    }
    return _save(
      agentId: agentId,
      dayId: dayId,
      plan: plan,
      blocks: [...plan.data.plannedBlocks, block],
    );
  });

  /// Ties the block to the task [taskId]. The task becomes the source of the
  /// block's title, and of its category when that category may be planned
  /// with; otherwise the block keeps its own.
  Future<DayPlanEntity> linkTask({
    required String agentId,
    required String dayId,
    required String blockId,
    required String taskId,
  }) async {
    final (plan: _, :block, identity: _) = await _load(
      agentId: agentId,
      dayId: dayId,
      blockId: blockId,
    );
    _requireTaskable(block);
    final entity = await journalDb.journalEntityById(taskId);
    if (entity is! Task || entity.meta.deletedAt != null) {
      throw DayAgentCaptureException('no task $taskId');
    }
    return _link(
      agentId: agentId,
      dayId: dayId,
      blockId: blockId,
      task: entity,
    );
  }

  /// Unties a task-linked block. It keeps the task's title as its own, so
  /// the timeline reads the same until it is renamed; the share of the task
  /// it left unscheduled (`remainingMinutes`) goes with the task.
  Future<DayPlanEntity> unlinkTask({
    required String agentId,
    required String dayId,
    required String blockId,
  }) => syncService.runInTransaction(() async {
    final (:plan, :block, identity: _) = await _load(
      agentId: agentId,
      dayId: dayId,
      blockId: blockId,
    );
    if (!_isLinked(block)) {
      throw DayAgentCaptureException('block $blockId has no task');
    }
    return _save(
      agentId: agentId,
      dayId: dayId,
      plan: plan,
      blocks: _replace(
        plan,
        block.copyWith(taskId: null, remainingMinutes: null),
      ),
    );
  });

  /// Turns a standalone block into a new open task — named after the block,
  /// in its category, estimated at its length — and ties the block to it.
  ///
  /// The task is created first, outside the plan write; the block is then
  /// linked on the plan as it is by then. Should that link fail, the task
  /// already exists, so this throws [DayAgentTaskNotLinkedException] with its
  /// id rather than leaving it unaccounted for — the caller can point to it,
  /// and a retry links it instead of creating another.
  Future<({DayPlanEntity plan, Task task})> createTaskForBlock({
    required String agentId,
    required String dayId,
    required String blockId,
  }) async {
    final (plan: _, :block, identity: _) = await _load(
      agentId: agentId,
      dayId: dayId,
      blockId: blockId,
    );
    _requireTaskable(block);
    if (_isLinked(block)) {
      throw DayAgentCaptureException('block $blockId already has a task');
    }
    final title = block.title?.trim() ?? '';
    if (title.isEmpty) {
      throw DayAgentCaptureException(
        'block $blockId has no title to name a task after',
      );
    }
    final task = await _taskFactory(
      title: title,
      categoryId: block.categoryId,
      now: clock.now(),
      estimateMinutes: block.duration.inMinutes,
    );
    if (task == null) {
      throw DayAgentCaptureException('could not create a task for $blockId');
    }
    try {
      final saved = await _link(
        agentId: agentId,
        dayId: dayId,
        blockId: blockId,
        task: task,
        requireUnlinked: true,
      );
      return (plan: saved, task: task);
    } on Object catch (error) {
      throw DayAgentTaskNotLinkedException(
        taskId: task.meta.id,
        blockId: blockId,
        cause: error,
      );
    }
  }

  /// Links [task] to the block on the plan as it is now, read and written in
  /// one transaction so a concurrent change to the plan is not overwritten.
  /// The unscheduled remainder survives only a re-link to the same task.
  Future<DayPlanEntity> _link({
    required String agentId,
    required String dayId,
    required String blockId,
    required Task task,
    bool requireUnlinked = false,
  }) => syncService.runInTransaction(() async {
    final (:plan, :block, :identity) = await _load(
      agentId: agentId,
      dayId: dayId,
      blockId: blockId,
    );
    _requireTaskable(block);
    if (requireUnlinked && _isLinked(block)) {
      throw DayAgentCaptureException('block $blockId already has a task');
    }
    final taskCategoryId = task.meta.categoryId;
    final categoryId =
        taskCategoryId != null &&
            await _categoryPlannable(taskCategoryId, identity)
        ? taskCategoryId
        : block.categoryId;
    final title = task.data.title.trim();
    final sameTask = block.taskId == task.meta.id;
    return _save(
      agentId: agentId,
      dayId: dayId,
      plan: plan,
      blocks: _replace(
        plan,
        block.copyWith(
          taskId: task.meta.id,
          title: title.isEmpty ? block.title : title,
          categoryId: categoryId,
          remainingMinutes: sameTask ? block.remainingMinutes : null,
        ),
      ),
    );
  });

  Future<bool> _categoryPlannable(
    String categoryId,
    AgentIdentityEntity identity,
  ) async {
    if (!categoryAllowed(categoryId, identity.allowedCategoryIds)) {
      return false;
    }
    final category = await journalDb.getCategoryById(categoryId);
    return category != null &&
        category.deletedAt == null &&
        category.active &&
        (category.isAvailableForDayPlan ?? false);
  }

  void _requireTaskable(PlannedBlock block) {
    switch (block.type) {
      case PlannedBlockType.cal:
        throw DayAgentCaptureException(
          'block ${block.id} is calendar-owned — it cannot carry a task',
        );
      case PlannedBlockType.buffer:
        throw DayAgentCaptureException(
          'block ${block.id} is a buffer — it cannot carry a task',
        );
      case PlannedBlockType.ai:
      case PlannedBlockType.manual:
        return;
    }
  }

  static bool _isLinked(PlannedBlock block) =>
      block.taskId?.trim().isNotEmpty ?? false;

  static List<PlannedBlock> _replace(DayPlanEntity plan, PlannedBlock block) =>
      [
        for (final candidate in plan.data.plannedBlocks)
          if (candidate.id == block.id) block else candidate,
      ];

  Future<
    ({DayPlanEntity plan, PlannedBlock block, AgentIdentityEntity identity})
  >
  _load({
    required String agentId,
    required String dayId,
    required String blockId,
  }) async {
    final identity = await reads.requireIdentity(agentId);
    final plan = await _requirePlan(agentId: agentId, dayId: dayId);
    final block = plan.data.plannedBlocks
        .where((candidate) => candidate.id == blockId)
        .firstOrNull;
    if (block == null) {
      throw DayAgentCaptureException(
        'no block $blockId on the plan for $dayId',
      );
    }
    return (plan: plan, block: block, identity: identity);
  }

  Future<DayPlanEntity> _requirePlan({
    required String agentId,
    required String dayId,
  }) async {
    final plan = await reads.draftPlanForDay(agentId: agentId, dayId: dayId);
    if (plan == null) {
      throw DayAgentCaptureException(
        'no plan for $dayId; call draft_day_plan first',
      );
    }
    return plan;
  }

  Future<DayPlanEntity> _save({
    required String agentId,
    required String dayId,
    required DayPlanEntity plan,
    required List<PlannedBlock> blocks,
  }) async {
    final sorted = [...blocks]
      ..sort((a, b) {
        final byStart = a.startTime.compareTo(b.startTime);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });
    final saved = plan.copyWith(
      data: plan.data.copyWith(plannedBlocks: sorted),
      scheduledMinutes: scheduledMinutesFor(sorted),
      updatedAt: clock.now(),
    );
    await syncService.upsertEntity(saved);
    onPersistedStateChanged
      ?..call(agentId)
      ..call(dayId)
      ..call(saved.id);
    return saved;
  }
}

/// A task was created for a planned block, but the block could not be linked
/// to it. The task exists — [taskId] — so a caller can say so and point to it
/// instead of creating another on retry.
class DayAgentTaskNotLinkedException implements Exception {
  const DayAgentTaskNotLinkedException({
    required this.taskId,
    required this.blockId,
    required this.cause,
  });

  final String taskId;
  final String blockId;

  /// Why the link failed.
  final Object cause;

  @override
  String toString() =>
      'task $taskId was created but block $blockId could not be linked: '
      '$cause';
}
