import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
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

/// A retraction that has been validated and is queued for application at the
/// end of the wake.
///
/// [SuggestionRetractionService.plan] produces these without touching the
/// database; [SuggestionRetractionService.applyStaged] persists them. The
/// snapshot ([changeSet], [itemIndex], [item]) lets the apply step re-read the
/// latest persisted state and skip items a concurrent user action has already
/// resolved.
class StagedRetraction {
  const StagedRetraction({
    required this.changeSet,
    required this.itemIndex,
    required this.item,
    required this.reason,
  });

  final ChangeSetEntity changeSet;
  final int itemIndex;
  final ChangeItem item;
  final String reason;

  /// Stable identity of the target item — `'<changeSetId>:<itemIndex>'`. Used
  /// to dedupe staging across multiple `retract_suggestions` calls in one wake
  /// and to dedupe application within [SuggestionRetractionService.applyStaged].
  String get key => '${changeSet.id}:$itemIndex';
}

/// Outcome of [SuggestionRetractionService.plan]: the per-request [results] to
/// feed back to the LLM, plus the [staged] retractions to persist later via
/// [SuggestionRetractionService.applyStaged].
class RetractionPlan {
  const RetractionPlan({required this.results, required this.staged});

  const RetractionPlan.empty() : results = const [], staged = const [];

  final List<RetractionResult> results;
  final List<StagedRetraction> staged;
}

typedef ChangeSetRetractionCallback =
    Future<void> Function(ChangeSetEntity changeSet);

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
/// Retraction is a two-phase operation so it can commit atomically with the
/// wake's other writes:
///  * [plan] validates the requested fingerprints against the current pending
///    sets and returns the per-request outcomes (for the LLM) plus the staged
///    retractions — it touches nothing on disk.
///  * [applyStaged] persists those staged retractions. The workflow runs it at
///    the end of the wake, in the same transaction as the new proposals, so the
///    suggestion list never flashes empty between a retraction and its
///    replacement.
///
/// The service re-reads the parent [ChangeSetEntity] before mutating it so
/// concurrent user confirmations are not overwritten — last writer wins,
/// but both paths leave a decision record.
class SuggestionRetractionService {
  SuggestionRetractionService({
    required this._syncService,
    this._domainLogger,
    this._onChangeSetRetracted,
  });

  final AgentSyncService _syncService;
  final DomainLogger? _domainLogger;
  final ChangeSetRetractionCallback? _onChangeSetRetracted;

  static const _uuid = Uuid();
  static const _sub = 'SuggestionRetraction';

