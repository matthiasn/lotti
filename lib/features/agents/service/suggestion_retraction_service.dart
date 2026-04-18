import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Outcome of attempting to retract a single proposed change item.
enum RetractionOutcome {
  /// The item was found in pending status and is now retracted.
  retracted,

  /// The item was located but is no longer in pending status (user already
  /// confirmed or rejected it, or the agent retracted it in an earlier call).
  /// Treated as a no-op.
  notOpen,

  /// No open item with this fingerprint was found for the task.
  notFound,
}

/// One entry in a `retract_suggestions` tool call.
class RetractionRequest {
  const RetractionRequest({required this.fingerprint, required this.reason});

  /// Structural fingerprint from a `LedgerEntry` or `ChangeItem.fingerprint(...)`.
  final String fingerprint;

  /// Free-text justification the agent provides. Persisted on the
  /// `ChangeDecisionEntity.retractionReason` column so the user can see why
  /// the proposal was withdrawn.
  final String reason;
}

/// Per-entry result returned to the LLM after a `retract_suggestions` call.
class RetractionResult {
  const RetractionResult({
    required this.fingerprint,
    required this.outcome,
    this.toolName,
    this.humanSummary,
  });

  final String fingerprint;
  final RetractionOutcome outcome;

  /// Tool name of the retracted item, if one was found.
  final String? toolName;

  /// Human-readable summary of the retracted item, if one was found.
  final String? humanSummary;
}

/// Withdraws change items the agent has previously proposed.
///
/// Retraction is agent-autonomous and not gated on user confirmation: the
/// agent calls `retract_suggestions` during a wake when an open proposal is
/// no longer relevant (duplicate of current state, superseded by user edit,
/// or redundant with another open proposal). Each retraction transitions
/// the target [ChangeItem] to [ChangeItemStatus.retracted] and persists a
/// matching [ChangeDecisionEntity] whose `actor` is [DecisionActor.agent]
/// and whose `retractionReason` carries the agent's justification.
///
/// The service re-reads the parent [ChangeSetEntity] before mutating it so
/// concurrent user confirmations are not overwritten — last writer wins,
/// but both paths leave a decision record.
class SuggestionRetractionService {
  SuggestionRetractionService({
    required AgentSyncService syncService,
    DomainLogger? domainLogger,
  }) : _syncService = syncService,
       _domainLogger = domainLogger;

  final AgentSyncService _syncService;
  final DomainLogger? _domainLogger;

  static const _uuid = Uuid();
  static const _sub = 'SuggestionRetraction';

  /// Retract every request in [requests] against the pending change sets for
  /// `(agentId, taskId)`. Returns one [RetractionResult] per request, in the
  /// same order.
  Future<List<RetractionResult>> retract({
    required String agentId,
    required String taskId,
    required List<RetractionRequest> requests,
  }) async {
    if (requests.isEmpty) return const [];

    final pendingSets = await _syncService.repository.getPendingChangeSets(
      agentId,
      taskId: taskId,
    );

    final results = <RetractionResult>[];
    // Fingerprints we have already retracted during this call — ensures
    // the same fingerprint passed twice yields `notOpen` on the second
    // occurrence rather than crashing on a stale snapshot.
    final retractedThisCall = <String>{};

    for (final request in requests) {
      final locator = _locate(
        pendingSets,
        request.fingerprint,
        retractedThisCall,
      );
      if (locator == null) {
        results.add(
          RetractionResult(
            fingerprint: request.fingerprint,
            outcome: RetractionOutcome.notFound,
          ),
        );
        continue;
      }

      if (locator.item.status != ChangeItemStatus.pending) {
        results.add(
          RetractionResult(
            fingerprint: request.fingerprint,
            outcome: RetractionOutcome.notOpen,
            toolName: locator.item.toolName,
            humanSummary: locator.item.humanSummary,
          ),
        );
        continue;
      }

      await _applyRetraction(
        changeSet: locator.changeSet,
        itemIndex: locator.itemIndex,
        item: locator.item,
        agentId: agentId,
        taskId: taskId,
        reason: request.reason,
      );
      retractedThisCall.add(request.fingerprint);

      results.add(
        RetractionResult(
          fingerprint: request.fingerprint,
          outcome: RetractionOutcome.retracted,
          toolName: locator.item.toolName,
          humanSummary: locator.item.humanSummary,
        ),
      );
    }

    return results;
  }

  ({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})? _locate(
    List<ChangeSetEntity> pendingSets,
    String fingerprint,
    Set<String> alreadyRetractedInThisCall,
  ) {
    for (final cs in pendingSets) {
      for (var i = 0; i < cs.items.length; i++) {
        final item = cs.items[i];
        if (ChangeItem.fingerprint(item) != fingerprint) continue;
        // If this fingerprint was already retracted earlier in the same
        // call, surface it as `notOpen` — the on-disk state is in flux
        // and a second retraction would double-write the decision.
        final effectiveItem = alreadyRetractedInThisCall.contains(fingerprint)
            ? item.copyWith(status: ChangeItemStatus.retracted)
            : item;
        return (changeSet: cs, itemIndex: i, item: effectiveItem);
      }
    }
    return null;
  }

  Future<void> _applyRetraction({
    required ChangeSetEntity changeSet,
    required int itemIndex,
    required ChangeItem item,
    required String agentId,
    required String taskId,
    required String reason,
  }) async {
    final now = clock.now();

    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Retracting item $itemIndex (${item.toolName}) in change set '
      '${changeSet.id}',
      subDomain: _sub,
    );

    // 1. Persist the decision record first so we never leave a retracted
    //    item without a matching explanation — mirrors the confirmation
    //    service ordering (see ChangeSetConfirmationService.confirmItem).
    final decision =
        AgentDomainEntity.changeDecision(
              id: _uuid.v4(),
              agentId: agentId,
              changeSetId: changeSet.id,
              itemIndex: itemIndex,
              toolName: item.toolName,
              verdict: ChangeDecisionVerdict.retracted,
              actor: DecisionActor.agent,
              taskId: taskId,
              retractionReason: reason,
              humanSummary: item.humanSummary,
              args: item.args,
              createdAt: now,
              vectorClock: const VectorClock({}),
            )
            as ChangeDecisionEntity;
    await _syncService.upsertEntity(decision);

    // 2. Re-read the parent change set and transition the item + set status.
    final latest = await _syncService.repository.getEntity(changeSet.id);
    final current = latest is ChangeSetEntity ? latest : changeSet;
    if (itemIndex < 0 || itemIndex >= current.items.length) return;

    final updatedItems = List<ChangeItem>.from(current.items);
    updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
      status: ChangeItemStatus.retracted,
    );

    final newSetStatus = ChangeItem.deriveSetStatus(updatedItems);
    final resolvedAt = newSetStatus == ChangeSetStatus.resolved
        ? now
        : current.resolvedAt;

    await _syncService.upsertEntity(
      current.copyWith(
        items: updatedItems,
        status: newSetStatus,
        resolvedAt: resolvedAt,
      ),
    );
  }
}
