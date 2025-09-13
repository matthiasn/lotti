import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklist_data.freezed.dart';
part 'checklist_data.g.dart';

@freezed
abstract class ChecklistData with _$ChecklistData {
  const factory ChecklistData({
    required String title,
    required List<String> linkedChecklistItems,
    required List<String> linkedTasks,
  }) = _ChecklistData;

  factory ChecklistData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistDataFromJson(json);
}