  /// Validate [requests] against the current pending change sets for
  /// `(agentId, taskId)` WITHOUT persisting anything.
  ///
  /// Returns a [RetractionPlan] whose [RetractionPlan.results] list (one entry
  /// per request, in order) is the per-entry outcome report for the LLM, and
  /// whose [RetractionPlan.staged] list holds the pending items that should be
  /// retracted. The caller persists the staged retractions at the end of the
  /// wake via [applyStaged] so they commit atomically with the wake's new
  /// proposals — the suggestion list never flashes empty between a retraction
  /// and its replacement.
  ///
  /// [alreadyStagedKeys] are item keys (`'<changeSetId>:<itemIndex>'`) staged
  /// by earlier `retract_suggestions` calls in the same wake. Because nothing
  /// is persisted between calls, those items still read as pending here; the
  /// keys let a repeated request report `notOpen` and avoid staging the same
  /// item twice.
  Future<RetractionPlan> plan({
    required String agentId,
    required String taskId,
    required List<RetractionRequest> requests,
    Set<String> alreadyStagedKeys = const {},
  }) async {
    if (requests.isEmpty) return const RetractionPlan.empty();

    final pendingSets = await _syncService.repository.getPendingChangeSets(
      agentId,
      taskId: taskId,
    );

    final results = <RetractionResult>[];
    final staged = <StagedRetraction>[];
    // Item keys staged so far (prior calls + this call). Prevents the same
    // target item from being staged twice across `retract_suggestions` calls.
    final stagedKeys = <String>{...alreadyStagedKeys};
    // Fingerprints staged earlier in THIS call, so the same fingerprint passed
    // twice yields `notOpen` on the second occurrence instead of re-staging.
    final stagedThisCall = <String>{};
    Map<String, LedgerEntry>? resolvedByFingerprint;

    Future<LedgerEntry?> resolvedLedgerEntry(String fingerprint) async {
      if (resolvedByFingerprint == null) {
        final ledger = await _syncService.repository.getProposalLedger(
          agentId,
          taskId: taskId,
        );
        // ledger.resolved is sorted newest-first; keep the first occurrence
        // per fingerprint so older duplicates don't overwrite newer entries.
        final byFingerprint = <String, LedgerEntry>{};
        for (final entry in ledger.resolved) {
          byFingerprint.putIfAbsent(entry.fingerprint, () => entry);
        }
        resolvedByFingerprint = byFingerprint;
      }
      return resolvedByFingerprint![fingerprint];
    }

    for (final request in requests) {
      final matches = _locateAll(pendingSets, request.fingerprint);
      if (matches.isEmpty) {
        final resolvedEntry = await resolvedLedgerEntry(request.fingerprint);
        if (resolvedEntry != null) {
          results.add(
            RetractionResult(
              fingerprint: request.fingerprint,
              outcome: RetractionOutcome.notOpen,
              toolName: resolvedEntry.toolName,
              humanSummary: resolvedEntry.humanSummary,
            ),
          );
          continue;
        }
        results.add(
          RetractionResult(
            fingerprint: request.fingerprint,
            outcome: RetractionOutcome.notFound,
          ),
        );
        continue;
      }

      // Already staged this fingerprint earlier in the same call — the second
      // pass is a no-op (the first staged every pending sibling).
      if (stagedThisCall.contains(request.fingerprint)) {
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
          .where(
            (m) =>
                m.item.status == ChangeItemStatus.pending &&
                !stagedKeys.contains('${m.changeSet.id}:${m.itemIndex}'),
          )
          .toList();
      if (pendingMatches.isEmpty) {
        // Every match is already resolved or already staged — report the
        // first so the LLM sees the item exists but is no longer actionable.
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

      // Sibling sweep: stage every pending duplicate, not just the first.
      // Multiple items can share a fingerprint when consecutive wakes wrote
      // separate change sets before cross-set dedup caught them, and a single
      // agent retraction intent should clear every open copy so the user
      // doesn't keep seeing ghosts in the UI.
      for (final match in pendingMatches) {
        staged.add(
          StagedRetraction(
            changeSet: match.changeSet,
            itemIndex: match.itemIndex,
            item: match.item,
            reason: request.reason,
          ),
        );
        stagedKeys.add('${match.changeSet.id}:${match.itemIndex}');
      }
      stagedThisCall.add(request.fingerprint);

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

    return RetractionPlan(results: results, staged: staged);
  }

  /// Persist the [staged] retractions produced by [plan].
  ///
  /// Intended to run at the end of a wake — ideally inside the same transaction
  /// that persists the wake's new proposals — so the suggestion list
  /// transitions straight from the old set to the new one without an empty
  /// intermediate state. Each retraction re-reads the parent [ChangeSetEntity]
  /// and skips the item if a concurrent user confirm/reject already resolved
  /// it, so deferring the write is strictly safer than applying it
  /// mid-conversation.
  Future<void> applyStaged(List<StagedRetraction> staged) async {
    if (staged.isEmpty) return;

    // Defensive dedupe: never write two retractions for the same target item,
    // even if a caller accumulated overlapping plans.
    final applied = <String>{};
    for (final retraction in staged) {
      if (!applied.add(retraction.key)) continue;
      await _applyRetraction(
        changeSet: retraction.changeSet,
        itemIndex: retraction.itemIndex,
        item: retraction.item,
        agentId: retraction.changeSet.agentId,
        taskId: retraction.changeSet.taskId,
        reason: retraction.reason,
      );
    }
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
      '${DomainLogger.sanitizeId(changeSet.id)}',
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
        'items=${current.items.length}, '
        'changeSet=${DomainLogger.sanitizeId(changeSet.id)}, '
        'decision=${DomainLogger.sanitizeId(decision.id)}',
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
        'changeSet=${DomainLogger.sanitizeId(changeSet.id)}, '
        'decision=${DomainLogger.sanitizeId(decision.id)}',
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

    final updated = current.copyWith(
      items: updatedItems,
      status: newSetStatus,
      resolvedAt: resolvedAt,
    );
    await _syncService.upsertEntity(updated);
    await _notifyChangeSetRetracted(updated);
  }

  Future<void> _notifyChangeSetRetracted(ChangeSetEntity changeSet) async {
    final callback = _onChangeSetRetracted;
    if (callback == null) return;

    try {
      await callback(changeSet);
    } catch (error, stackTrace) {
      _domainLogger?.error(
        LogDomains.agentWorkflow,
        'Post-retraction notification sync failed for change set '
        '${DomainLogger.sanitizeId(changeSet.id)}',
        subDomain: _sub,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
