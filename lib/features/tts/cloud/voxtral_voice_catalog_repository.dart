import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tts/cloud/voxtral_tts_service.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';

/// SettingsDb key prefix for a provider's cached voice catalog; the
/// provider's config id completes it.
const String voxtralVoiceCatalogKeyPrefix = 'TTS_VOXTRAL_VOICES_';

/// The voice catalog of one Mistral provider, cached on this device.
///
/// A cached catalog younger than [VoxtralVoiceCatalog.maxAge] answers without
/// a request. An older one is refreshed, and kept when the refresh fails, so
/// voices still resolve offline. Only a device that has never fetched the
/// catalog needs the network for it.
///
/// The cache is device-local: it is the provider account's catalog, and the
/// account's credentials do not sync either.
class VoxtralVoiceCatalogRepository {
  VoxtralVoiceCatalogRepository({
    required this._settingsDb,
    required this._service,
  });

  final SettingsDb _settingsDb;
  final VoxtralTtsService _service;

  /// The catalog for [provider], fetched only when the cache is missing or
  /// stale, or when [refresh] asks for it. Throws the fetch's
  /// [VoxtralTtsException] only when there is no cached catalog to fall
  /// back to.
  Future<VoxtralVoiceCatalog> catalogFor(
    AiConfigInferenceProvider provider, {
    bool refresh = false,
  }) async {
    final key = '$voxtralVoiceCatalogKeyPrefix${provider.id}';
    final cached = _decode(await _settingsDb.itemByKey(key));
    if (cached != null && !refresh && !cached.isStale(clock.now())) {
      return cached;
    }
    try {
      final fetched = await _service.fetchVoices(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
      );
      await _settingsDb.saveSettingsItem(key, jsonEncode(fetched.toJson()));
      return fetched;
    } on VoxtralTtsException {
      if (cached != null) return cached;
      rethrow;
    }
  }

  static VoxtralVoiceCatalog? _decode(String? stored) {
    if (stored == null) return null;
    try {
      return VoxtralVoiceCatalog.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    } on Object {
      // A cache this build cannot read is no cache; the next fetch replaces it.
      return null;
    }
  }
}
