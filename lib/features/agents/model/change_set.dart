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
  }) = _ChangeItem;

  factory ChangeItem.fromJson(Map<String, dynamic> json) =>
      _$ChangeItemFromJson(json);

  static const _deepEquals = DeepCollectionEquality();

  /// Structural fingerprint based on `toolName` and `args`.
  ///
  /// Ignores `status` and `humanSummary` so that two items proposing the
  /// same mutation are considered equal regardless of presentation.
  static String fingerprint(ChangeItem item) =>
      '${item.toolName}:${_deepEquals.hash(item.args)}';
}
