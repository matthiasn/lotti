import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Migrates a single checklist item from a source task to a target task.
///
/// The item is archived in the source task's checklist and a copy is created
/// in the target task's checklist (preserving title and checked state).
///
/// If the target task does not yet have a checklist, one is created
/// automatically via [ChecklistRepository.createChecklist].
class ChecklistMigrationHandler {
  ChecklistMigrationHandler({
    required this._checklistRepository,
    required this._journalDb,
    this._domainLogger,
    this.approval,
  });

  final ChecklistRepository _checklistRepository;
  final ChecklistItemProvenance? approval;
  final JournalDb _journalDb;
  final DomainLogger? _domainLogger;

  static const _sub = 'ChecklistMigrationHandler';

  /// Migrates a checklist item: archives in source, copies to target.
  ///
  /// [sourceTaskId] — the task that currently owns the item.
  /// [args] must contain `id` (item ID), `title`, and `targetTaskId`.
  ///
  /// With an [effect] — a confirmed change item — the copy, and the target's
  /// checklist when it has none, get ids derived from the item, so the same
  /// migration confirmed on two devices before they sync copies the item
  /// once: a copy already there (written here, synced from the other device,
  /// or deleted since) is not written again, and the source is archived.
  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args, {
    ChangeEffect? effect,
  }) async {
    final itemId = args['id'];
    if (itemId is! String || itemId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "id" must be a non-empty string',
        errorMessage: 'Missing checklist item ID',
      );
    }

    final targetTaskId = args['targetTaskId'];
    if (targetTaskId is! String || targetTaskId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "targetTaskId" must be a non-empty string',
        errorMessage: 'Missing target task ID',
      );
    }

    // Look up the checklist item.
    final itemEntity = await _journalDb.journalEntityById(itemId);
    if (itemEntity is! ChecklistItem) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: checklist item $itemId not found',
        errorMessage: 'Checklist item lookup failed',
      );
    }

    // Reject already-archived items to stay idempotent on replay.
    if (itemEntity.data.isArchived) {
      return ToolExecutionResult(
        success: true,
        output:
            'Item "${itemEntity.data.title}" is already archived — '
            'skipping migration',
      );
    }

    // Verify the item belongs to the source task's checklist.
    final sourceTask = await _journalDb.journalEntityById(sourceTaskId);
    if (sourceTask is! Task) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: source task $sourceTaskId not found',
        errorMessage: 'Source task lookup failed',
      );
    }

    final sourceChecklistIds = sourceTask.data.checklistIds ?? [];
    final itemBelongsToSource = itemEntity.data.linkedChecklists.any(
      sourceChecklistIds.contains,
    );
    if (!itemBelongsToSource) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: item $itemId does not belong to source task $sourceTaskId',
        errorMessage: 'Item does not belong to source task',
      );
    }

    // Validate the target task and resolve its checklist BEFORE archiving the
    // source item, so we never leave an item archived without a valid target.
    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Looking up target task: ${DomainLogger.sanitizeId(targetTaskId)}',
      subDomain: _sub,
    );
    final targetTask = await _journalDb.journalEntityById(targetTaskId);
    _domainLogger?.log(
      LogDomain.agentWorkflow,
      'Target task lookup result: ${targetTask?.runtimeType} '
      '(id: ${targetTask != null ? DomainLogger.sanitizeId(targetTask.meta.id) : 'none'})',
      subDomain: _sub,
    );
    if (targetTask is! Task) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        'Target task ${DomainLogger.sanitizeId(targetTaskId)} not found',
        subDomain: _sub,
      );
      return ToolExecutionResult(
        success: false,
        output: 'Error: target task $targetTaskId not found',
        errorMessage: 'Target task lookup failed',
      );
    }

    // Copy the item to the target checklist BEFORE archiving the source,
    // so that a failed copy never leaves the source archived with no target.
    if (effect == null || !await effect.created(_journalDb, _copyRole)) {
      final copyFailure = await _copyToTarget(
        itemEntity,
        targetTask,
        effect,
      );
      if (copyFailure != null) return copyFailure;
    }

    // Archive the item in the source (after copy succeeded).
    // Return success even if archival fails — the copy exists and a retry
    // would create a duplicate. The source staying unarchived is a minor
    // inconsistency that beats duplicate target items.
    final archived = await _checklistRepository.updateChecklistItem(
      checklistItemId: itemId,
      data: itemEntity.data.copyWith(
        isArchived: true,
        approvalHistory: [
          ...itemEntity.data.approvalHistory,
          if (approval case final receipt?)
            receipt.copyWith(isChecked: null, isArchived: true),
        ],
      ),
      taskId: sourceTaskId,
    );

    final warning = archived ? '' : '. Warning: source item was not archived';

    return ToolExecutionResult(
      success: true,
      output:
          'Migrated "${itemEntity.data.title}" from task $sourceTaskId '
          'to $targetTaskId$warning',
      mutatedEntityId: targetTaskId,
      errorMessage: archived ? null : 'Source item archival failed',
    );
  }

  /// The roles of the copy and of the target's new checklist in their
  /// [ChangeEffect]'s derived ids.
  static const _copyRole = 'checklist-item';
  static const _checklistRole = 'checklist';

  /// Copies [item] into the first checklist of [targetTask] — creating one
  /// when it has none — under the ids derived from [effect], if any.
  /// Returns the failure to report, or `null` once the copy exists.
  Future<ToolExecutionResult?> _copyToTarget(
    ChecklistItem item,
    Task targetTask,
    ChangeEffect? effect,
  ) async {
    final targetChecklistIds = targetTask.data.checklistIds ?? [];
    String targetChecklistId;

    if (targetChecklistIds.isEmpty) {
      // Create a checklist on the target task directly — we bypass
      // AutoChecklistService because it rejects empty suggestions. With an
      // effect, the derived checklist — reused when another device's copy has
      // arrived before the task update listing it.
      final created = effect == null
          ? (await _checklistRepository.createChecklist(
              taskId: targetTask.meta.id,
            )).checklist?.meta.id
          : await _checklistRepository.derivedChecklistFor(
              taskId: targetTask.meta.id,
              uuidV5Input: effect.entityInput(_checklistRole),
            );
      if (created == null) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: failed to create checklist on target task',
          errorMessage: 'Target checklist creation failed',
        );
      }
      targetChecklistId = created;
    } else {
      targetChecklistId = targetChecklistIds.first;
    }

    final newItem = await _checklistRepository.addItemToChecklist(
      checklistId: targetChecklistId,
      title: item.data.title,
      isChecked: item.data.isChecked,
      categoryId: targetTask.meta.categoryId,
      checkedBy: approval == null ? item.data.checkedBy : ChangeSource.user,
      checkedAt: approval?.approvedAt ?? item.data.checkedAt,
      approvalHistory: [
        ...item.data.approvalHistory,
        if (approval case final receipt?)
          receipt.copyWith(isChecked: item.data.isChecked),
      ],
      uuidV5Input: effect?.entityInput(_copyRole),
    );

    if (newItem == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to create item copy in target checklist',
        errorMessage: 'Item copy creation failed',
      );
    }
    return null;
  }
}
