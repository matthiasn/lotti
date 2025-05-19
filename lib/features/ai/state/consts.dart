import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

extension AiResponseTypeDisplay on AiResponseType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case AiResponseType.actionItemSuggestions:
        return l10n.aiResponseTypeActionItemSuggestions;
      case AiResponseType.taskSummary:
        return l10n.aiResponseTypeTaskSummary;
      case AiResponseType.imageAnalysis:
        return l10n.aiResponseTypeImageAnalysis;
      case AiResponseType.audioTranscription:
        return l10n.aiResponseTypeAudioTranscription;
    }
  }
}
