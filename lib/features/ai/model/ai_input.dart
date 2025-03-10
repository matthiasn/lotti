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
    required List<AiInputActionItemObject> actionItems,
    required List<AiInputLogEntryObject> logEntries,
  }) = _AiInputTaskObject;

  factory AiInputTaskObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputTaskObjectFromJson(json);
}

@freezed
class AiInputActionItemObject with _$AiInputActionItemObject {
  const factory AiInputActionItemObject({
    required String title,
    required bool completed,
    DateTime? deadline,
    DateTime? completionDate,
  }) = _AiInputActionItemObject;

  factory AiInputActionItemObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputActionItemObjectFromJson(json);
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
