import 'package:freezed_annotation/freezed_annotation.dart';

/// JSON values of [AiResponseType], also the strings persisted in the
/// journal database.
const taskSummaryConst = 'TaskSummary';
const imageAnalysisConst = 'ImageAnalysis';
const audioTranscriptionConst = 'AudioTranscription';
const checklistUpdatesConst = 'ChecklistUpdates';
const promptGenerationConst = 'PromptGeneration';
const imagePromptGenerationConst = 'ImagePromptGeneration';
const imageGenerationConst = 'ImageGeneration';
const audioSummaryConst = 'AudioSummary';
const pullRequestSummaryConst = 'PullRequestSummary';

/// The kind of AI response an entry holds. Persisted, so values are only
/// ever deprecated, never removed.
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

  /// A short summary of a merged or closed GitHub pull request, linked to its
  /// pull request entry and read as its TL;DR in task contexts. Its `prompt`
  /// is the pull request content it summarises (`pullRequestSummaryInput`),
  /// which is how a reader tells whether it still matches.
  @JsonValue(pullRequestSummaryConst)
  pullRequestSummary,
}
