import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/omlx_transcription_repository.dart';
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';

/// Whether transcribing with [model] on [provider] goes to a dedicated
/// speech-to-text engine — Whisper and its kin — rather than to a multimodal
/// model that listens to the audio under a prompt.
///
/// The distinction is what the transcript can know. A speech-to-text engine
/// returns what it heard, with at most a vocabulary hint, so a name it has
/// never seen comes back misspelled; a multimodal model reads the speech
/// dictionary and the task in its prompt and spells them as given. The
/// branches mirror the audio routes of `CloudInferenceRepository
/// .generateWithAudio`: everything this does not name goes to a chat model.
bool routesToSpeechToText(AiConfigInferenceProvider provider, String model) =>
    switch (provider.inferenceProviderType) {
      InferenceProviderType.whisper ||
      InferenceProviderType.sherpa ||
      InferenceProviderType.voxtral => true,
      InferenceProviderType.openAi =>
        OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(model),
      // A chat-audio Voxtral is routed to chat first, as the router does.
      InferenceProviderType.mistral =>
        !MistralInferenceRepository.isMistralChatAudioModel(model) &&
            MistralTranscriptionRepository.isMistralTranscriptionModel(model),
      InferenceProviderType.melious =>
        MeliousInferenceRepository.isMeliousTranscriptionModel(model),
      InferenceProviderType.omlx =>
        OmlxTranscriptionRepository.isOmlxTranscriptionModel(model),
      InferenceProviderType.alibaba ||
      InferenceProviderType.anthropic ||
      InferenceProviderType.gemini ||
      InferenceProviderType.genericOpenAi ||
      InferenceProviderType.nebiusAiStudio ||
      InferenceProviderType.openRouter ||
      InferenceProviderType.ollama => false,
    };
