import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_client.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';

/// SettingsDb key prefix for a Mistral provider's cached voice catalog; the
/// provider's config id completes it. Its catalog is the account's, whatever
/// the model.
const String voxtralVoiceCatalogKeyPrefix = 'TTS_VOXTRAL_VOICES_';

/// SettingsDb key prefix for an ElevenLabs provider's cached voice catalog;
/// the provider's config id and the model id complete it, because which
/// languages the voices speak is the model's.
const String elevenLabsVoiceCatalogKeyPrefix = 'TTS_ELEVENLABS_VOICES_';

/// The voice catalog of one cloud voice service — a provider and the
/// read-aloud model it runs — cached on this device.
///
/// A cached catalog younger than [CloudVoiceCatalog.maxAge] answers without
/// a request. An older one is refreshed, and kept when the refresh fails, so
/// voices still resolve offline. Only a device that has never fetched the
/// catalog needs the network for it.
///
/// The cache is device-local: it is the provider account's catalog, and the
/// account's credentials do not sync either. It remembers which account it
/// was fetched for ([accountFingerprint]): a provider edited to another
/// account or base URL never answers from the old account's voices, whose
/// ids — a cloned voice's above all — the new account may not have.
class CloudVoiceCatalogRepository {
  CloudVoiceCatalogRepository({
    required this._settingsDb,
    required this._clients,
  });

  final SettingsDb _settingsDb;

  /// The speech client per provider type; a type without one has no voices.
  final Map<InferenceProviderType, CloudTtsClient> _clients;

  /// The catalog for [provider] running [model], fetched only when the cache
  /// is missing or stale, or when [refresh] asks for it. Throws the fetch's
  /// [CloudTtsException] only when there is no cached catalog to fall back
  /// to, and [ArgumentError] for a provider type without a speech client.
  Future<CloudVoiceCatalog> catalogFor(
    AiConfigInferenceProvider provider,
    AiConfigModel model, {
    bool refresh = false,
  }) async {
    final client = _clients[provider.inferenceProviderType];
    if (client == null) {
      throw ArgumentError.value(
        provider.inferenceProviderType,
        'provider',
        'has no speech client',
      );
    }
    final key = cacheKey(provider, model);
    final account = accountFingerprint(provider);
    final stored = _decode(await _settingsDb.itemByKey(key));
    // Another account's catalog is no cache at all. One stored before the
    // account was recorded is most likely this account's: it is refreshed
    // first, and only answers when the refresh fails.
    final ours = stored != null && stored.account == account;
    final unrecorded = stored != null && stored.account == null;
    final cached = ours || unrecorded ? stored.catalog : null;
    if (ours && !refresh && !stored.catalog.isStale(clock.now())) {
      return stored.catalog;
    }
    try {
      final fetched = await client.fetchVoices(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        model: model.providerModelId,
      );
      await _settingsDb.saveSettingsItem(
        key,
        jsonEncode({...fetched.toJson(), _accountField: account}),
      );
      return fetched;
    } on CloudTtsException {
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Identifies the account [provider] reaches — its base URL and key —
  /// without holding either: the first 16 hex digits of their SHA-256.
  static String accountFingerprint(AiConfigInferenceProvider provider) => sha256
      .convert(utf8.encode('${provider.baseUrl}\n${provider.apiKey}'))
      .toString()
      .substring(0, 16);

  static const String _accountField = 'account';

  /// Where [provider]'s catalog for [model] is cached.
  static String cacheKey(
    AiConfigInferenceProvider provider,
    AiConfigModel model,
  ) => switch (provider.inferenceProviderType) {
    InferenceProviderType.elevenLabs =>
      '$elevenLabsVoiceCatalogKeyPrefix${provider.id}/'
          '${model.providerModelId}',
    _ => '$voxtralVoiceCatalogKeyPrefix${provider.id}',
  };

  static ({CloudVoiceCatalog catalog, String? account})? _decode(
    String? stored,
  ) {
    if (stored == null) return null;
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return (
        catalog: CloudVoiceCatalog.fromJson(json),
        account: json[_accountField] as String?,
      );
    } on Object {
      // A cache this build cannot read is no cache; the next fetch replaces it.
      return null;
    }
  }
}
