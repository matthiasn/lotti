import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_input.freezed.dart';
part 'ai_input.g.dart';

@freezed
class AiInputTaskObject with _$AiInputTaskObject {
  const factory AiInputTaskObject({
    required String title,
    required String status,
    required Duration estimatedDuration,
    required Duration timeSpent,
    required DateTime creationDate,
    required List<AiActionItem> actionItems,
    required List<AiInputLogEntryObject> logEntries,
  }) = _AiInputTaskObject;

  factory AiInputTaskObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputTaskObjectFromJson(json);
}

@freezed
class AiActionItem with _$AiActionItem {
  const factory AiActionItem({
    required String title,
    required bool completed,
    DateTime? deadline,
    DateTime? completionDate,
  }) = _AiActionItem;

  factory AiActionItem.fromJson(Map<String, dynamic> json) =>
      _$AiActionItemFromJson(json);
}

@freezed
class AiInputLogEntryObject with _$AiInputLogEntryObject {
  const factory AiInputLogEntryObject({
    required DateTime creationTimestamp,
    required Duration loggedDuration,
    required String text,
  }) = _AiInputLogEntryObject;

  factory AiInputLogEntryObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputLogEntryObjectFromJson(json);
}

@freezed
abstract class AiInputActionItemsList with _$AiInputActionItemsList {
  const factory AiInputActionItemsList({
    required List<AiActionItem> items,
  }) = _AiInputActionItemsList;

  factory AiInputActionItemsList.fromJson(Map<String, dynamic> json) =>
      _$AiInputActionItemsListFromJson(json);
}
