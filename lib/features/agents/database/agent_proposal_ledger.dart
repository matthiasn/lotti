part of 'agent_repository.dart';

/// Proposal-ledger assembly of [AgentRepository] — the heaviest single
/// query in the repository. The class keeps a thin delegator so mocks
/// keep intercepting the public method.
extension AgentProposalLedger on AgentRepository {
  /// Build a [ProposalLedger] for [taskId] under [agentId] — every
  /// [ChangeItem] the agent has ever produced for this task, annotated with
  /// its current lifecycle status and (if resolved) who resolved it.
  ///
  /// The ledger feeds two consumers:
  ///
  ///  * the LLM prompt (`TaskAgentWorkflow._formatProposalLedger`), so the
  ///    agent sees a single status-sorted view of its own history and can
  ///    avoid duplicate proposals or explicitly retract stale ones;
  ///  * the consolidated `AiSummaryCard` UI, which renders only open
  ///    items and exposes resolved history in a collapsed history toggle
  ///    plus an inline recent-activity footer.
  ///
  /// Open entries are extracted only from pending/partiallyResolved change
  /// sets whose effective item status is still pending. Resolved entries come
  /// from non-pending items and item-level [ChangeDecisionEntity] records, and
  /// are capped at [resolvedLimit] most-recent decisions to keep the LLM
  /// prompt bounded. Historical rows with a resolved parent but a stale
  /// embedded pending item and no decision are filtered out entirely.
  Future<ProposalLedger> getProposalLedgerImpl(
    String agentId, {
    required String taskId,
    int changeSetFetchLimit = 200,
    int resolvedLimit = 50,
  }) async {
    // Three independent table scans — run in parallel to keep wall-clock
    // bounded on cold sqlite access. The dedicated pending query is what
    // guarantees an old-but-still-open consolidated change set is never
    // dropped by the recent-history cap: `getChangeSetsForAgent` is
    // newest-first and would otherwise bury a long-lived open set past
    // `changeSetFetchLimit` once enough resolved history accumulates.
    final results = await Future.wait([
      _db
          .getPendingChangeSetsForAgent(
            agentId,
            changeSetFetchLimit * AgentRepository._overFetchMultiplier,
          )
          .get(),
      _db.getChangeSetsForAgent(agentId, changeSetFetchLimit).get(),
      _db
          .getRecentDecisionsForAgent(
            agentId,
            resolvedLimit * AgentRepository._overFetchMultiplier,
          )
          .get(),
    ]);
    final pendingRows = results[0];
    final recentRows = results[1];
    final decisionRows = results[2];

    final rawPendingSets = pendingRows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeSetEntity>()
        .where((cs) => cs.taskId == taskId)
        .toList();
    final recentSets = recentRows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeSetEntity>()
        .where((cs) => cs.taskId == taskId);

    final setsById = <String, ChangeSetEntity>{
      for (final cs in recentSets) cs.id: cs,
      // Pending wins the union: its rows are freshly queried by status
      // and may reflect state that newer resolved rows have not yet
      // picked up if a confirmation landed between the two scans.
      for (final cs in rawPendingSets) cs.id: cs,
    };
    final allSets = setsById.values.toList();

    if (allSets.isEmpty) return const ProposalLedger.empty();

    final decisions = decisionRows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeDecisionEntity>()
        .where((d) => d.taskId == taskId)
        .toList();

    final decisionByKey = <String, ChangeDecisionEntity>{};
    for (final d in decisions) {
      // Rows are newest-first. Keep the newest decision for each item;
      // older retry/audit rows must not reopen a later rejection or
      // retraction in the prompt ledger.
      decisionByKey.putIfAbsent('${d.changeSetId}:${d.itemIndex}', () => d);
    }

    final open = <LedgerEntry>[];
    final resolved = <LedgerEntry>[];
    final pendingSetIds = {for (final cs in rawPendingSets) cs.id};
    final sanitizedItemsBySetId = <String, List<ChangeItem>>{};

    for (final set in allSets) {
      final setIsActive = _isPendingLike(set.status);
      final sanitizedItems = pendingSetIds.contains(set.id)
          ? <ChangeItem>[]
          : null;
      for (var i = 0; i < set.items.length; i++) {
        final item = set.items[i];
        final decision = decisionByKey['${set.id}:$i'];
        final effectiveStatus = _effectiveLedgerStatus(
          setIsActive: setIsActive,
          item: item,
          decision: decision,
        );
        if (sanitizedItems != null) {
          sanitizedItems.add(
            effectiveStatus == item.status
                ? item
                : item.copyWith(status: effectiveStatus),
          );
        }
        final isOpen =
            setIsActive && effectiveStatus == ChangeItemStatus.pending;
        final hasResolvedSignal =
            effectiveStatus != ChangeItemStatus.pending || decision != null;
        if (!isOpen && !hasResolvedSignal) {
          // Historical consolidation bugs could leave a resolved/expired
          // parent row with embedded pending items and no decision. Those
          // rows are neither actionable nor useful history, so keep them
          // out of the LLM prompt and UI activity strip.
          continue;
        }
        final entry = LedgerEntry(
          changeSetId: set.id,
          itemIndex: i,
          toolName: item.toolName,
          args: item.args,
          humanSummary: item.humanSummary,
          fingerprint: ChangeItem.fingerprint(item),
          status: effectiveStatus,
          createdAt: set.createdAt,
          resolvedAt: decision?.createdAt ?? set.resolvedAt,
          resolvedBy: decision?.actor,
          verdict: decision?.verdict,
          reason: decision?.retractionReason ?? decision?.rejectionReason,
          groupId: item.groupId,
        );
        if (isOpen) {
          open.add(entry);
        } else {
          resolved.add(entry);
        }
      }
      if (sanitizedItems != null) {
        sanitizedItemsBySetId[set.id] = sanitizedItems;
      }
    }

    open.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    resolved.sort((a, b) {
      final aResolved = a.resolvedAt ?? a.createdAt;
      final bResolved = b.resolvedAt ?? b.createdAt;
      return bResolved.compareTo(aResolved);
    });

    final sanitizedPendingSets = <ChangeSetEntity>[];
    for (final set in rawPendingSets) {
      final items = sanitizedItemsBySetId[set.id];
      if (items == null) continue;
      if (items.any((i) => i.status == ChangeItemStatus.pending)) {
        sanitizedPendingSets.add(set.copyWith(items: items));
      }
    }

    return ProposalLedger(
      open: open,
      resolved: resolved.take(resolvedLimit).toList(),
      pendingSets: sanitizedPendingSets,
    );
  }

