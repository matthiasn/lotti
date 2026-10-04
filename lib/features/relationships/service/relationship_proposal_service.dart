import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/workflow/relationship_tool_dispatcher.dart';

/// Confirms proposals and remembers their task receipts on the decision row.
/// The immutable proposal args stay unchanged, preserving ledger fingerprints.
/// Receipts make the handled row's destination available after a restart/sync.
class RelationshipProposalService {
  RelationshipProposalService({
    required this.confirmation,
    required this.repository,
    required this.syncService,
    required this.journalDb,
    required this.relationshipRepository,
    required this.taskRemover,
  });

  final ChangeSetConfirmationService confirmation;
  final AgentRepository repository;
  final AgentSyncService syncService;
  final JournalDb journalDb;
  final RelationshipRepository relationshipRepository;
  final Future<bool> Function(Task, {String? allowedRelationshipId})
  taskRemover;
  final _busy = <String>{};
  final _receipts = <String, Task>{};
  static const receiptKey = '_relationshipTaskReceipt';

  String _key(String setId, int index) => '$setId:$index';

  /// Retrieves the last user decision for an item; decisions are agent-scoped.
  Future<ChangeDecisionEntity?> _decision(
    ChangeSetEntity set,
    int index,
  ) async {
    final decisions =
        (await repository.getEntitiesByAgentId(
              set.agentId,
              type: AgentEntityTypes.changeDecision,
            ))
            .whereType<ChangeDecisionEntity>()
            .where(
              (d) =>
                  d.changeSetId == set.id &&
                  d.itemIndex == index &&
                  d.deletedAt == null &&
                  d.actor == DecisionActor.user,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return decisions.firstOrNull;
  }

  /// Local fallback when a successful creation outlived a receipt write error.
  Task? cachedReceipt(String setId, int index) => _receipts[_key(setId, index)];

  /// A durable snapshot of the task created by this confirmation, if any.
  Future<Task?> receipt(ChangeSetEntity set, int index) async {
    final cached = _receipts[_key(set.id, index)];
    if (cached != null) return cached;
    final raw = (await _decision(set, index))?.args?[receiptKey];
    return decodeReceipt(raw);
  }

  /// Older or malformed peer data must not make the entire ledger unreadable.
  static Task? decodeReceipt(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      final entity = JournalEntity.fromJson(
        jsonDecode(jsonEncode(raw)) as Map<String, dynamic>,
      );
      return entity is Task ? entity : null;
    } on Object {
      return null;
    }
  }

