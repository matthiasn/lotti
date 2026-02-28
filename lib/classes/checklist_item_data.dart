import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_item_data.freezed.dart';
part 'checklist_item_data.g.dart';

/// Who last changed the `isChecked` field on a checklist item.
enum CheckedBySource {
  /// Set by the user via the UI.
  user,

  /// Set by an AI agent tool call.
  agent,
}

@freezed
abstract class ChecklistItemData with _$ChecklistItemData {
  const factory ChecklistItemData({
    required String title,
    required bool isChecked,
    required List<String> linkedChecklists,
    @Default(false) bool isArchived,
    String? id,
    @Default(CheckedBySource.user)
    @JsonKey(unknownEnumValue: CheckedBySource.user)
    CheckedBySource checkedBy,
    DateTime? checkedAt,
  }) = _ChecklistItemData;

  factory ChecklistItemData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDataFromJson(json);
}
