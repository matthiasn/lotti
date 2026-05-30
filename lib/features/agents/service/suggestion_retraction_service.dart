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

  /// Structural fingerprint of the target item (`toolName + args`). Lets the
  /// workflow detect when the agent is retracting a proposal it is
  /// simultaneously re-proposing this wake (retract-then-re-add churn).
  String get fingerprint => ChangeItem.fingerprint(item);
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
  /// intermediate state.
  ///
  /// Decisions are persisted first (one per staged item, in order), then each
  /// parent change set is re-read **once** and all of its retractions applied in
  /// a single write. Grouping by change set keeps DB I/O proportional to the
  /// number of distinct sets, not the number of items, and collapses what the
  /// `AiSummaryCard` stream sees into one update per set.
  ///
  /// Applying at end-of-wake is also strictly safer than mid-conversation: the
  /// re-read re-validates each target by **bounds, status, and fingerprint**, so
  /// an item a concurrent user confirm/reject already resolved — or one whose
  /// row moved or changed under us — is skipped rather than mis-retracted.
  ///
  /// [skipFingerprints] suppresses retractions whose target item shares a
  /// fingerprint with something the agent is **re-proposing in the same wake**.
  /// Retracting an open proposal and re-adding an identical one is churn: it
  /// makes a stable suggestion vanish and reappear under the user's finger.
  /// Skipping the retraction keeps the original open; the matching new proposal
  /// is then dropped by the builder's dedup against that still-open original.
  /// Stale retractions (not re-proposed) and supersedes (different fingerprint,
  /// e.g. `update_running_timer`) carry a different fingerprint and are applied
  /// normally.
  Future<void> applyStaged(
    List<StagedRetraction> staged, {
    Set<String> skipFingerprints = const {},
  }) async {
    if (staged.isEmpty) return;

    // Dedupe by target item, preserving first-seen order, drop churn (an item
    // being re-proposed this wake), and group by parent change set so each set
    // is read and written exactly once.
    final seenKeys = <String>{};
    final deduped = <StagedRetraction>[];
    final order = <String>[];
    final byChangeSetId = <String, List<StagedRetraction>>{};
    for (final retraction in staged) {
      if (skipFingerprints.contains(retraction.fingerprint)) continue;
      if (!seenKeys.add(retraction.key)) continue;
      deduped.add(retraction);
      byChangeSetId
          .putIfAbsent(retraction.changeSet.id, () {
            order.add(retraction.changeSet.id);
            return <StagedRetraction>[];
          })
          .add(retraction);
    }
    if (deduped.isEmpty) return;

    // 1. Persist every decision first (in staged order) so we never leave a
    //    retracted item without a matching explanation — mirrors the
    //    confirmation service ordering (see
    //    ChangeSetConfirmationService.confirmItem).
    for (final retraction in deduped) {
      await _persistRetractionDecision(retraction);
    }

    // 2. Apply each set's retractions in a single re-read + write + notify.
    for (final changeSetId in order) {
      await _applyRetractionsToChangeSet(byChangeSetId[changeSetId]!);
    }
  }

  Future<void> _persistRetractionDecision(StagedRetraction retraction) async {
    final item = retraction.item;
    _domainLogger?.log(
      LogDomains.agentWorkflow,
      'Retracting item ${retraction.itemIndex} (${item.toolName}) in change '
      'set ${DomainLogger.sanitizeId(retraction.changeSet.id)}',
      subDomain: _sub,
    );

    final decision =
        AgentDomainEntity.changeDecision(
              id: _uuid.v4(),
              agentId: retraction.changeSet.agentId,
              changeSetId: retraction.changeSet.id,
              itemIndex: retraction.itemIndex,
              toolName: item.toolName,
              verdict: ChangeDecisionVerdict.retracted,
              actor: DecisionActor.agent,
              taskId: retraction.changeSet.taskId,
              retractionReason: retraction.reason,
              humanSummary: item.humanSummary,
              args: item.args,
              createdAt: clock.now(),
              vectorClock: const VectorClock({}),
            )
            as ChangeDecisionEntity;
    await _syncService.upsertEntity(decision);
  }

  /// Applies every retraction targeting one change set in a single read/write.
  ///
  /// All entries share the same `changeSet.id`. The set is re-read once, every
  /// still-valid target item is flipped to `retracted` in memory, and the set
  /// is persisted once (only if at least one flip survived validation).
  Future<void> _applyRetractionsToChangeSet(
    List<StagedRetraction> retractions,
  ) async {
    final snapshot = retractions.first.changeSet;
    final latest = await _syncService.repository.getEntity(snapshot.id);
    final current = latest is ChangeSetEntity ? latest : snapshot;

    var items = current.items;
    var changed = false;
    for (final retraction in retractions) {
      final itemIndex = retraction.itemIndex;
      if (itemIndex < 0 || itemIndex >= items.length) {
        // A concurrent writer truncated items between staging and this
        // re-read. The decision was already persisted, so surface the orphan.
        _domainLogger?.log(
          LogDomains.agentWorkflow,
          'Retraction bounds mismatch after re-read: itemIndex=$itemIndex, '
          'items=${items.length}, '
          'changeSet=${DomainLogger.sanitizeId(current.id)}',
          subDomain: _sub,
        );
        continue;
      }
      final existing = items[itemIndex];
      if (existing.status != ChangeItemStatus.pending) {
        // The user confirmed/rejected the item between staging and this
        // re-read. Do not overwrite their decision; the agent's retraction
        // decision record stays persisted for the audit trail.
        _domainLogger?.log(
          LogDomains.agentWorkflow,
          'Retraction lost race to user action: itemIndex=$itemIndex, '
          'observedStatus=${existing.status.name}, '
          'changeSet=${DomainLogger.sanitizeId(current.id)}',
          subDomain: _sub,
        );
        continue;
      }
      if (ChangeItem.fingerprint(existing) !=
          ChangeItem.fingerprint(retraction.item)) {
        // The row at this index is no longer the item we staged (inserted,
        // removed, reordered, or its args changed under us). Skip rather than
        // retract the wrong proposal; the agent can re-stage on the next wake.
        _domainLogger?.log(
          LogDomains.agentWorkflow,
          'Retraction skipped — item at index changed: itemIndex=$itemIndex, '
          'changeSet=${DomainLogger.sanitizeId(current.id)}',
          subDomain: _sub,
        );
        continue;
      }

      if (!changed) {
        items = List<ChangeItem>.from(items);
        changed = true;
      }
      items[itemIndex] = existing.copyWith(status: ChangeItemStatus.retracted);
    }

    if (!changed) return;

    final newSetStatus = ChangeItem.deriveSetStatus(items);
    final updated = current.copyWith(
      items: items,
      status: newSetStatus,
      resolvedAt: ChangeItem.deriveResolvedAt(
        newStatus: newSetStatus,
        existingResolvedAt: current.resolvedAt,
        now: clock.now(),
      ),
    );
    await _syncService.upsertEntity(updated);
    await _notifyChangeSetRetracted(updated);
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
