import 'dart:async';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_settings_controller.g.dart';

/// Holds the user's TTS preferences — selected voice, model, and playback
/// speed — persisted locally via [SettingsDb].
///
/// These are device-local preferences (which voice sounds best on this
/// device, how fast to read), so unlike theming they are intentionally not
/// enqueued for cross-device sync.
@Riverpod(keepAlive: true)
class TtsSettingsController extends _$TtsSettingsController {
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
      final stored = await getIt<SettingsDb>().itemsByKeys({
        ttsVoiceIdKey,
        ttsModelIdKey,
        ttsSpeedKey,
      });
      if (_userChanged) return;
      const defaults = TtsSettings();
      final storedSpeed = double.tryParse(stored[ttsSpeedKey] ?? '');
      state = TtsSettings(
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

  /// Selects [voiceId] and persists it.
  void setVoice(String voiceId) {
    _userChanged = true;
    state = state.copyWith(voiceId: voiceId);
    unawaited(getIt<SettingsDb>().saveSettingsItem(ttsVoiceIdKey, voiceId));
  }

  /// Selects [modelId] and persists it.
  void setModel(String modelId) {
    _userChanged = true;
    state = state.copyWith(modelId: modelId);
    unawaited(getIt<SettingsDb>().saveSettingsItem(ttsModelIdKey, modelId));
  }

  /// Sets the playback [speed] (clamped to the supported range) and persists
  /// it.
  void setSpeed(double speed) {
    _userChanged = true;
    final clamped = TtsSettings.clampSpeed(speed);
    state = state.copyWith(speed: clamped);
    unawaited(
      getIt<SettingsDb>().saveSettingsItem(ttsSpeedKey, clamped.toString()),
    );
  }
}
