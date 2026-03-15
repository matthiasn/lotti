import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/l10n/app_localizations.dart';

const taskSummaryConst = 'TaskSummary';
const imageAnalysisConst = 'ImageAnalysis';
const audioTranscriptionConst = 'AudioTranscription';
const checklistUpdatesConst = 'ChecklistUpdates';
const promptGenerationConst = 'PromptGeneration';
const imagePromptGenerationConst = 'ImagePromptGeneration';
const imageGenerationConst = 'ImageGeneration';

// Ollama API constants
const ollamaChatEndpoint = '/api/chat';
const ollamaDefaultTimeoutSeconds = 120; // 2 minutes for regular requests
const ollamaImageAnalysisTimeoutSeconds =
    900; // 15 minutes for image analysis (large models can be very slow)
const ollamaMaxTemperature = 2.0;
const ollamaMinTemperature = 0.0;
const ollamaContentType = 'application/json';
const ollamaResponseIdPrefix = 'ollama-';

// Ollama Embedding API constants
const ollamaEmbedEndpoint = '/api/embed';
const ollamaEmbedTimeoutSeconds = 60;
const ollamaEmbedDefaultModel = 'mxbai-embed-large';

// Whisper API constants
const whisperTranscriptionTimeoutSeconds =
    600; // 10 minutes for audio transcription

// HTTP status codes
const httpStatusOk = 200;
const httpStatusNotFound = 404;
const httpStatusRequestTimeout = 408;

enum AiResponseType {
  @Deprecated(
    'Legacy type superseded by the agent system. '
    'Kept only for JSON/DB backwards-compatibility. '
    'Remove once a DB migration drops persisted taskSummary rows.',
  )
  @JsonValue(taskSummaryConst)
  taskSummary,
  @JsonValue(imageAnalysisConst)
  imageAnalysis,
  @JsonValue(audioTranscriptionConst)
  audioTranscription,
  @Deprecated(
    'Legacy type superseded by the agent system. '
    'Kept only for JSON/DB backwards-compatibility. '
    'Remove once a DB migration drops persisted checklistUpdates rows.',
  )
  @JsonValue(checklistUpdatesConst)
  checklistUpdates,
  @JsonValue(promptGenerationConst)
  promptGeneration,
  @JsonValue(imagePromptGenerationConst)
  imagePromptGeneration,
  @JsonValue(imageGenerationConst)
  imageGeneration,
}

extension AiResponseTypeDisplay on AiResponseType {
  String localizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.taskSummary:
        return l10n.aiResponseTypeTaskSummary;
      case AiResponseType.imageAnalysis:
        return l10n.aiResponseTypeImageAnalysis;
      case AiResponseType.audioTranscription:
        return l10n.aiResponseTypeAudioTranscription;
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.checklistUpdates:
        return l10n.aiResponseTypeChecklistUpdates;
      case AiResponseType.promptGeneration:
        return l10n.aiResponseTypePromptGeneration;
      case AiResponseType.imagePromptGeneration:
        return l10n.aiResponseTypeImagePromptGeneration;
      case AiResponseType.imageGeneration:
        return l10n.generateCoverArt;
    }
  }

  /// Returns the appropriate icon for this response type
  IconData get icon {
    switch (this) {
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.taskSummary:
        return Icons.summarize_outlined;
      case AiResponseType.imageAnalysis:
        return Icons.image_outlined;
      case AiResponseType.audioTranscription:
        return Icons.mic_outlined;
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.checklistUpdates:
        return Icons.checklist_rtl_outlined;
      case AiResponseType.promptGeneration:
        return Icons.auto_fix_high_outlined;
      case AiResponseType.imagePromptGeneration:
        return Icons.palette_outlined;
      case AiResponseType.imageGeneration:
        return Icons.auto_awesome_outlined;
    }
  }

  /// Returns true if this is a legacy type superseded by the agent system.
  /// Legacy types are kept only for JSON/DB backwards-compatibility and
  /// should not be used for new prompts or automatic execution.
  bool get isLegacyType =>
      // ignore: deprecated_member_use_from_same_package
      this == AiResponseType.taskSummary ||
      // ignore: deprecated_member_use_from_same_package
      this == AiResponseType.checklistUpdates ||
      this == AiResponseType.imageGeneration;

  /// Returns true if this is a prompt generation type (coding or image).
  /// These types share common behavior:
  /// - Triggered from audio entries (not task-level)
  /// - Use {{audioTranscript}} placeholder
  /// - Display via GeneratedPromptCard with copy functionality
  bool get isPromptGenerationType =>
      this == AiResponseType.promptGeneration ||
      this == AiResponseType.imagePromptGeneration;
}

enum SkillType {
  transcription,
  imageAnalysis,
  imageGeneration,
  promptGeneration,
  imagePromptGeneration,
}

/// Maps each [SkillType] to its corresponding [AiResponseType] so the
/// inference status system (Siri waveform animation) can track skill runs.
extension SkillTypeToResponseType on SkillType {
  AiResponseType get toResponseType => switch (this) {
    SkillType.transcription => AiResponseType.audioTranscription,
    SkillType.imageAnalysis => AiResponseType.imageAnalysis,
    SkillType.imageGeneration => AiResponseType.imageGeneration,
    SkillType.promptGeneration => AiResponseType.promptGeneration,
    SkillType.imagePromptGeneration => AiResponseType.imagePromptGeneration,
  };
}

enum ContextPolicy {
  none,
  dictionaryOnly,
  taskSummary,
  fullTask,
}
