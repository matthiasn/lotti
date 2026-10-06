import 'dart:convert';

import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/workflow/relationship_tool_dispatcher.dart';
import 'package:lotti/services/domain_logging.dart';

/// Hears each result of a [RelationshipProposalService.confirmAll] batch.
typedef BatchConfirmationListener =
    void Function(ChangeSetEntity set, int index, ToolExecutionResult result);

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
    required this.domainLogger,
    this.onConfirmingChanged,
  });

  final ChangeSetConfirmationService confirmation;
  final AgentRepository repository;
  final AgentSyncService syncService;
  final JournalDb journalDb;
  final RelationshipRepository relationshipRepository;
  final Future<bool> Function(Task, {String? allowedRelationshipId})
  taskRemover;
  final DomainLogger domainLogger;

  /// Hears the set of items being confirmed — in flight, or queued in a
  /// running batch — as `setId:index` keys, on every change. The bands read
  /// it through a provider of its own, so a band's build never needs this
  /// service's dependencies.
  final void Function(Set<String> keys)? onConfirmingChanged;
  static const _logSubDomain = 'RelationshipProposalService';
  final _busy = <String>{};
  final _queued = <String>{};
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
    if (set.agentId != relationshipAgentIdFor(set.taskId) || !_claim(key)) {
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
          domainLogger.error(
            LogDomain.agentWorkflow,
            error,
            stackTrace: stackTrace,
            subDomain: _logSubDomain,
            message: 'Could not persist relationship task receipt',
          );
        }
      }
      return result;
    } finally {
      _release(key);
    }
  }

  /// Whether the item is being confirmed right now, or waits for its turn in
  /// a batch [confirmAll] is running. The batch outlives the band that asked
  /// for it, so a band built again mid-batch has none of its own busy state;
  /// it reads this instead, and offers neither a row nor a second batch the
  /// running one will reach.
  bool isConfirming(String setId, int index) {
    final key = _key(setId, index);
    return _busy.contains(key) || _queued.contains(key);
  }

  bool _claim(String key) {
    if (!_busy.add(key)) return false;
    _publish();
    return true;
  }

  void _release(String key) {
    _busy.remove(key);
    _publish();
  }

  void _publish() => onConfirmingChanged?.call({..._busy, ..._queued});

  /// Confirms [items] one after another, each as [confirm] does, and hands
  /// every result to [onEach] as it lands. The batch is this service's, not
  /// the widget's that asked for it: the chat host builds its suggestions
  /// band lazily, so scrolling away disposes the band mid-batch, and a loop
  /// that lived in the band stopped there with the remaining proposals still
  /// pending. Every item counts as [isConfirming] until its result is in,
  /// and leaves before [onEach] hears of it, so a refresh the listener
  /// triggers already sees it settled. An item another batch already holds
  /// is left to that batch — the person's card and its docked chat each show
  /// a band, and both can be pressed before either hears of the other — so
  /// it is neither confirmed twice nor reported here, and only this batch's
  /// items are released when it ends.
  Future<List<ToolExecutionResult>> confirmAll(
    List<(ChangeSetEntity, int)> items, {
    BatchConfirmationListener? onEach,
  }) async {
    final mine = [
      for (final item in items)
        if (!isConfirming(item.$1.id, item.$2)) item,
    ];
    final keys = [for (final (set, index) in mine) _key(set.id, index)];
    _queued.addAll(keys);
    _publish();
    try {
      return await confirmEach(
        mine,
        confirm: (set, index) async {
          try {
            return await confirm(set, index);
          } finally {
            _queued.remove(_key(set.id, index));
            _publish();
          }
        },
        onEach: onEach,
        logger: domainLogger,
      );
    } finally {
      _queued.removeAll(keys);
      _publish();
    }
  }

  /// The loop under [confirmAll]: [confirm] on each item in order, and
  /// [onEach] with each result. A confirmation that throws counts as a failed
  /// result and the batch goes on; so does a listener that throws. Both are
  /// reported to [logger], when there is one.
  static Future<List<ToolExecutionResult>> confirmEach(
    List<(ChangeSetEntity, int)> items, {
    required Future<ToolExecutionResult> Function(ChangeSetEntity, int) confirm,
    BatchConfirmationListener? onEach,
    DomainLogger? logger,
  }) async {
    final results = <ToolExecutionResult>[];
    for (final (set, index) in items) {
      ToolExecutionResult result;
      try {
        result = await confirm(set, index);
      } catch (error, stackTrace) {
        logger?.error(
          LogDomain.agentWorkflow,
          error,
          stackTrace: stackTrace,
          subDomain: _logSubDomain,
          message: 'confirming a proposal threw',
        );
        result = const ToolExecutionResult(
          success: false,
          output: 'Confirmation failed',
        );
      }
      results.add(result);
      try {
        onEach?.call(set, index, result);
      } catch (error, stackTrace) {
        logger?.error(
          LogDomain.agentWorkflow,
          error,
          stackTrace: stackTrace,
          subDomain: _logSubDomain,
          message: 'a batch confirmation listener threw',
        );
      }
    }
    return results;
  }

  /// Resolves a history row against its current durable change set.
  Future<bool> undoById(String setId, int index) async {
    final set = await repository.getEntity(setId);
    return set is ChangeSetEntity && await undo(set, index);
  }

  Future<bool> reject(ChangeSetEntity set, int index) async {
    final key = _key(set.id, index);
    if (set.agentId != relationshipAgentIdFor(set.taskId) || !_claim(key)) {
      return false;
    }
    try {
      return await confirmation.rejectItem(set, index);
    } finally {
      _release(key);
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
    if (set.agentId != relationshipAgentIdFor(set.taskId) || !_claim(key)) {
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
      _release(key);
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
        domainLogger.log(
          LogDomain.agentWorkflow,
          'Task removed; relationship link cleanup was refused',
          subDomain: _logSubDomain,
          level: InsightLevel.warn,
        );
      }
    } catch (error, stackTrace) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: _logSubDomain,
        message: 'Task removed; relationship link cleanup failed',
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
