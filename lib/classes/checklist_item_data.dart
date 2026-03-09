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
  }) = _ChecklistItemData;

  factory ChecklistItemData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDataFromJson(json);
}
