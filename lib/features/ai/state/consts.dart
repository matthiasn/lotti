import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

const taskSummaryConst = 'TaskSummary';
const imageAnalysisConst = 'ImageAnalysis';
const audioTranscriptionConst = 'AudioTranscription';
const checklistUpdatesConst = 'ChecklistUpdates';
const promptGenerationConst = 'PromptGeneration';
const imagePromptGenerationConst = 'ImagePromptGeneration';
const imageGenerationConst = 'ImageGeneration';
const audioSummaryConst = 'AudioSummary';

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

  /// A three-tier summary of an audio recording, produced after
  /// transcription and linked to the audio entry. Carries a one-liner and a
  /// TLDR on `AiResponseData` alongside the full markdown body.
  @JsonValue(audioSummaryConst)
  audioSummary,
}

extension AiResponseTypeDisplay on AiResponseType {
  /// Returns the appropriate icon for this response type
  IconData get icon {
    switch (this) {
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.taskSummary:
        return LottiIcons.summarize;
      case AiResponseType.imageAnalysis:
        return LottiIcons.image;
      case AiResponseType.audioTranscription:
        return LottiIcons.mic;
      // ignore: deprecated_member_use_from_same_package
      case AiResponseType.checklistUpdates:
        return LottiIcons.checkAll;
      case AiResponseType.promptGeneration:
        return LottiIcons.magic;
      case AiResponseType.imagePromptGeneration:
        return LottiIcons.palette;
      case AiResponseType.imageGeneration:
        return LottiIcons.aiSpark;
      case AiResponseType.audioSummary:
        return LottiIcons.summarize;
    }
  }

  /// Returns true if this is a legacy type superseded by the agent system.
  /// Legacy types are kept only for JSON/DB backwards-compatibility and
  /// should not be used for new prompts or automatic execution.
  ///
  /// [AiResponseType.imageGeneration] is intentionally listed here even
  /// though the enum value is not `@Deprecated`: prompt-driven image
  /// generation was superseded by the cover-art skill
  /// (`triggerSkillProvider`), which still constructs the enum value when
  /// persisting its responses — so the value stays current while the
  /// prompt-execution path for it is gated off.
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
  audioSummary,
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
    SkillType.audioSummary => AiResponseType.audioSummary,
  };
}

enum ContextPolicy {
  none,
  dictionaryOnly,
  taskSummary,
  fullTask,
}
