import 'package:collection/collection.dart';
import 'package:lotti/classes/ai/ai_config.dart';

/// The type a stored configuration is filed under.
AiConfigType aiConfigTypeOf(AiConfig config) => config.map(
  inferenceProvider: (_) => AiConfigType.inferenceProvider,
  model: (_) => AiConfigType.model,
  prompt: (_) => AiConfigType.prompt,
  inferenceProfile: (_) => AiConfigType.inferenceProfile,
  skill: (_) => AiConfigType.skill,
);

/// A received live provider without a key, holding the key stored here —
/// but only while it still points where that key was entered for, and only
/// when the sender did not say the key was removed on purpose.
///
/// A version that changes the provider's endpoint or kind arrives without
/// this device's key, so a peer cannot redirect a stored key to a host of
/// its choosing; the user enters the key again for the new endpoint.
AiConfig withKeptApiKey(AiConfig incoming, AiConfig? existing) {
  if (incoming is AiConfigInferenceProvider &&
      incoming.deletedAt == null &&
      incoming.apiKey.isEmpty &&
      !incoming.apiKeyCleared &&
      existing is AiConfigInferenceProvider &&
      existing.apiKey.isNotEmpty &&
      incoming.inferenceProviderType == existing.inferenceProviderType &&
      _sameEndpoint(incoming.baseUrl, existing.baseUrl)) {
    return incoming.copyWith(apiKey: existing.apiKey);
  }
  return incoming;
}

/// Whether two base URLs name the same endpoint, ignoring surrounding space,
/// trailing slashes and the case of the scheme and host.
bool _sameEndpoint(String a, String b) {
  String normalized(String url) {
    final trimmed = url.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    return uri == null ? trimmed : uri.normalizePath().toString();
  }

  return normalized(a) == normalized(b);
}

/// Whether [config] is a model whose provider this device holds a deletion
/// of: a tombstone among [providers], or a hard deletion in [hardDeleted].
/// A provider never seen here is not a deletion, and its models stay listed
/// as before.
///
/// Such a model is a user's edit or restore stamped after the provider's
/// deletion on a device that had not heard of it, which the receive keeps
/// (`KeepNewerModels`) because an undo's restore looks the same. It is not
/// deleted for the user — that would also delete the undo's restore — but it
/// is not listed either: nothing can be inferred through it, and a restore
/// of the provider shows it again.
bool isOrphanedModel(
  AiConfig config,
  Iterable<AiConfig> providers,
  Set<String> hardDeleted,
) {
  if (config is! AiConfigModel) return false;
  final provider = providers
      .where((p) => p.id == config.inferenceProviderId)
      .firstOrNull;
  if (provider != null) return provider.deletedAt != null;
  return hardDeleted.contains(config.inferenceProviderId);
}
