import 'package:lotti/features/ai/model/ai_config.dart';

/// Connection-state hint surfaced on the provider card. Reflects what
/// the redesigned settings page can determine locally — no live
/// network probe — so the values are deliberately coarse:
///
/// - `connected`: API key (or base URL for Ollama) is present and
///   at least one model row exists. The card renders the model-count
///   tail on the right of the status row.
/// - `invalidKey`: cloud provider with no / blank API key. Generic
///   on purpose so missing / wrong / revoked / 401 / 403 all read
///   the same.
/// - `offline`: Ollama variant — base URL is set but no model rows
///   exist yet, which mirrors the "server not running" failure mode.
enum AiProviderCardStatus { connected, invalidKey, offline }

/// Resolves a status from the underlying provider record. The detail
/// page surfaces real verification errors when the user taps Re-test;
/// this is the local-state read used by the cards, the detail header,
/// and the Profiles tab's Active-badge gate.
///
/// Lives in `util/` (no widget imports) so callers outside the widget
/// layer — e.g. `active_profile.dart` — can share the same definition
/// without pulling Flutter widget dependencies into a pure function
/// tree.
AiProviderCardStatus aiProviderCardStatusFor({
  required AiConfigInferenceProvider provider,
  required int modelCount,
}) {
  final isOllama =
      provider.inferenceProviderType == InferenceProviderType.ollama;
  final hasKey = provider.apiKey.trim().isNotEmpty;
  if (isOllama) {
    if (modelCount == 0 || provider.baseUrl.trim().isEmpty) {
      return AiProviderCardStatus.offline;
    }
    return AiProviderCardStatus.connected;
  }
  if (!hasKey) return AiProviderCardStatus.invalidKey;
  return AiProviderCardStatus.connected;
}
