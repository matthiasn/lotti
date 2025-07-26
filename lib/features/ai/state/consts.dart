import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/l10n/app_localizations.dart';

const actionItemSuggestionsConst = 'ActionItemSuggestions';
const taskSummaryConst = 'TaskSummary';
const imageAnalysisConst = 'ImageAnalysis';
const audioTranscriptionConst = 'AudioTranscription';

// Ollama API constants
const ollamaDefaultTimeoutSeconds = 120; // 2 minutes for regular requests
const ollamaImageAnalysisTimeoutSeconds =
    900; // 15 minutes for image analysis (large models can be very slow)
const ollamaMaxTemperature = 2.0;
const ollamaMinTemperature = 0.0;
const ollamaContentType = 'application/json';
const ollamaGenerateEndpoint = '/api/generate';

// HTTP status codes
const httpStatusOk = 200;
const httpStatusBadRequest = 400;
const httpStatusNotFound = 404;
const httpStatusInternalServerError = 500;
const httpStatusServiceUnavailable = 503;
const httpStatusRequestTimeout = 408;

enum AiResponseType {
  @JsonValue(actionItemSuggestionsConst)
  @Deprecated('no longer supported')
  // TODO(matthiasn): remove after some deprecation period
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
      // ignore: deprecated_member_use_from_same_package
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
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.actionItemSuggestions:
        return Icons.checklist_outlined;
      case AiResponseType.imageAnalysis:
        return Icons.image_outlined;
      case AiResponseType.audioTranscription:
        return Icons.mic_outlined;
    }
  }
}
