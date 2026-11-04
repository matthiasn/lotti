import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';

import '../../agents/test_data/ai_config_factories.dart';

final AiConfigInferenceProvider _mistral = testInferenceProvider(
  id: 'mistral',
  inferenceProviderType: InferenceProviderType.mistral,
);
final AiConfigInferenceProvider _eleven = testInferenceProvider(
  id: 'eleven',
  inferenceProviderType: InferenceProviderType.elevenLabs,
);

void main() {
  group('TtsSettings defaults', () {
    test('default to the female default voice, default model, 1x speed', () {
      const settings = TtsSettings();
      expect(settings.voiceId, kDefaultTtsVoiceId);
      expect(settings.modelId, kDefaultTtsModelId);
      expect(settings.speed, kDefaultTtsSpeed);
    });
  });

  test('chat preparation is opt-in and survives unrelated preferences', () {
    const defaults = TtsSettings();
    expect(defaults.autoPrepareChatAudio, isFalse);
    final enabled = defaults.copyWith(autoPrepareChatAudio: true);
    expect(enabled, isNot(defaults));
    expect(enabled.copyWith(voiceId: 'M2').autoPrepareChatAudio, isTrue);
    expect(enabled.copyWith(autoPrepareChatAudio: false), defaults);
    expect(enabled, const TtsSettings(autoPrepareChatAudio: true));
    expect(
      enabled.hashCode,
      const TtsSettings(autoPrepareChatAudio: true).hashCode,
    );
  });

  group('clampSpeed', () {
    test('clamps below, within, and above the range', () {
      expect(TtsSettings.clampSpeed(0.1), kMinTtsSpeed);
      expect(TtsSettings.clampSpeed(1.25), 1.25);
      expect(TtsSettings.clampSpeed(9), kMaxTtsSpeed);
    });
  });

  group('copyWith', () {
    test('updates provided fields and clamps speed', () {
      const base = TtsSettings();
      final next = base.copyWith(voiceId: 'M2', speed: 5);
      expect(next.voiceId, 'M2');
      expect(next.speed, kMaxTtsSpeed);
      // Untouched field preserved.
      expect(next.modelId, kDefaultTtsModelId);
    });

    test('leaves speed unchanged when not provided', () {
      const base = TtsSettings(speed: 1.5);
      final next = base.copyWith(voiceId: 'F2');
      expect(next.speed, 1.5);
    });
  });

  group('kTtsSpeedSequence', () {
    test('is sorted, within bounds, and includes the default', () {
      final sorted = [...kTtsSpeedSequence]..sort();
      expect(kTtsSpeedSequence, sorted);
      expect(kTtsSpeedSequence.first, greaterThanOrEqualTo(kMinTtsSpeed));
      expect(kTtsSpeedSequence.last, lessThanOrEqualTo(kMaxTtsSpeed));
      expect(kTtsSpeedSequence, contains(kDefaultTtsSpeed));
    });
  });

  group('persistence keys', () {
    test('are stable string constants', () {
      expect(ttsVoiceIdKey, 'TTS_VOICE_ID');
      expect(ttsModelIdKey, 'TTS_MODEL_ID');
      expect(ttsSpeedKey, 'TTS_SPEED');
    });
  });

  group('cloud voice choices', () {
    test('Mistral keeps the bare language key, so earlier picks stay; '
        'any other provider is scoped by its own config id', () {
      expect(cloudVoiceChoiceKey(_mistral, 'de'), 'de');
      expect(cloudVoiceChoiceKey(_eleven, 'de'), 'eleven/de');
      // A second account of the same type keeps its own choice.
      expect(
        cloudVoiceChoiceKey(
          testInferenceProvider(
            id: 'eleven-work',
            inferenceProviderType: InferenceProviderType.elevenLabs,
          ),
          'de',
        ),
        'eleven-work/de',
      );
    });

    test('cloudVoiceFor reads only the choice of the asked provider', () {
      const settings = TtsSettings(
        cloudVoiceByLanguage: {'de': 'mistral-de', 'eleven/en': 'xi-en'},
      );
      expect(settings.cloudVoiceFor(_mistral, 'de'), 'mistral-de');
      expect(settings.cloudVoiceFor(_eleven, 'de'), isNull);
      expect(settings.cloudVoiceFor(_eleven, 'en'), 'xi-en');
      expect(settings.cloudVoiceFor(_mistral, 'en'), isNull);
    });
  });

  group('value semantics', () {
    test('equal settings are equal and share a hashCode', () {
      const a = TtsSettings(voiceId: 'F2', modelId: 'm1', speed: 1.5);
      const b = TtsSettings(voiceId: 'F2', modelId: 'm1', speed: 1.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString includes the field values', () {
      const settings = TtsSettings(voiceId: 'F2', modelId: 'm1', speed: 1.5);
      expect(
        settings.toString(),
        allOf(contains('F2'), contains('m1'), contains('1.5')),
      );
    });
  });
}
