import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/l10n/app_localizations.dart';

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

  /// Returns the appropriate icon for this response type
  IconData get icon {
    switch (this) {
      case AiResponseType.taskSummary:
        return Icons.summarize_outlined;
      case AiResponseType.actionItemSuggestions:
        return Icons.checklist_outlined;
      case AiResponseType.imageAnalysis:
        return Icons.image_outlined;
      case AiResponseType.audioTranscription:
        return Icons.mic_outlined;
    }
  }
}
