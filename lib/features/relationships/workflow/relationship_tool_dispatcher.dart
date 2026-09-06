import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_contract.dart';
import 'package:lotti/logic/create/task_agent_assignment.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:uuid/uuid.dart';

/// The exact creation snapshot, before any asynchronous follow-up can edit it.
class RelationshipTaskCreationResult extends ToolExecutionResult {
  RelationshipTaskCreationResult(this.task)
    : super(
        success: true,
        output: 'Created and linked task',
        mutatedEntityId: task.id,
      );

  final Task task;
}

/// Applies user-confirmed relationship proposals. Evidence and consent are
/// checked again at apply time; the model never writes journal entities.
class RelationshipToolDispatcher {
  RelationshipToolDispatcher({
    required this.relationshipRepository,
    required this.persistenceLogic,
    required this.entitiesCacheService,
    required this.taskAgentService,
    required this.journalDb,
  });

  final RelationshipRepository relationshipRepository;
  final PersistenceLogic persistenceLogic;
  final EntitiesCacheService entitiesCacheService;
  final TaskAgentService taskAgentService;
  final JournalDb journalDb;

  Future<ToolExecutionResult> dispatch(
    String toolName,
    Map<String, dynamic> args,
    String relationshipId,
  ) async {
    if (toolName != RelationshipAgentToolNames.createAndLinkTask) {
      return _failure('Unknown relationship tool', permanent: true);
    }
    final invalid = relationshipTaskProposalError(args);
    if (invalid != null) return _failure(invalid, permanent: true);
    final person = await relationshipRepository.getRelationshipById(
      relationshipId,
    );
    if (person == null ||
        person.isDeleted ||
        !person.data.important ||
        person.data.status is! RelationshipActive) {
      return _failure('Relationship is no longer eligible', permanent: true);
    }
    final evidence = (await relationshipRepository.getCheckInsForRelationship(
      relationshipId,
    )).where((entry) => entry.id == args['sourceCheckInId']).firstOrNull;
    if (evidence == null ||
        evidence.isDeleted ||
        evidence.data.relationshipId != relationshipId) {
      return _failure(
        'Source check-in is no longer available',
        permanent: true,
      );
    }
    final quote = (args['description'] as String).trim();
    final narrative = evidence.entryText?.plainText ?? '';
    if (!narrative.contains(quote)) {
      return _failure(
        'The quoted commitment is no longer in the source check-in',
        permanent: true,
      );
    }
    // One journal identity per evidence-backed commitment, independent of
    // device-local creation timestamps or status UUIDs. Retrying or syncing
    // concurrent confirmations cannot produce a second task row.
    final taskId = const Uuid().v5(
      Namespace.nil.value,
      jsonEncode([
        'relationship-task',
        relationshipId,
        args['sourceCheckInId'],
        (args['title'] as String).trim(),
        quote,
      ]),
    );
    final existing = await journalDb.journalEntityById(taskId);
    if (existing != null && !existing.isDeleted) {
      if (existing is! Task) {
        return _failure('Task identity is unavailable', permanent: true);
      }
      final linked = await _tryLinkTask(taskId, relationshipId);
      // Do not mint an undo receipt from a task a peer may already have edited.
      return (linked || await _hasRelationshipLink(taskId, relationshipId))
          ? ToolExecutionResult(
              success: true,
              output: 'Task already exists',
              mutatedEntityId: taskId,
            )
          : _failure('Existing task linking failed');
    }
    final now = clock.now();
    final categoryId = person.meta.categoryId;
    final category = categoryId == null
        ? null
        : entitiesCacheService.getCategoryById(categoryId);
    final description = args['description'] as String;
    final evidenceUrl = 'lotti://journal/${evidence.id}';
    final data = TaskData(
      title: (args['title'] as String).trim(),
      status: TaskStatus.open(
        id: const Uuid().v4(),
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      profileId: category?.defaultProfileId,
      due: args['dueDate'] == null
          ? null
          : DateTime.parse(args['dueDate'] as String),
    );
    final entryText = EntryText(
      plainText: '$description\n\nlotti://journal/${evidence.id}',
      markdown: '$description\n\n[$evidenceUrl]($evidenceUrl)',
    );
    final private =
        person.meta.private == true || evidence.meta.private == true;
    final Task? task;
    if (existing is Task && existing.isDeleted) {
      // Undo retains a tombstone. A new confirmation restores the same identity
      // with a clock descended from that tombstone, so peers accept the restore.
      final restored = Task(
        meta: await persistenceLogic.updateMetadata(
          existing.meta.copyWith(
            deletedAt: null,
            categoryId: categoryId,
            private: private,
          ),
          dateFrom: now,
          dateTo: now,
        ),
        data: data,
        entryText: entryText,
      );
      task = await persistenceLogic.updateDbEntity(restored) == true
          ? restored
          : null;
    } else {
      task = await persistenceLogic.createTaskEntry(
        id: taskId,
        data: data,
        entryText: entryText,
        categoryId: categoryId,
        private: private,
      );
    }
    if (task == null) return _failure('Task creation failed');
    var linked = false;
    var alreadyLinked = false;
    try {
      // A deleted person must not gain a task while an async create was running.
      final current = await relationshipRepository.getRelationshipById(
        relationshipId,
      );
      if (current != null &&
          !current.isDeleted &&
          current.data.important &&
          current.data.status is RelationshipActive &&
          current.meta.categoryId == categoryId &&
          current.meta.private == person.meta.private) {
        linked = await _tryLinkTask(task.id, relationshipId);
        if (!linked) {
          alreadyLinked = await _hasRelationshipLink(task.id, relationshipId);
          linked = alreadyLinked;
        }
      }
    } catch (_) {
      // If validation or reconciliation fails, compensation is still guarded.
    }
    if (!linked) {
      final rolledBack = await removeTask(task);
      return _failure(
        rolledBack
            ? 'Task linking failed; creation rolled back'
            : 'Task linking failed and rollback failed',
        permanent: !rolledBack,
      );
    }
    if (alreadyLinked) {
      // The peer's confirmation owns this task. Do not issue a local undo receipt.
      return ToolExecutionResult(
        success: true,
        output: 'Task already exists',
        mutatedEntityId: task.id,
      );
    }
    final assignment = await assignCategoryDefaultTaskAgent(
      service: taskAgentService,
      task: task,
      category: category,
    );
    if (assignment.status == TaskAgentAssignmentStatus.failed) {
      developer.log(
        'Could not assign category agent to relationship task',
        name: 'RelationshipToolDispatcher',
        error: assignment.error,
        stackTrace: assignment.stackTrace,
      );
    }
    return RelationshipTaskCreationResult(task);
  }

  /// A link may commit before post-write work throws. Both callers reconcile
  /// the stored link after a false result, without issuing another undo receipt.
  Future<bool> _tryLinkTask(String taskId, String personId) async {
    try {
      return await relationshipRepository.linkTask(
        relationshipId: personId,
        taskId: taskId,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasRelationshipLink(String taskId, String personId) async {
    final links = await journalDb.linksForEntryIdsBidirectional({taskId});
    return links.any(
      (link) =>
          link.deletedAt == null &&
          link.hidden != true &&
          _isPersonLink(link, taskId, personId),
    );
  }

  static bool _isPersonLink(EntryLink link, String taskId, String? personId) =>
      link is RelationshipLink &&
      ((link.fromId == personId && link.toId == taskId) ||
          (link.fromId == taskId && link.toId == personId));

  /// Tombstones only the unchanged snapshot, checking links in the journal write
  /// transaction. Compensation permits no live links; undo may retain only the
  /// originating person's relationship links until its subsequent cleanup.
  Future<bool> removeTask(Task task, {String? allowedRelationshipId}) async {
    try {
      final meta = await persistenceLogic.updateMetadata(
        task.meta,
        deletedAt: clock.now(),
      );
      return await persistenceLogic.updateDbEntity(
            task.copyWith(meta: meta),
            precondition: () async {
              // The public lookup coalesces callers across transaction zones.
              // Read directly so this snapshot belongs to the write transaction.
              final current = await journalDb.entityById(task.id);
              if (task.isDeleted ||
                  current == null ||
                  fromDbEntity(current) != task) {
                return false;
              }
              final links = await journalDb.linksForEntryIdsBidirectional({
                task.id,
              });
              return !links.any(
                (link) =>
                    link.deletedAt == null &&
                    !_isPersonLink(link, task.id, allowedRelationshipId),
              );
            },
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  ToolExecutionResult _failure(String reason, {bool permanent = false}) =>
      ToolExecutionResult(
        success: false,
        output: reason,
        errorMessage: reason,
        nonRetryable: permanent,
      );
}
