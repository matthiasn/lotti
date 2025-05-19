import 'package:freezed_annotation/freezed_annotation.dart';

const actionItemSuggestions = 'ActionItemSuggestions';
const taskSummary = 'TaskSummary';
const imageAnalysis = 'ImageAnalysis';
const audioTranscription = 'AudioTranscription';

enum AiResponseType {
  @JsonValue(actionItemSuggestions)
  actionItemSuggestions,
  @JsonValue(taskSummary)
  taskSummary,
  @JsonValue(imageAnalysis)
  imageAnalysis,
  @JsonValue(audioTranscription)
  audioTranscription,
}
