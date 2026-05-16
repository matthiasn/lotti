import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

/// Connection-state hint surfaced on the provider card. Reflects what
/// the redesigned settings page can determine locally — no live
/// network probe — so the values are deliberately coarse:
///
/// - `connected`: a cloud provider has a non-blank API key and a
///   local provider (Ollama / Voxtral / Whisper — see
///   [ProviderConfig.noApiKeyRequired]) has both a non-blank base URL
///   and at least one model row. The card renders the model-count
///   tail on the right of the status row.
/// - `invalidKey`: cloud provider with no / blank API key. Generic
///   on purpose so missing / wrong / revoked / 401 / 403 all read
///   the same. Local providers never reach this state — they don't
///   accept an API key at all.
/// - `offline`: local provider variant — base URL is missing or no
///   model rows exist yet, which mirrors the "server not running"
///   failure mode.
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
  final isLocal = ProviderConfig.noApiKeyRequired.contains(
    provider.inferenceProviderType,
  );
  if (isLocal) {
    if (modelCount == 0 || provider.baseUrl.trim().isEmpty) {
      return AiProviderCardStatus.offline;
    }
    return AiProviderCardStatus.connected;
  }
  final hasKey = provider.apiKey.trim().isNotEmpty;
  if (!hasKey) return AiProviderCardStatus.invalidKey;
  return AiProviderCardStatus.connected;
}
