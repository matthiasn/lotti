import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_input.freezed.dart';
part 'ai_input.g.dart';

/// Distilled, JSON-serializable snapshot of a task injected into AI prompts.
///
/// Built from the live task entity and embedded in the prompt as the task
/// context the model reasons over (checklist items, time logs, due date, etc.).
/// Durations are pre-formatted strings, not raw values, so the model sees them
/// verbatim.
@freezed
abstract class AiInputTaskObject with _$AiInputTaskObject {
  const factory AiInputTaskObject({
    required String title,
    required String status,
    required String priority,
    required String estimatedDuration,
    required String timeSpent,
    required DateTime creationDate,
    required List<AiActionItem> actionItems,
    required List<AiInputLogEntryObject> logEntries,
    DateTime? dueDate,
    String? languageCode,
  }) = _AiInputTaskObject;

  factory AiInputTaskObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputTaskObjectFromJson(json);
}

/// A single checklist item inside an [AiInputTaskObject].
///
/// Doubles as the shape the model emits when proposing checklist changes, so
/// the function handlers can round-trip suggestions back into real checklist
/// items.
@freezed
abstract class AiActionItem with _$AiActionItem {
  const factory AiActionItem({
    required String title,
    required bool completed,
    @Default(false) bool isArchived,
    String? id,
    DateTime? deadline,
    DateTime? completionDate,
    String? checkedBy,
    DateTime? checkedAt,
  }) = _AiActionItem;

  factory AiActionItem.fromJson(Map<String, dynamic> json) =>
      _$AiActionItemFromJson(json);
}

/// A single journal/log entry attached to a task, as seen by the model inside
/// an [AiInputTaskObject]. Carries the pre-formatted logged duration plus any
/// audio transcript so the prompt can reference past activity. Image entries
/// additionally nest their AI analysis results (summary, OCR, …) in
/// [aiResponses] so the model can reason over extracted image content.
@freezed
abstract class AiInputLogEntryObject with _$AiInputLogEntryObject {
  const factory AiInputLogEntryObject({
    required DateTime creationTimestamp,
    required String loggedDuration,
    required String text,
    String? audioTranscript,
    String? transcriptLanguage,
    String? entryType,
    // Omitted from JSON when null so text/audio entries don't pay for the
    // key on every prompt; only image entries with analyses carry it.
    @JsonKey(includeIfNull: false) List<AiInputAiResponseObject>? aiResponses,
  }) = _AiInputLogEntryObject;

  factory AiInputLogEntryObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputLogEntryObjectFromJson(json);
}

/// One AI analysis response nested under an [AiInputLogEntryObject] — e.g. an
/// image's brief summary or its full OCR extraction. [model] identifies which
/// analysis produced [text] (summary vs OCR models differ), and [generatedAt]
/// is when the analysis ran.
@freezed
abstract class AiInputAiResponseObject with _$AiInputAiResponseObject {
  const factory AiInputAiResponseObject({
    required String model,
    required DateTime generatedAt,
    required String text,
  }) = _AiInputAiResponseObject;

  factory AiInputAiResponseObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputAiResponseObjectFromJson(json);
}

/// Wrapper around a list of [AiActionItem]s, used as the structured-output
/// schema when the model returns a full set of suggested checklist items.
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
