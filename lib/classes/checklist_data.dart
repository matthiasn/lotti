import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_data.freezed.dart';
part 'checklist_data.g.dart';

@freezed
class ChecklistData with _$ChecklistData {
  const factory ChecklistData({
    required String title,
    required bool isChecked,
  }) = _ChecklistData;

  factory ChecklistData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistDataFromJson(json);
}