  Future<ToolExecutionResult> confirm(ChangeSetEntity set, int index) async {
    final key = _key(set.id, index);
    if (set.agentId != relationshipAgentIdFor(set.taskId) || !_busy.add(key)) {
      return const ToolExecutionResult(
        success: false,
        output: 'Proposal is unavailable',
      );
    }
    try {
      final result = await confirmation.confirmItem(set, index);
      if (!result.success || result.mutatedEntityId == null) return result;
      final entity = result is RelationshipTaskCreationResult
          ? result.task
          : null;
      if (entity != null) {
        _receipts[key] = entity;
        try {
          final decision = await _decision(set, index);
          if (decision != null) {
            await syncService.upsertEntity(
              decision.copyWith(
                args: {
                  ...?decision.args,
                  receiptKey: jsonDecode(jsonEncode(entity.toJson())),
                },
              ),
            );
          }
        } catch (error, stackTrace) {
          // Confirmation already created the task. Never offer a second create
          // because persisting its receipt failed; this session can still undo.
          developer.log(
            'Could not persist relationship task receipt',
            name: 'RelationshipProposalService',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      return result;
    } finally {
      _busy.remove(key);
    }
  }

  /// Resolves a history row against its current durable change set.
  Future<bool> undoById(String setId, int index) async {
    final set = await repository.getEntity(setId);
    return set is ChangeSetEntity && await undo(set, index);
  }

  Future<bool> reject(ChangeSetEntity set, int index) async {
    final key = _key(set.id, index);
    if (set.agentId != relationshipAgentIdFor(set.taskId) || !_busy.add(key)) {
      return false;
    }
    try {
      return await confirmation.rejectItem(set, index);
    } finally {
      _busy.remove(key);
    }
  }

  /// Reopens a rejection, or removes an untouched task and its relationship
  /// link, in that order. Failed cleanup can leave a link to a tombstoned task;
  /// failed deletion always preserves the live link. Changed tasks are refused.
  /// The removal is retry-safe: when an earlier Undo tombstoned the task but
  /// failed to reopen the item, a retry finds the untouched tombstone, takes
  /// the task as removed and reopens the item.
  Future<bool> undo(ChangeSetEntity set, int index) async {
    final key = _key(set.id, index);
    if (set.agentId != relationshipAgentIdFor(set.taskId) || !_busy.add(key)) {
      return false;
    }
    try {
      final fresh = await repository.getEntity(set.id);
      if (fresh is! ChangeSetEntity ||
          index < 0 ||
          index >= fresh.items.length) {
        return false;
      }
      final status = fresh.items[index].status;
      if (status == ChangeItemStatus.rejected) {
        return await confirmation.reopenItem(fresh, index);
      }
      if (status != ChangeItemStatus.confirmed) return false;
      final original = await receipt(fresh, index);
      if (original == null) return false;
      final reopened = await confirmation.reopenItem(
        fresh,
        index,
        revert: () async {
          final current = await journalDb.journalEntityById(original.id);
          if (current == null) {
            return _alreadyRemoved(original, fresh.taskId);
          }
          if (current != original ||
              current is! Task ||
              current.isDeleted ||
              await _hasAdditionalLinks(original.id, fresh.taskId)) {
            return false;
          }
          final latest = await journalDb.journalEntityById(original.id);
          if (latest != original ||
              await _hasAdditionalLinks(original.id, fresh.taskId) ||
              !await taskRemover(
                current,
                allowedRelationshipId: fresh.taskId,
              )) {
            return false;
          }
          // A refused deletion must never detach a live task. Once tombstoned,
          // a leftover link is invisible to relationship task queries and is
          // safe to clean up independently.
          await _unlinkRemoved(original.id, fresh.taskId);
          return true;
        },
      );
      if (reopened) _receipts.remove(key);
      return reopened;
    } finally {
      _busy.remove(key);
    }
  }

  /// The revert of an Undo whose task is no longer live: a retry after a
  /// revert that tombstoned the task but whose reopen then failed, leaving
  /// the item confirmed (ADR 0097). The effect is already taken back when
  /// the stored tombstone is [original] as the removal leaves it — nothing
  /// changed but the deletion and its stamps — so the revert succeeds and
  /// the retry proceeds to the reopen. A purge between the two attempts
  /// compacts that tombstone to a type-erased row marked `purgedAt` (ADR
  /// 0095): its content can no longer be compared, but it records that the
  /// task is gone for good, which is all the Undo takes back, so it counts
  /// too. A live task changed after the receipt, or one that is missing
  /// altogether, still refuses.
  Future<bool> _alreadyRemoved(Task original, String personId) async {
    final stored = await journalDb.journalEntityByIdIncludingDeleted(
      original.id,
    );
    final removed = stored != null && stored.isPurgedTombstone
        ? stored.isDeleted
        : stored is Task && _isRemovedReceipt(stored, original);
    if (!removed) return false;
    await _unlinkRemoved(original.id, personId);
    return true;
  }

  /// Whether [stored] is the tombstone removing [original] leaves: deleted,
  /// and equal to [original] apart from the metadata every write restamps
  /// (`updatedAt`, `vectorClock`) and the deletion itself.
  static bool _isRemovedReceipt(Task stored, Task original) {
    if (!stored.isDeleted) return false;
    final meta = stored.meta.copyWith(
      updatedAt: original.meta.updatedAt,
      vectorClock: original.meta.vectorClock,
      deletedAt: original.meta.deletedAt,
    );
    return stored.copyWith(meta: meta) == original;
  }

  /// Removes the relationship's link to the tombstoned task [taskId]. Best
  /// effort: the task is gone either way, and a leftover link to it is
  /// invisible to relationship task queries.
  Future<void> _unlinkRemoved(String taskId, String personId) async {
    try {
      final unlinked = await relationshipRepository.unlinkTask(
        relationshipId: personId,
        taskId: taskId,
      );
      if (!unlinked) {
        developer.log(
          'Task removed; relationship link cleanup was refused',
          name: 'RelationshipProposalService',
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Task removed; relationship link cleanup failed',
        name: 'RelationshipProposalService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Notes, checklist entries or another relationship make a task independently
  /// useful even when linking them did not change the task's own metadata.
  Future<bool> _hasAdditionalLinks(String taskId, String personId) async {
    final links = await journalDb.linksForEntryIdsBidirectional({taskId});
    return links.any(
      (link) =>
          link.deletedAt == null &&
          !(link is RelationshipLink &&
              ((link.fromId == personId && link.toId == taskId) ||
                  (link.fromId == taskId && link.toId == personId))),
    );
  }
}
