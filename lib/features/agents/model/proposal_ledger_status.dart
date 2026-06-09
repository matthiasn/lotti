import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';

/// Pure status state-machine for the proposal ledger.
///
/// These functions classify the lifecycle status of proposal-ledger items
/// without touching the database. They are factored out of
/// `agent_proposal_ledger.dart` so they can be exercised directly as a unit,
/// independent of any repository or sqlite setup.

/// Whether a change set in [status] is still "active" — i.e. it can hold
/// open, actionable proposals.
///
/// Only [ChangeSetStatus.pending] and [ChangeSetStatus.partiallyResolved]
/// are active; [ChangeSetStatus.resolved] and [ChangeSetStatus.expired]
/// are terminal and never contribute open items.
bool isPendingLike(ChangeSetStatus status) {
  return status == ChangeSetStatus.pending ||
      status == ChangeSetStatus.partiallyResolved;
}

/// The effective ledger status of [item], given whether its parent change
/// set is still active ([setIsActive]) and the newest item-level
/// [decision] (if any).
///
/// Contract:
///  * a non-pending embedded item status is always authoritative and is
///    returned unchanged;
///  * a pending item with no decision stays pending;
///  * a `confirmed` verdict on an ACTIVE set keeps the item pending —
///    confirmation is written before dispatch, and a failed dispatch
///    deliberately reverts the item to pending so the user can retry;
///  * rejection, deferral, and retraction have no dispatch retry path, so
///    their decisions close an otherwise-stale embedded pending item.
ChangeItemStatus effectiveLedgerStatus({
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
  return statusForDecision(verdict);
}

/// The terminal [ChangeItemStatus] implied by a resolved decision [verdict].
ChangeItemStatus statusForDecision(ChangeDecisionVerdict verdict) {
  return switch (verdict) {
    ChangeDecisionVerdict.confirmed => ChangeItemStatus.confirmed,
    ChangeDecisionVerdict.rejected => ChangeItemStatus.rejected,
    ChangeDecisionVerdict.deferred => ChangeItemStatus.deferred,
    ChangeDecisionVerdict.retracted => ChangeItemStatus.retracted,
  };
}
