import 'package:freezed_annotation/freezed_annotation.dart';

const actionItemSuggestionsConst = 'ActionItemSuggestions';
const taskSummaryConst = 'TaskSummary';
const imageAnalysisConst = 'ImageAnalysis';
const audioTranscriptionConst = 'AudioTranscription';

enum AiResponseType {
  @JsonValue(actionItemSuggestionsConst)
  actionItemSuggestions,
  @JsonValue(taskSummaryConst)
  taskSummary,
  @JsonValue(imageAnalysisConst)
  imageAnalysis,
  @JsonValue(audioTranscriptionConst)
  audioTranscription,
}
