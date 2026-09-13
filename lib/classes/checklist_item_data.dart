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
    for (final approval in approvalHistory.reversed) {
      if (approval.isChecked != null) {
        return approval.source == 'chat_suggestion' &&
                approval.approvedBy == 'user' &&
                approval.isChecked == isChecked &&
                approval.approvedAt == checkedAt
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
    bool? isChecked,
  }) = _ChecklistItemProvenance;

  factory ChecklistItemProvenance.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemProvenanceFromJson(json);
}
