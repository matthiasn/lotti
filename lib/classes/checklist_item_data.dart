import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_item_data.freezed.dart';
part 'checklist_item_data.g.dart';

@freezed
class ChecklistItemData with _$ChecklistItemData {
  const factory ChecklistItemData({
    required String title,
    required bool isChecked,
    required List<String> linkedChecklists,
    String? id,
  }) = _ChecklistItemData;

  factory ChecklistItemData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDataFromJson(json);
}
