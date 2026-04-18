import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// A single row in the proposal ledger — one `ChangeItem` the agent has
/// ever produced for a given task, annotated with its current lifecycle
/// status and (if resolved) who resolved it and why.
///
/// Constructed transiently by `AgentRepository.getProposalLedger`; not
/// persisted. Composes data from the owning `ChangeSetEntity` with the
/// matching `ChangeDecisionEntity` (if the item has been resolved).
class LedgerEntry {
  const LedgerEntry({
    required this.changeSetId,
    required this.itemIndex,
    required this.toolName,
    required this.args,
    required this.humanSummary,
    required this.fingerprint,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.verdict,
    this.reason,
    this.groupId,
  });

  /// The parent `ChangeSetEntity.id`.
  final String changeSetId;

  /// The zero-based position of this item within its parent set's items list.
  final int itemIndex;

  /// The mutation tool name (e.g., `set_task_priority`).
  final String toolName;

  /// The original tool-call arguments.
  final Map<String, dynamic> args;

  /// Plain-text description of the proposed change.
  final String humanSummary;

  /// Structural fingerprint of `toolName + args` — stable across wakes,
  /// used by the agent's retraction protocol and by persistence-time
  /// dedup to match items across change sets.
  final String fingerprint;

  /// The item's current status (`pending` / `confirmed` / `rejected` /
  /// `retracted` / `deferred`).
  final ChangeItemStatus status;

  /// When the parent change set created this item.
  final DateTime createdAt;

  /// When the item was resolved (confirmed / rejected / retracted / expired),
  /// or `null` if still open.
  final DateTime? resolvedAt;

  /// Who resolved the item, or `null` if still open / expired.
  final DecisionActor? resolvedBy;

  /// The resolution verdict, or `null` if still open / expired.
  final ChangeDecisionVerdict? verdict;

  /// Free-text reason for the resolution — the user's rejection reason or
  /// the agent's retraction reason, whichever applies. `null` otherwise.
  final String? reason;

  /// Optional group key from the source `ChangeItem` (used by task-split
  /// operations to relate a follow-up creation to its migration items).
  final String? groupId;

  /// True when the item is still pending and therefore actionable in the UI
  /// and reasonable to propose duplicates against.
  bool get isOpen => status == ChangeItemStatus.pending;
}

/// All proposals an agent has ever produced for one target task, grouped
/// by whether they are still actionable or already resolved.
///
/// Open entries are the unioned pending items across any
/// pending/partiallyResolved change sets for the task. Resolved entries
/// are capped at a bounded recent window to keep LLM prompts small.
class ProposalLedger {
  const ProposalLedger({
    required this.open,
    required this.resolved,
    this.pendingSets = const [],
  });

  const ProposalLedger.empty()
    : open = const [],
      resolved = const [],
      pendingSets = const [];

  /// Still-pending proposals. Newest-first.
  final List<LedgerEntry> open;

  /// Recently-resolved proposals — confirmed, rejected, retracted, or
  /// expired. Newest-first, bounded by the caller.
  final List<LedgerEntry> resolved;

  /// The underlying pending (or partiallyResolved) `ChangeSetEntity`
  /// snapshots that produced [open]. Exposed so callers like the prompt
  /// builder and the UI provider do not have to re-query
  /// `getPendingChangeSets` separately — one repository round-trip feeds
  /// both the agent context and the user-facing list.
  final List<ChangeSetEntity> pendingSets;

  bool get isEmpty => open.isEmpty && resolved.isEmpty;
}
