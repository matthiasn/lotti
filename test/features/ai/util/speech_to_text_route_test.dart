import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/util/speech_to_text_route.dart';

import '../../agents/test_data/ai_config_factories.dart';

void main() {
  bool route(InferenceProviderType type, String model) => routesToSpeechToText(
    testInferenceProvider(inferenceProviderType: type),
    model,
  );

  group('routesToSpeechToText', () {
    for (final (type, model) in [
      (InferenceProviderType.whisper, 'whisper-large-v3'),
      (InferenceProviderType.sherpa, 'any-sherpa-model'),
      (InferenceProviderType.voxtral, 'voxtral-mini'),
      (InferenceProviderType.openAi, 'gpt-4o-transcribe'),
      (InferenceProviderType.mistral, 'voxtral-mini-latest'),
      (InferenceProviderType.melious, 'whisper-large-v3-turbo'),
      (InferenceProviderType.omlx, 'whisper-large-v3-turbo'),
    ]) {
      test('${type.name} $model is a speech-to-text engine', () {
        expect(route(type, model), isTrue);
      });
    }

    for (final (type, model) in [
      (InferenceProviderType.gemini, 'models/gemini-3-flash-preview'),
      (InferenceProviderType.openAi, 'gpt-4o-audio-preview'),
      // A chat-audio Voxtral goes to chat, though its name is a Voxtral's.
      (InferenceProviderType.mistral, 'voxtral-small-latest'),
      (InferenceProviderType.melious, 'voxtral-small-24b'),
      (InferenceProviderType.alibaba, 'qwen3-omni-flash'),
      (InferenceProviderType.openRouter, 'whisper-like-name'),
      (InferenceProviderType.ollama, 'gemma3'),
    ]) {
      test('${type.name} $model is a multimodal model', () {
        expect(route(type, model), isFalse);
      });
    }
  });
}
