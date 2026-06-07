// Test factories for proposal-ledger types — consistent with the other
// `test_data/*_factories.dart` files (sensible defaults, named overrides).

import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';

/// Builds a [LedgerEntry] with sensible defaults.
LedgerEntry makeLedgerEntry({
  String changeSetId = 'cs-001',
  int itemIndex = 0,
  String toolName = 'set_task_priority',
  Map<String, dynamic> args = const <String, dynamic>{'priority': 'P1'},
  String humanSummary = 'Change priority to P1',
  String fingerprint = 'fp-abc123',
  ChangeItemStatus status = ChangeItemStatus.pending,
  DateTime? createdAt,
  DateTime? resolvedAt,
  DecisionActor? resolvedBy,
  ChangeDecisionVerdict? verdict,
  String? reason,
  String? groupId,
}) {
  return LedgerEntry(
    changeSetId: changeSetId,
    itemIndex: itemIndex,
    toolName: toolName,
    args: args,
    humanSummary: humanSummary,
    fingerprint: fingerprint,
    status: status,
    createdAt: createdAt ?? DateTime(2024, 3, 15),
    resolvedAt: resolvedAt,
    resolvedBy: resolvedBy,
    verdict: verdict,
    reason: reason,
    groupId: groupId,
  );
}

/// Builds a [ProposalLedger] with sensible defaults.
ProposalLedger makeProposalLedger({
  List<LedgerEntry> open = const [],
  List<LedgerEntry> resolved = const [],
}) {
  return ProposalLedger(open: open, resolved: resolved);
}
