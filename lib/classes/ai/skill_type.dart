import 'package:lotti/classes/ai_response_type.dart';

/// What a skill produces.
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