  /// Test-only seam for [_isPendingLike] — pure enum predicate.
  @visibleForTesting
  static bool debugIsPendingLike(ChangeSetStatus status) =>
      _isPendingLike(status);

  /// Test-only seam for [_effectiveLedgerStatus] — the pure status
  /// state-machine that getProposalLedger applies per item.
  @visibleForTesting
  static ChangeItemStatus debugEffectiveLedgerStatus({
    required bool setIsActive,
    required ChangeItem item,
    required ChangeDecisionEntity? decision,
  }) => _effectiveLedgerStatus(
    setIsActive: setIsActive,
    item: item,
    decision: decision,
  );

  static bool _isPendingLike(ChangeSetStatus status) {
    return status == ChangeSetStatus.pending ||
        status == ChangeSetStatus.partiallyResolved;
  }

  static ChangeItemStatus _effectiveLedgerStatus({
    required bool setIsActive,
    required ChangeItem item,
    required ChangeDecisionEntity? decision,
  }) {
    if (item.status != ChangeItemStatus.pending) return item.status;

    final verdict = decision?.verdict;
    if (verdict == null) return item.status;

    // Confirmation decisions are written before dispatch. If dispatch later
    // fails, the item is deliberately reverted to pending so the user can
    // retry. Rejection, deferral, and retraction have no dispatch retry path,
    // so their decisions close stale embedded pending items.
    if (setIsActive && verdict == ChangeDecisionVerdict.confirmed) {
      return item.status;
    }
    return _statusForDecision(verdict);
  }

  static ChangeItemStatus _statusForDecision(ChangeDecisionVerdict verdict) {
    return switch (verdict) {
      ChangeDecisionVerdict.confirmed => ChangeItemStatus.confirmed,
      ChangeDecisionVerdict.rejected => ChangeItemStatus.rejected,
      ChangeDecisionVerdict.deferred => ChangeItemStatus.deferred,
      ChangeDecisionVerdict.retracted => ChangeItemStatus.retracted,
    };
  }
}
