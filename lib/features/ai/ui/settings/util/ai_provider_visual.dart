import 'package:flutter/material.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Visual + copy metadata for an AI provider used by the redesigned
/// AI Settings page surfaces: the provider list cards, the four
/// quick-add tiles in the empty state, the master/detail rail, and
/// the provider-detail page.
///
/// Keeps per-type assignments centralised so the tabs, the empty
/// state, the master/detail rail, and the detail page can't drift on
/// "what colour is Anthropic" or "what's Ollama's tagline". Providers
/// without a dedicated brand token (Mistral, OpenRouter, etc.) fall
/// back to a neutral interactive accent rather than impersonating
/// Gemini's teal, so a Mistral card never looks like a Gemini card.
class AiProviderVisual {
  const AiProviderVisual({
    required this.accent,
    required this.surface,
    required this.displayName,
    required this.tagline,
  });

  final Color accent;
  final Color surface;
  final String displayName;
  final String tagline;
}

/// Resolves the full visual bundle for a provider type. Designed to be
/// called once per render from a widget that already has tokens +
/// localizations in scope. Accepts a nullable [type] so callers that
/// can't resolve an owning provider (e.g. a model row whose provider
/// hasn't loaded yet) can still render neutral chrome.
AiProviderVisual aiProviderVisual({
  required InferenceProviderType? type,
  required DsTokens tokens,
  required AppLocalizations messages,
}) {
  return AiProviderVisual(
    accent: aiProviderAccent(type: type, tokens: tokens),
    surface: aiProviderSurface(type: type, tokens: tokens),
    displayName: aiProviderDisplayName(type: type, messages: messages),
    tagline: aiProviderTagline(type: type, messages: messages),
  );
}

/// Provider accent color — the saturated hue used for the per-row
/// chip, the quick-add tile, the master/detail rail-row indicator,
/// and the detail page's header strip. Light + dark variants are
/// resolved through the design tokens, so callers don't need to
/// know which mode is active. Providers without a dedicated brand
/// token fall back to the neutral interactive accent so a Mistral
/// (or unresolved) card doesn't masquerade as a Gemini card.
Color aiProviderAccent({
  required InferenceProviderType? type,
  required DsTokens tokens,
}) {
  return switch (type) {
    InferenceProviderType.gemini => tokens.colors.aiProvider.gemini.color,
    InferenceProviderType.openAi => tokens.colors.aiProvider.openAi.color,
    InferenceProviderType.anthropic => tokens.colors.aiProvider.anthropic.color,
    InferenceProviderType.ollama => tokens.colors.aiProvider.ollama.color,
    InferenceProviderType.alibaba => tokens.colors.aiProvider.alibaba.color,
    _ => tokens.colors.interactive.enabled,
  };
}

/// Tinted-surface pair for the accent — used as the background fill
/// of a quick-add tile or a card's leading badge so the saturated
/// accent doesn't fight high-emphasis body text. Falls back to a
/// translucent neutral surface for the same provider types that fall
/// back on [aiProviderAccent].
Color aiProviderSurface({
  required InferenceProviderType? type,
  required DsTokens tokens,
}) {
  return switch (type) {
    InferenceProviderType.gemini => tokens.colors.aiProvider.gemini.surface,
    InferenceProviderType.openAi => tokens.colors.aiProvider.openAi.surface,
    InferenceProviderType.anthropic =>
      tokens.colors.aiProvider.anthropic.surface,
    InferenceProviderType.ollama => tokens.colors.aiProvider.ollama.surface,
    InferenceProviderType.alibaba => tokens.colors.aiProvider.alibaba.surface,
    _ => tokens.colors.interactive.enabled.withValues(alpha: 0.14),
  };
}

/// Derives the capability-chip labels for a model from its reasoning
/// flag and input/output modalities. Shared between the redesigned
/// Models tab (`AiModelCard`) and the FTUE preview modal so the
/// "Thinking / Image recognition / Transcription / Image generation"
/// labelling stays consistent across surfaces.
List<String> modelCapabilityLabels({
  required AppLocalizations messages,
  required bool isReasoning,
  required List<Modality> inputModalities,
  required List<Modality> outputModalities,
}) {
  final out = <String>[];
  if (isReasoning) {
    out.add(messages.aiCapabilityChipThinking);
  }
  if (inputModalities.contains(Modality.image)) {
    out.add(messages.aiCapabilityChipImageRecognition);
  }
  if (inputModalities.contains(Modality.audio)) {
    out.add(messages.aiCapabilityChipTranscription);
  }
  if (outputModalities.contains(Modality.image)) {
    out.add(messages.aiCapabilityChipImageGeneration);
  }
  return out;
}

