import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_input.freezed.dart';
part 'ai_input.g.dart';

@freezed
abstract class AiInputTaskObject with _$AiInputTaskObject {
  const factory AiInputTaskObject({
    required String title,
    required String status,
    required String estimatedDuration,
    required String timeSpent,
    required DateTime creationDate,
    required List<AiActionItem> actionItems,
    required List<AiInputLogEntryObject> logEntries,
    String? languageCode,
  }) = _AiInputTaskObject;

  factory AiInputTaskObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputTaskObjectFromJson(json);
}

@freezed
abstract class AiActionItem with _$AiActionItem {
  const factory AiActionItem({
    required String title,
    required bool completed,
    String? id,
    DateTime? deadline,
    DateTime? completionDate,
  }) = _AiActionItem;

  factory AiActionItem.fromJson(Map<String, dynamic> json) =>
      _$AiActionItemFromJson(json);
}

@freezed
abstract class AiInputLogEntryObject with _$AiInputLogEntryObject {
  const factory AiInputLogEntryObject({
    required DateTime creationTimestamp,
    required String loggedDuration,
    required String text,
    String? audioTranscript,
    String? transcriptLanguage,
    String? entryType,
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

/// Context for a linked task (parent or child) to be injected into AI prompts.
/// Contains distilled information about related work.
@freezed
abstract class AiLinkedTaskContext with _$AiLinkedTaskContext {
  const factory AiLinkedTaskContext({
    required String id,
    required String title,
    required String status,
    required DateTime statusSince,
    required String priority,
    required String estimate,
    required String timeSpent,
    required DateTime createdAt,
    required List<Map<String, String>> labels,
    String? languageCode,
    String? latestSummary,
  }) = _AiLinkedTaskContext;

  factory AiLinkedTaskContext.fromJson(Map<String, dynamic> json) =>
      _$AiLinkedTaskContextFromJson(json);
}
