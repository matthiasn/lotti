import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';
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

  /// Whether the voice itself was picked before storage finished loading:
  /// only then does the stored voice give way to the state's.
  bool _voiceChanged = false;

  /// Whether storage was read, so the voice in the state is the stored one
  /// and not a default standing in for it. [matchVoice] moves no voice it
  /// does not know.
  bool _voiceKnown = false;

  /// Settles once storage was read, or could not be: what [matchVoice]
  /// waits for, so it never judges a voice by the defaults.
  Future<void> _loaded = Future<void>.value();

  @override
  TtsSettings build() {
    // Return defaults synchronously; refine from storage once loaded.
    _loaded = _load();
    return const TtsSettings();
  }

  Future<void> _load() async {
    try {
      final stored = await ref.read(settingsDbProvider).itemsByKeys({
        ttsVoiceIdKey,
        ttsVoicePickedKey,
        ttsModelIdKey,
        ttsSpeedKey,
        ttsAutoPrepareChatAudioKey,
        ttsCloudVoicesKey,
      });
      const defaults = TtsSettings();
      final storedVoice = stored[ttsVoiceIdKey];
      final voiceId = storedVoice ?? defaults.voiceId;
      // A voice stored before picks were noted was chosen by hand — nothing
      // else wrote one then, the default included — and is never matched
      // away. One that followed her character is stored as not picked
      // ([matchVoice]).
      final voicePicked =
          stored[ttsVoicePickedKey] == 'true' ||
          (stored[ttsVoicePickedKey] == null && storedVoice != null);
      _voiceKnown = true;
      if (_userChanged) {
        // What was changed meanwhile stands; a voice left alone is still
        // the stored one, with its pick.
        if (!_voiceChanged) {
          state = state.copyWith(voiceId: voiceId, voicePicked: voicePicked);
        }
        return;
      }
      final storedSpeed = double.tryParse(stored[ttsSpeedKey] ?? '');
      state = TtsSettings(
        autoPrepareChatAudio: stored[ttsAutoPrepareChatAudioKey] == 'true',
        cloudVoiceByLanguage: _decodeVoices(stored[ttsCloudVoicesKey]),
        voiceId: voiceId,
        voicePicked: voicePicked,
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

  /// Selects [voiceId] as the user's own pick and persists it: from now on
  /// the voice no longer follows the companion's character ([matchVoice]).
  void setVoice(String voiceId) {
    _userChanged = true;
    _voiceChanged = true;
    state = state.copyWith(voiceId: voiceId, voicePicked: true);
    unawaited(_saveVoice(voiceId, picked: true));
  }

  /// Stores the voice, then whether it is the user's own pick.
  Future<void> _saveVoice(String voiceId, {required bool picked}) async {
    final settingsDb = ref.read(settingsDbProvider);
    await settingsDb.saveSettingsItem(ttsVoiceIdKey, voiceId);
    await settingsDb.saveSettingsItem(ttsVoicePickedKey, picked.toString());
  }

  /// Has the voice follow a companion of [gender] — the grandpa speaks with
  /// a male voice, Lotti with a female one — keeping the voice's number.
  /// Nothing changes once the user picked a voice themselves, or when the
  /// voice is of [gender] already.
  ///
  /// Waits for storage first: a pick is only known once it was read, and a
  /// match made on the defaults would overwrite it — so where storage could
  /// not be read, nothing is matched. The match is stored as not picked, so
  /// after a restart the voice goes on following.
  Future<void> matchVoice(TtsVoiceGender gender) async {
    await _loaded;
    if (!ref.mounted || !_voiceKnown || state.voicePicked) return;
    final matched = ttsVoiceOfGender(state.voiceId, gender).id;
    if (matched == state.voiceId) return;
    _userChanged = true;
    state = state.copyWith(voiceId: matched);
    await _saveVoice(matched, picked: false);
  }

  /// Selects [modelId] and persists it.
  void setModel(String modelId) {
    _userChanged = true;
    state = state.copyWith(modelId: modelId);
    unawaited(
      ref.read(settingsDbProvider).saveSettingsItem(ttsModelIdKey, modelId),
    );
  }

  /// Chooses [voiceId] as the cloud voice for [languageCode] on [provider],
  /// or clears the choice when it is `null` so the language's default voice
  /// speaks again. Another provider's choice for the language is left as it
  /// is.
  void setCloudVoice(
    AiConfigInferenceProvider provider,
    String languageCode,
    String? voiceId,
  ) {
    _userChanged = true;
    final voices = Map<String, String>.of(state.cloudVoiceByLanguage);
    final key = cloudVoiceChoiceKey(provider, languageCode);
    if (voiceId == null) {
      voices.remove(key);
    } else {
      voices[key] = voiceId;
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
