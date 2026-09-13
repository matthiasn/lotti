import 'package:flutter/foundation.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';

/// SettingsDb keys for persisted TTS preferences.
const String ttsVoiceIdKey = 'TTS_VOICE_ID';
const String ttsModelIdKey = 'TTS_MODEL_ID';
const String ttsSpeedKey = 'TTS_SPEED';
const String ttsAutoPrepareChatAudioKey = 'TTS_AUTO_PREPARE_CHAT_AUDIO';

/// Playback speed bounds and default, matching the recordings audio player's
/// range so the two players feel consistent.
const double kMinTtsSpeed = 0.5;
const double kMaxTtsSpeed = 2;
const double kDefaultTtsSpeed = 1;

/// Discrete speed steps offered by the speed selector (mirrors the existing
/// audio player's sequence).
const List<double> kTtsSpeedSequence = <double>[
  0.5,
  0.75,
  1,
  1.25,
  1.5,
  1.75,
  2,
];

/// User-configurable TTS preferences, persisted via `SettingsDb`.
@immutable
class TtsSettings {
  const TtsSettings({
    this.voiceId = kDefaultTtsVoiceId,
    this.modelId = kDefaultTtsModelId,
    this.speed = kDefaultTtsSpeed,
    this.autoPrepareChatAudio = false,
  });

  /// Selected Supertonic voice id (e.g. `F1`).
  final String voiceId;

  /// Selected model id (e.g. `supertonic-3`).
  final String modelId;

  /// Playback rate multiplier in `[kMinTtsSpeed, kMaxTtsSpeed]` (1.0 =
  /// natural). [copyWith] clamps on assignment.
  final double speed;

  /// Opt-in preparation of published chat replies; never starts playback.
  final bool autoPrepareChatAudio;

  /// Clamps an arbitrary speed into the supported range.
  static double clampSpeed(double value) =>
      value.clamp(kMinTtsSpeed, kMaxTtsSpeed);

  TtsSettings copyWith({
    String? voiceId,
    String? modelId,
    double? speed,
    bool? autoPrepareChatAudio,
  }) {
    return TtsSettings(
      autoPrepareChatAudio: autoPrepareChatAudio ?? this.autoPrepareChatAudio,
      voiceId: voiceId ?? this.voiceId,
      modelId: modelId ?? this.modelId,
      speed: speed == null ? this.speed : clampSpeed(speed),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TtsSettings &&
      other.voiceId == voiceId &&
      other.modelId == modelId &&
      other.speed == speed &&
      other.autoPrepareChatAudio == autoPrepareChatAudio;

  @override
  int get hashCode =>
      Object.hash(voiceId, modelId, speed, autoPrepareChatAudio);

  @override
  String toString() =>
      'TtsSettings(voiceId: $voiceId, modelId: $modelId, speed: $speed, '
      'autoPrepareChatAudio: $autoPrepareChatAudio)';
}
