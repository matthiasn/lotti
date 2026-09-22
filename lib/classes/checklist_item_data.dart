import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/change_source.dart';

export 'package:lotti/classes/change_source.dart';

part 'checklist_item_data.freezed.dart';
part 'checklist_item_data.g.dart';

@freezed
abstract class ChecklistItemData with _$ChecklistItemData {
  const factory ChecklistItemData({
    required String title,
    required bool isChecked,
    required List<String> linkedChecklists,
    @Default(false) bool isArchived,
    String? id,
    @Default(ChangeSource.user)
    @JsonKey(unknownEnumValue: ChangeSource.user)
    ChangeSource checkedBy,
    DateTime? checkedAt,
    @Default([]) List<ChecklistItemProvenance> approvalHistory,
  }) = _ChecklistItemData;

  factory ChecklistItemData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDataFromJson(json);
  const ChecklistItemData._();

  /// Approval backing the current checked state, independent of chat retention.
  /// Later title edits preserve it; a later direct toggle supersedes it.
  ChecklistItemProvenance? get checkedStateApproval {
    if (checkedBy != ChangeSource.user || checkedAt == null) return null;
    final approval = _currentApproval((a) => a.isChecked, isChecked);
    return approval?.approvedAt == checkedAt ? approval : null;
  }

  /// Approval backing the current title. Any later rename that lands on a
  /// different title — direct or agent-applied — supersedes it.
  ChecklistItemProvenance? get titleApproval =>
      _currentApproval((a) => a.title, title);

  /// Approval backing the current archived state. A later direct archive or
  /// restore that changes the state supersedes it.
  ChecklistItemProvenance? get archivedStateApproval =>
      _currentApproval((a) => a.isArchived, isArchived);

  /// The newest chat approval still backing any part of the current state —
  /// what the checklist row credits to the user rather than the agent.
  ChecklistItemProvenance? get currentChatApproval =>
      [
        checkedStateApproval,
        titleApproval,
        archivedStateApproval,
      ].nonNulls.fold(
        null,
        (newest, approval) =>
            newest == null || approval.approvedAt.isAfter(newest.approvedAt)
            ? approval
            : newest,
      );

  /// The newest receipt that approved a value for one field, provided it came
  /// from a user-approved chat suggestion and still matches [current].
  ChecklistItemProvenance? _currentApproval<T extends Object>(
    T? Function(ChecklistItemProvenance approval) approvedValue,
    T current,
  ) {
    for (final approval in approvalHistory.reversed) {
      final value = approvedValue(approval);
      if (value != null) {
        return approval.source == 'chat_suggestion' &&
                approval.approvedBy == 'user' &&
                value == current
            ? approval
            : null;
      }
    }
    return null;
  }
}

/// The actual confirmation gesture, rather than the number of changes in it.
@JsonEnum(fieldRename: FieldRename.snake)
enum ChecklistApprovalMode { individual, confirmAll }

/// Trusted approval receipt written with the checklist mutation, never parsed
/// from model tool arguments. Lotti's human actor is the local user; the host
/// identifies their approving device, not a fabricated account identity.
@freezed
abstract class ChecklistItemProvenance with _$ChecklistItemProvenance {
  const factory ChecklistItemProvenance({
    required String approvedBy,
    required String approvalHost,
    required DateTime approvedAt,
    required ChecklistApprovalMode approvalMode,
    required String originatingMessageId,
    required String conversationId,
    required String changeSetId,
    required String decisionId,
    required String agentId,
    @Default('chat_suggestion') String source,
    @Default('task_agent') String appliedBy,
    // The values this approval set; null for a field the change left alone.
    bool? isChecked,
    String? title,
    bool? isArchived,
  }) = _ChecklistItemProvenance;

  factory ChecklistItemProvenance.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemProvenanceFromJson(json);
}
