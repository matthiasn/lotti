import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/providers/service_providers.dart';

/// Holds the user's TTS preferences — selected voice, model, and playback
/// speed and automatic chat audio preparation — persisted locally via [SettingsDb].
///
/// These are device-local preferences (which voice sounds best on this
/// device, how fast to read), so unlike theming they are intentionally not
/// enqueued for cross-device sync.
final ttsSettingsControllerProvider =
    NotifierProvider<TtsSettingsController, TtsSettings>(
      TtsSettingsController.new,
      name: 'ttsSettingsControllerProvider',
    );

class TtsSettingsController extends Notifier<TtsSettings> {
  /// Set once the user changes any setting, so a late-resolving [_load] never
  /// clobbers an interaction made before storage finished loading.
  bool _userChanged = false;

  @override
  TtsSettings build() {
    // Return defaults synchronously; refine from storage once loaded.
    unawaited(_load());
    return const TtsSettings();
  }

  Future<void> _load() async {
    try {
      final stored = await ref.read(settingsDbProvider).itemsByKeys({
        ttsVoiceIdKey,
        ttsModelIdKey,
        ttsSpeedKey,
        ttsAutoPrepareChatAudioKey,
        ttsCloudVoicesKey,
      });
      if (_userChanged) return;
      const defaults = TtsSettings();
      final storedSpeed = double.tryParse(stored[ttsSpeedKey] ?? '');
      state = TtsSettings(
        autoPrepareChatAudio: stored[ttsAutoPrepareChatAudioKey] == 'true',
        cloudVoiceByLanguage: _decodeVoices(stored[ttsCloudVoicesKey]),
        voiceId: stored[ttsVoiceIdKey] ?? defaults.voiceId,
        modelId: stored[ttsModelIdKey] ?? defaults.modelId,
        speed: storedSpeed == null
            ? defaults.speed
            : TtsSettings.clampSpeed(storedSpeed),
      );
    } on Object {
      // Settings storage unavailable — keep the default preferences rather
      // than failing the card that reads them.
    }
  }

  /// Enables device-local preparation without enabling automatic playback.
  void setAutoPrepareChatAudio({required bool enabled}) {
    _userChanged = true;
    state = state.copyWith(autoPrepareChatAudio: enabled);
    unawaited(
      ref
          .read(settingsDbProvider)
          .saveSettingsItem(
            ttsAutoPrepareChatAudioKey,
            enabled.toString(),
          ),
    );
  }

  /// Selects [voiceId] and persists it.
  void setVoice(String voiceId) {
    _userChanged = true;
    state = state.copyWith(voiceId: voiceId);
    unawaited(
      ref.read(settingsDbProvider).saveSettingsItem(ttsVoiceIdKey, voiceId),
    );
  }

  /// Selects [modelId] and persists it.
  void setModel(String modelId) {
    _userChanged = true;
    state = state.copyWith(modelId: modelId);
    unawaited(
      ref.read(settingsDbProvider).saveSettingsItem(ttsModelIdKey, modelId),
    );
  }

  /// Chooses [voiceId] as the cloud voice for [languageCode], or clears the
  /// choice when it is `null` so the language's default voice speaks again.
  void setCloudVoice(String languageCode, String? voiceId) {
    _userChanged = true;
    final voices = Map<String, String>.of(state.cloudVoiceByLanguage);
    if (voiceId == null) {
      voices.remove(languageCode);
    } else {
      voices[languageCode] = voiceId;
    }
    state = state.copyWith(cloudVoiceByLanguage: voices);
    // Saves queue behind each other, so the last choice is the one stored.
    final encoded = jsonEncode(voices);
    final settingsDb = ref.read(settingsDbProvider);
    _cloudVoicesSave = _cloudVoicesSave
        .then((_) => settingsDb.saveSettingsItem(ttsCloudVoicesKey, encoded))
        // Storage unavailable: the choice holds for this session, as when
        // loading fails.
        .then<void>((_) {}, onError: (Object _) {});
  }

  Future<void> _cloudVoicesSave = Future<void>.value();

  static Map<String, String> _decodeVoices(String? stored) {
    if (stored == null) return const <String, String>{};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return const <String, String>{};
      return <String, String>{
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && value is String) key: value,
      };
    } on FormatException {
      return const <String, String>{};
    }
  }

  /// Sets the playback [speed] (clamped to the supported range) and persists
  /// it.
  void setSpeed(double speed) {
    _userChanged = true;
    final clamped = TtsSettings.clampSpeed(speed);
    state = state.copyWith(speed: clamped);
    unawaited(
      ref
          .read(settingsDbProvider)
          .saveSettingsItem(ttsSpeedKey, clamped.toString()),
    );
  }
}
