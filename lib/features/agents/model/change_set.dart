import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

part 'change_set.freezed.dart';
part 'change_set.g.dart';

/// A single proposed mutation within a change set.
///
/// Each item represents one atomic change the agent wants to make — e.g., a
/// single checklist item to add, a status transition, or an estimate update.
/// Batch tool calls (like `add_multiple_checklist_items`) are exploded into
/// individual [ChangeItem] entries so the user can confirm or reject each one
/// independently.
@freezed
abstract class ChangeItem with _$ChangeItem {
  const factory ChangeItem({
    /// The tool name for this mutation (e.g., `add_checklist_item`).
    required String toolName,

    /// The arguments to pass to the tool handler.
    required Map<String, dynamic> args,

    /// A user-facing plain-text description of what this change does.
    required String humanSummary,

    /// Current status of this item within the change set.
    @Default(ChangeItemStatus.pending) ChangeItemStatus status,

    /// Optional group identifier for related items (e.g., a task-split
    /// operation produces a create + N migrate items sharing the same group).
    /// Used by the approval UI to visually group related items.
    String? groupId,
  }) = _ChangeItem;

  factory ChangeItem.fromJson(Map<String, dynamic> json) =>
      _$ChangeItemFromJson(json);

  static const _deepEquals = DeepCollectionEquality();

  /// Structural fingerprint from raw parts, without requiring a [ChangeItem].
  ///
  /// Useful when reconstructing fingerprints from persisted decision records
  /// that store `toolName` and `args` separately.
  static String fingerprintFromParts(
    String toolName,
    Map<String, dynamic> args,
  ) => '$toolName:${_deepEquals.hash(args)}';

  /// Structural fingerprint based on `toolName` and `args`.
  ///
  /// Ignores `status` and `humanSummary` so that two items proposing the
  /// same mutation are considered equal regardless of presentation.
  static String fingerprint(ChangeItem item) =>
      fingerprintFromParts(item.toolName, item.args);

  /// Derives the overall `ChangeSetStatus` from a list of item statuses.
  ///
  /// Mirrors the contract enforced by both `ChangeSetConfirmationService`
  /// (user confirm/reject) and `SuggestionRetractionService` (agent
  /// retraction): when every item is resolved the set is resolved; when
  /// some are still pending the set is partiallyResolved; when none have
  /// been touched the set stays pending.
  static ChangeSetStatus deriveSetStatus(List<ChangeItem> items) {
    final anyResolved = items.any((i) => i.status != ChangeItemStatus.pending);
    if (!anyResolved) return ChangeSetStatus.pending;
    final allResolved = items.every(
      (i) => i.status != ChangeItemStatus.pending,
    );
    return allResolved
        ? ChangeSetStatus.resolved
        : ChangeSetStatus.partiallyResolved;
  }

  /// Derives the `resolvedAt` timestamp consistent with [newStatus].
  ///
  /// Only `ChangeSetStatus.resolved` carries a non-null value; any other
  /// status clears the field so queries that treat `resolvedAt != null` as
  /// "resolved" do not see stale timestamps after a revert path. An
  /// already-set timestamp is preserved on idempotent re-resolves so the
  /// original resolution time is not overwritten.
  static DateTime? deriveResolvedAt({
    required ChangeSetStatus newStatus,
    required DateTime? existingResolvedAt,
    required DateTime now,
  }) {
    if (newStatus != ChangeSetStatus.resolved) return null;
    return existingResolvedAt ?? now;
  }
}
