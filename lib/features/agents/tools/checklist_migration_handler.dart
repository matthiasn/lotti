import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
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
    required ChecklistRepository checklistRepository,
    required JournalDb journalDb,
    DomainLogger? domainLogger,
  }) : _checklistRepository = checklistRepository,
       _journalDb = journalDb,
       _domainLogger = domainLogger;

  final ChecklistRepository _checklistRepository;
  final JournalDb _journalDb;
  final DomainLogger? _domainLogger;

  static const _sub = 'ChecklistMigrationHandler';

  /// Migrates a checklist item: archives in source, copies to target.
  ///
  /// [sourceTaskId] — the task that currently owns the item.
  /// [args] must contain `id` (item ID), `title`, and `targetTaskId`.
  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args,
  ) async {
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
      LogDomains.agentWorkflow,
      'Looking up target task: $targetTaskId',
      subDomain: _sub,
    );
    final targetTask = await _journalDb.journalEntityById(targetTaskId);
    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Target task lookup result: ${targetTask?.runtimeType} '
      '(id: ${targetTask?.meta.id})',
      subDomain: _sub,
    );
    if (targetTask is! Task) {
      _domainLogger?.error(
        LogDomains.agentWorkflow,
        'Target task $targetTaskId not found',
        subDomain: _sub,
      );
      return ToolExecutionResult(
        success: false,
        output: 'Error: target task $targetTaskId not found',
        errorMessage: 'Target task lookup failed',
      );
    }

    final targetChecklistIds = targetTask.data.checklistIds ?? [];
    String targetChecklistId;

    if (targetChecklistIds.isEmpty) {
      // Create a checklist on the target task directly — we bypass
      // AutoChecklistService because it rejects empty suggestions.
      final createResult = await _checklistRepository.createChecklist(
        taskId: targetTaskId,
      );
      if (createResult.checklist == null) {
        return const ToolExecutionResult(
          success: false,
          output: 'Error: failed to create checklist on target task',
          errorMessage: 'Target checklist creation failed',
        );
      }
      targetChecklistId = createResult.checklist!.meta.id;
    } else {
      targetChecklistId = targetChecklistIds.first;
    }

    // Copy the item to the target checklist BEFORE archiving the source,
    // so that a failed copy never leaves the source archived with no target.
    final newItem = await _checklistRepository.addItemToChecklist(
      checklistId: targetChecklistId,
      title: itemEntity.data.title,
      isChecked: itemEntity.data.isChecked,
      categoryId: targetTask.meta.categoryId,
    );

    if (newItem == null) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: failed to create item copy in target checklist',
        errorMessage: 'Item copy creation failed',
      );
    }

    // Archive the item in the source (after copy succeeded).
    // Return success even if archival fails — the copy exists and a retry
    // would create a duplicate. The source staying unarchived is a minor
    // inconsistency that beats duplicate target items.
    final archived = await _checklistRepository.updateChecklistItem(
      checklistItemId: itemId,
      data: itemEntity.data.copyWith(isArchived: true),
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
}
