import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_item.freezed.dart';
part 'checklist_item.g.dart';

@freezed
class ChecklistItemData with _$ChecklistItemData {
  const factory ChecklistItemData({
    required String title,
    required bool isChecked,
  }) = _ChecklistItemData;

  factory ChecklistItemData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDataFromJson(json);
}
