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
      final matches = _locateAll(pendingSets, request.fingerprint);
      if (matches.isEmpty) {
        results.add(
          RetractionResult(
            fingerprint: request.fingerprint,
            outcome: RetractionOutcome.notFound,
          ),
        );
        continue;
      }

      // If we already retracted this fingerprint earlier in the same
      // call, the second pass is a no-op. The first pass swept every
      // pending sibling; anything still matching this fingerprint is
      // either already `retracted` or caught by the in-`_applyRetraction`
      // bounds/status check.
      if (retractedThisCall.contains(request.fingerprint)) {
        final first = matches.first;
        results.add(
          RetractionResult(
            fingerprint: request.fingerprint,
            outcome: RetractionOutcome.notOpen,
            toolName: first.item.toolName,
            humanSummary: first.item.humanSummary,
          ),
        );
        continue;
      }

      final pendingMatches = matches
          .where((m) => m.item.status == ChangeItemStatus.pending)
          .toList();
      if (pendingMatches.isEmpty) {
        // Every match is already resolved — report the first so the
        // LLM sees the item exists but is no longer actionable.
        final first = matches.first;
        results.add(
          RetractionResult(
            fingerprint: request.fingerprint,
            outcome: RetractionOutcome.notOpen,
            toolName: first.item.toolName,
            humanSummary: first.item.humanSummary,
          ),
        );
        continue;
      }

      // Sibling sweep: retract every pending duplicate, not just the
      // first. Multiple items can share a fingerprint when consecutive
      // wakes wrote separate change sets before cross-set dedup caught
      // them, and a single agent retraction intent should clear every
      // open copy so the user doesn't keep seeing ghosts in the UI.
      for (final match in pendingMatches) {
        await _applyRetraction(
          changeSet: match.changeSet,
          itemIndex: match.itemIndex,
          item: match.item,
          agentId: agentId,
          taskId: taskId,
          reason: request.reason,
        );
      }
      retractedThisCall.add(request.fingerprint);

      // toolName / humanSummary are identical across matches (same
      // fingerprint) — use the first for the LLM response payload.
      final first = pendingMatches.first;
      results.add(
        RetractionResult(
          fingerprint: request.fingerprint,
          outcome: RetractionOutcome.retracted,
          toolName: first.item.toolName,
          humanSummary: first.item.humanSummary,
        ),
      );
    }

    return results;
  }

  /// Return every `(changeSet, itemIndex, item)` tuple whose item matches
  /// [fingerprint]. Duplicates can exist across change sets when
  /// consecutive wakes wrote separate sets before cross-set dedup caught
  /// them; the caller sweeps the full list so no sibling copy survives.
  List<({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>
  _locateAll(List<ChangeSetEntity> pendingSets, String fingerprint) {
    final matches =
        <({ChangeSetEntity changeSet, int itemIndex, ChangeItem item})>[];
    for (final cs in pendingSets) {
      for (var i = 0; i < cs.items.length; i++) {
        final item = cs.items[i];
        if (ChangeItem.fingerprint(item) != fingerprint) continue;
        matches.add((changeSet: cs, itemIndex: i, item: item));
      }
    }
    return matches;
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
    if (itemIndex < 0 || itemIndex >= current.items.length) {
      // Rare: a concurrent writer truncated items between the initial
      // locate and the re-read. The decision entity was already persisted,
      // so surface the orphan so it is diagnosable if it ever happens.
      _domainLogger?.log(
        LogDomains.agentWorkflow,
        'Retraction bounds mismatch after re-read: itemIndex=$itemIndex, '
        'items=${current.items.length}, changeSet=${changeSet.id}, '
        'decision=${decision.id}',
        subDomain: _sub,
      );
      return;
    }
    if (current.items[itemIndex].status != ChangeItemStatus.pending) {
      // The user confirmed/rejected the item between the initial pending
      // check in retract() and this re-read. Do not overwrite their
      // decision. The agent's retraction decision record stays persisted
      // so the audit trail shows both the agent's intent and the user's
      // winning action.
      _domainLogger?.log(
        LogDomains.agentWorkflow,
        'Retraction lost race to user action: itemIndex=$itemIndex, '
        'observedStatus=${current.items[itemIndex].status.name}, '
        'changeSet=${changeSet.id}, decision=${decision.id}',
        subDomain: _sub,
      );
      return;
    }

    final updatedItems = List<ChangeItem>.from(current.items);
    updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
      status: ChangeItemStatus.retracted,
    );

    final newSetStatus = ChangeItem.deriveSetStatus(updatedItems);
    final resolvedAt = ChangeItem.deriveResolvedAt(
      newStatus: newSetStatus,
      existingResolvedAt: current.resolvedAt,
      now: now,
    );

    await _syncService.upsertEntity(
      current.copyWith(
        items: updatedItems,
        status: newSetStatus,
        resolvedAt: resolvedAt,
      ),
    );
  }
}
