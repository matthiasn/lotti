import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';

void main() {
  group('TtsSettings defaults', () {
    test('default to the female default voice, default model, 1x speed', () {
      const settings = TtsSettings();
      expect(settings.voiceId, kDefaultTtsVoiceId);
      expect(settings.modelId, kDefaultTtsModelId);
      expect(settings.speed, kDefaultTtsSpeed);
      expect(settings.voice.gender, TtsVoiceGender.female);
      expect(settings.model.id, kDefaultTtsModelId);
    });

    test('resolve voice/model getters from ids, including stale ids', () {
      const settings = TtsSettings(voiceId: 'F4', modelId: 'gone');
      expect(settings.voice.id, 'F4');
      // Unknown model id resolves to the default, not a crash.
      expect(settings.model.id, kDefaultTtsModelId);
    });
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
}