/// Returns `true` when [provider] looks like a draft saved via the
/// connect form's "Save as draft" affordance — i.e. a cloud provider
/// row with no API key yet. Local providers (Ollama, Whisper, Voxtral)
/// never need a key, so they're never reported as drafts. The flag
/// is consumed by the AI Settings provider card and the provider
/// detail page header to render a "DRAFT" badge so the user can tell
/// half-configured providers apart from fully-set-up ones.
bool isProviderDraft(AiConfigInferenceProvider provider) {
  if (ProviderConfig.noApiKeyRequired.contains(
    provider.inferenceProviderType,
  )) {
    return false;
  }
  return provider.apiKey.trim().isEmpty;
}

/// Returns the **bare host** of the public console where the user
/// can obtain an API key for [type], or `null` when no such page
/// exists (Ollama/MLX Audio run locally; whisper/voxtral are local-only).
///
/// Powers the "Get a key at …" hint rendered next to the API-key
/// field on the connect form. The host-only form is intentional:
/// the connect form displays this as static text inside the field's
/// right-hand caption (a visual cue, not a tap target — see
/// `_FlatFieldHintTone.link`), and a fully-qualified `https://…`
/// would only bloat the caption ("Get a key at https://aistudio…").
/// If a future surface needs to launch the URL, prepend `https://`
/// at that call site (or introduce a paired `…ConsoleUri` helper)
/// rather than changing the display contract here.
///
/// Hosts are centralised in one switch arm so any future provider
/// rename or moved console URL touches one place instead of the
/// form widget.
String? aiProviderKeyConsoleUrl(InferenceProviderType? type) {
  return switch (type) {
    InferenceProviderType.gemini => 'aistudio.google.com',
    InferenceProviderType.openAi => 'platform.openai.com',
    InferenceProviderType.anthropic => 'console.anthropic.com',
    InferenceProviderType.mistral => 'console.mistral.ai',
    InferenceProviderType.alibaba => 'dashscope.console.aliyun.com',
    InferenceProviderType.openRouter => 'openrouter.ai',
    InferenceProviderType.nebiusAiStudio => 'studio.nebius.ai',
    _ => null,
  };
}

/// Provider-type icon used by the cards' leading tile and the empty
/// state's compact chips. Centralised so the two surfaces can't drift.
IconData aiProviderIcon(InferenceProviderType? type) {
  return switch (type) {
    InferenceProviderType.gemini => Icons.auto_awesome_rounded,
    InferenceProviderType.openAi => Icons.circle_rounded,
    InferenceProviderType.anthropic => Icons.psychology_rounded,
    InferenceProviderType.ollama => Icons.computer_rounded,
    InferenceProviderType.mistral => Icons.air_rounded,
    InferenceProviderType.mlxAudio => Icons.memory_rounded,
    InferenceProviderType.alibaba => Icons.cloud_rounded,
    _ => Icons.smart_toy_rounded,
  };
}

/// User-facing display name for a provider type. Wraps the existing
/// per-type localised name source so the rest of the redesigned
/// surfaces don't reach back into `InferenceProviderTypeExtension`
/// directly. Returns the generic "AI provider" label when [type] is
/// null so cards can render without a resolved owner.
String aiProviderDisplayName({
  required InferenceProviderType? type,
  required AppLocalizations messages,
}) {
  return switch (type) {
    InferenceProviderType.gemini => messages.aiProviderGeminiName,
    InferenceProviderType.openAi => messages.aiProviderOpenAiName,
    InferenceProviderType.anthropic => messages.aiProviderAnthropicName,
    InferenceProviderType.ollama => messages.aiProviderOllamaName,
    InferenceProviderType.mistral => messages.aiProviderMistralName,
    InferenceProviderType.mlxAudio => messages.aiProviderMlxAudioName,
    InferenceProviderType.alibaba => messages.aiProviderAlibabaName,
    InferenceProviderType.openRouter => messages.aiProviderOpenRouterName,
    InferenceProviderType.nebiusAiStudio =>
      messages.aiProviderNebiusAiStudioName,
    InferenceProviderType.genericOpenAi => messages.aiProviderGenericOpenAiName,
    InferenceProviderType.whisper => messages.aiProviderWhisperName,
    InferenceProviderType.voxtral => messages.aiProviderVoxtralName,
    null => messages.aiProviderUnknownName,
  };
}

/// One-line tagline shown under the display name on the provider
/// cards + quick-add tiles. Returns an empty string for provider types
/// that haven't been given a tagline in the redesign yet (and for `null`) —
/// callers should `if (tagline.isNotEmpty)` before rendering.
String aiProviderTagline({
  required InferenceProviderType? type,
  required AppLocalizations messages,
}) {
  return switch (type) {
    InferenceProviderType.gemini => messages.aiProviderTaglineGemini,
    InferenceProviderType.openAi => messages.aiProviderTaglineOpenAi,
    InferenceProviderType.anthropic => messages.aiProviderTaglineAnthropic,
    InferenceProviderType.ollama => messages.aiProviderTaglineOllama,
    InferenceProviderType.mlxAudio => messages.aiProviderTaglineMlxAudio,
    InferenceProviderType.alibaba => messages.aiProviderTaglineAlibaba,
    _ => '',
  };
}
