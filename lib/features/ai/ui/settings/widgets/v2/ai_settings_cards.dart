import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_card_action_menu.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Connection-state hint surfaced on the provider card. Reflects what
/// the redesigned settings page can determine locally — no live
/// network probe in PR-3 — so the values are deliberately coarse:
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

/// 2-column grid card for the redesigned Providers tab.
///
/// Layout from `/Desktop/ai-settings-images/D1 _ Tabs _ populated _ Providers.png`:
///
/// ```text
/// ┌─────────────────────────────────────────────┐
/// │ [icon]                                  ⋯  │
/// │                                             │
/// │ Provider Name                               │
/// │ tagline · tagline · tagline                 │
/// │                                             │
/// │ ─────────────────────────────────────────── │
/// │ • Connected           3 models · last 2m ago │
/// └─────────────────────────────────────────────┘
/// ```
///
/// The card is sized by its parent grid; everything inside the card is
/// tokenised so the layout holds across the two viewport widths the
/// page uses (mobile single column, desktop two columns).
class AiProviderCard extends StatelessWidget {
  const AiProviderCard({
    required this.provider,
    required this.modelCount,
    required this.status,
    required this.onTap,
    this.menuActions = const [],
    this.onFix,
    this.lastUsedLabel,
    super.key,
  });

  final AiConfigInferenceProvider provider;
  final int modelCount;
  final AiProviderCardStatus status;
  final VoidCallback onTap;

  /// Rows to show when the user taps the `⋯` icon. Empty (the default)
  /// hides the icon entirely — the v2 cards used to render a disabled
  /// IconButton on top of the tappable card, which made the icon look
  /// actionable but only forwarded the tap to the card itself.
  final List<AiCardMenuAction> menuActions;

  /// Required when [status] is [AiProviderCardStatus.invalidKey] —
  /// powers the right-side "Fix →" affordance on the status row.
  final VoidCallback? onFix;

  /// Optional last-used label shown after the model count for
  /// connected providers. PR-3 doesn't track usage telemetry, so the
  /// page passes null and the right-side meta carries only the
  /// model count.
  final String? lastUsedLabel;

  /// Resolves a status from the underlying provider record. PR-3
  /// doesn't ship a live connectivity probe — the detail page in
  /// PR-4 surfaces real verification errors when the user taps
  /// Re-test.
  static AiProviderCardStatus statusFor({
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final visual = aiProviderVisual(
      type: provider.inferenceProviderType,
      tokens: tokens,
      messages: messages,
    );
    final radius = BorderRadius.circular(tokens.radii.l);
    final displayName = provider.name.isNotEmpty
        ? provider.name
        : visual.displayName;

    return Material(
      color: tokens.colors.background.level02,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: tokens.colors.surface.hover,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CardHeaderRow(
                accent: visual.accent,
                surface: visual.surface,
                providerType: provider.inferenceProviderType,
                menuActions: menuActions,
                isDraft: isProviderDraft(provider),
              ),
              SizedBox(height: tokens.spacing.step3),
              Text(
                displayName,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (visual.tagline.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.step1),
                Text(
                  visual.tagline,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: tokens.spacing.step4),
              Container(
                height: 1,
                color: tokens.colors.decorative.level01.withValues(
                  alpha: 0.18,
                ),
              ),
              SizedBox(height: tokens.spacing.step3),
              _ProviderStatusRow(
                status: status,
                modelCount: modelCount,
                lastUsedLabel: lastUsedLabel,
                onFix: onFix,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top row of a provider / profile card: colored icon square on the
/// left, optional `DRAFT` badge in the middle (only when [isDraft] is
/// true), three-dot overflow menu on the right.
///
/// The badge lets a half-configured provider (cloud row saved via
/// "Save as draft" with no API key yet) be told apart from a fully
/// set-up one with the same display name — important when the user
/// connects the same provider twice.
class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({
    required this.accent,
    required this.surface,
    required this.providerType,
    required this.menuActions,
    this.isDraft = false,
  });

  final Color accent;
  final Color surface;
  final InferenceProviderType? providerType;
  final List<AiCardMenuAction> menuActions;
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      children: [
        _ProviderIconTile(
          accent: accent,
          surface: surface,
          providerType: providerType,
        ),
        if (isDraft) ...[
          SizedBox(width: tokens.spacing.step2),
          DesignSystemBadge.outlined(
            label: messages.aiProviderCardDraftBadge,
            tone: DesignSystemBadgeTone.secondary,
          ),
        ],
        const Spacer(),
        AiCardActionMenuButton(actions: menuActions),
      ],
    );
  }
}

/// Small rounded square showing a provider-type icon in the provider
/// accent color over a tinted surface. Used as the leading badge on
/// provider cards, profile cards, and model rows.
class _ProviderIconTile extends StatelessWidget {
  const _ProviderIconTile({
    required this.accent,
    required this.surface,
    required this.providerType,
    this.size,
  });

  final Color accent;
  final Color surface;
  final InferenceProviderType? providerType;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dim = size ?? tokens.spacing.step8;
    return Container(
      width: dim,
      height: dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Icon(
        aiProviderIcon(providerType),
        size: dim * 0.5,
        color: accent,
      ),
    );
  }
}

/// Status row below the divider on a provider card. Left side: status
/// dot + label. Right side: secondary meta — model count + optional
/// "last used" for connected, the inline Fix link for invalid-key,
/// the Ollama-running hint for offline.
class _ProviderStatusRow extends StatelessWidget {
  const _ProviderStatusRow({
    required this.status,
    required this.modelCount,
    required this.lastUsedLabel,
    required this.onFix,
  });

  final AiProviderCardStatus status;
  final int modelCount;
  final String? lastUsedLabel;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption;

    switch (status) {
      case AiProviderCardStatus.connected:
        final connected = messages.aiProviderCardStatusConnectedShort;
        final tail = lastUsedLabel == null
            ? messages.aiProviderCardModelCount(modelCount)
            : messages.aiProviderCardModelCountWithLastUsed(
                modelCount,
                lastUsedLabel!,
              );
        return Row(
          children: [
            _StatusDot(color: tokens.colors.alert.success.defaultColor),
            SizedBox(width: tokens.spacing.step2),
            Text(
              connected,
              style: caption.copyWith(color: tokens.colors.text.highEmphasis),
            ),
            // Expanded (not Spacer + Flexible) so the tail's "3 models
            // · last used 2m ago" text actually sits flush against the
            // card's right edge. The previous Spacer-with-Flexible
            // pairing split the remaining width 1:1 and parked the
            // count in the middle-right of the card.
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tokens.spacing.step3,
                ),
                child: Text(
                  tail,
                  textAlign: TextAlign.end,
                  style: caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      case AiProviderCardStatus.invalidKey:
        return Row(
          children: [
            _StatusDot(color: tokens.colors.alert.error.defaultColor),
            SizedBox(width: tokens.spacing.step2),
            Text(
              messages.aiProviderCardStatusInvalidKey,
              style: caption.copyWith(
                color: tokens.colors.alert.error.defaultColor,
              ),
            ),
            const Spacer(),
            if (onFix != null)
              InkWell(
                onTap: onFix,
                borderRadius: BorderRadius.circular(tokens.radii.s),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                    vertical: tokens.spacing.step1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        messages.aiProviderCardFixButton,
                        style: caption.copyWith(
                          color: tokens.colors.interactive.enabled,
                          fontWeight: tokens.typography.weight.semiBold,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step1),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: tokens.colors.interactive.enabled,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case AiProviderCardStatus.offline:
        return Row(
          children: [
            _StatusDot(color: tokens.colors.text.lowEmphasis),
            SizedBox(width: tokens.spacing.step2),
            Text(
              messages.aiProviderCardStatusOfflineShort,
              style: caption.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            // Same flush-right treatment as the Connected branch — the
            // Ollama hint sits at the card's right edge instead of
            // floating in the middle.
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tokens.spacing.step3,
                ),
                child: Text(
                  messages.aiProviderCardOllamaHint,
                  textAlign: TextAlign.end,
                  style: caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Single-column row for the redesigned Models tab.
///
/// Layout from `/Desktop/ai-settings-images/D1 _ Tabs _ populated _ Models.png`:
/// provider icon left, model name + mono provider-model id inline on
/// the first text line, capability chips below the name, three-dot
/// overflow on the right. Per the design tweaks file, the on/off
/// toggle from the reference is intentionally omitted — models are
/// either present in the repo or not.
class AiModelCard extends StatelessWidget {
  const AiModelCard({
    required this.model,
    required this.providerType,
    required this.onTap,
    this.menuActions = const [],
    super.key,
  });

  final AiConfigModel model;

  /// Type of the inference provider that owns this model. Drives the
  /// leading icon color so a glance at the row says which provider
  /// the model belongs to without re-reading the id. Nullable because
  /// a row may render before its owning provider has resolved (or
  /// after the provider has been deleted) — the card renders neutral
  /// chrome in that case instead of impersonating Gemini.
  final InferenceProviderType? providerType;

  final VoidCallback onTap;
  final List<AiCardMenuAction> menuActions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final visual = aiProviderVisual(
      type: providerType,
      tokens: tokens,
      messages: messages,
    );
    final radius = BorderRadius.circular(tokens.radii.l);

    return Material(
      color: tokens.colors.background.level02,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: tokens.colors.surface.hover,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProviderIconTile(
                accent: visual.accent,
                surface: visual.surface,
                providerType: providerType,
                size: tokens.spacing.step7,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                // Stack the model name, the mono provider-model id, and
                // the capability chips vertically — previously the name
                // and id sat inline on the first row which truncated
                // both on mobile widths. Vertical stack lets long names
                // and ids wrap to multiple lines instead of clipping.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          ),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      model.providerModelId,
                      style: monoMetaStyle(tokens, tokens.colors),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    _CapabilityChipRow(
                      labels: modelCapabilityLabels(
                        messages: messages,
                        isReasoning: model.isReasoningModel,
                        inputModalities: model.inputModalities,
                        outputModalities: model.outputModalities,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              AiCardActionMenuButton(actions: menuActions),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityChipRow extends StatelessWidget {
  const _CapabilityChipRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final label in labels)
          DesignSystemBadge.filled(
            label: label,
            tone: DesignSystemBadgeTone.secondary,
          ),
      ],
    );
  }
}

/// 2-column grid card for the redesigned Profiles tab.
///
/// Layout from `/Desktop/ai-settings-images/D1 _ Tabs _ populated _ Profiles.png`:
///
/// ```text
/// ┌──────────────────────────────────────────────┐
/// │ [icon]  Profile Name  ACTIVE             ⋯  │
/// │         tagline                              │
/// │                                              │
/// │ ⇆ Transcription      →  Gemini 3 Flash      │
/// │ 🖼 Image recognition → Gemini 3 Flash       │
/// │ 🧠 Thinking          →  Gemini 3 Pro        │
/// │ 🎨 Image generation  →  Nano Banana Pro     │
/// └──────────────────────────────────────────────┘
/// ```
class AiProfileCard extends StatelessWidget {
  const AiProfileCard({
    required this.profile,
    required this.isActive,
    required this.providerTypeFor,
    required this.modelLookup,
    required this.onTap,
    this.menuActions = const [],
    super.key,
  });

  final AiConfigInferenceProfile profile;
  final bool isActive;

  /// Resolves the inference provider type that owns this profile, so
  /// the card can color its leading icon. The page wires this from a
  /// providerId → type map built from the providers list. May return
  /// null when none of the profile's skill slots reference a known
  /// model row — the card renders neutral chrome in that case.
  final InferenceProviderType? Function() providerTypeFor;

  /// Resolves a `providerModelId` to its display name. Returns null
  /// when the id doesn't match any known model row — those slots
  /// render in the warning tone so the user can spot dangling
  /// references.
  final String? Function(String providerModelId) modelLookup;

  final VoidCallback onTap;
  final List<AiCardMenuAction> menuActions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Resolve once — providerTypeFor walks four model slots, no point
    // re-running it for the header icon after the visual bundle.
    final providerType = providerTypeFor();
    final visual = aiProviderVisual(
      type: providerType,
      tokens: tokens,
      messages: messages,
    );
    final radius = BorderRadius.circular(tokens.radii.l);
    // The icon tile dimension matches the default `_ProviderIconTile`
    // size. Indenting the description by exactly this column + the
    // header gap keeps the description flush with the profile name
    // without hardcoding token-arithmetic literals further down.
    final iconColumn = tokens.spacing.step8;
    final iconGap = tokens.spacing.step3;

    final slots = <_ProfileSlot>[
      _ProfileSlot(
        icon: Icons.psychology_rounded,
        label: messages.aiCapabilityChipThinking,
        modelId: profile.thinkingModelId,
      ),
      _ProfileSlot(
        icon: Icons.image_outlined,
        label: messages.aiCapabilityChipImageRecognition,
        modelId: profile.imageRecognitionModelId,
      ),
      _ProfileSlot(
        icon: Icons.mic_none_rounded,
        label: messages.aiCapabilityChipTranscription,
        modelId: profile.transcriptionModelId,
      ),
      _ProfileSlot(
        icon: Icons.brush_outlined,
        label: messages.aiCapabilityChipImageGeneration,
        modelId: profile.imageGenerationModelId,
      ),
    ];

    final description = profile.description;
    final hasDescription = description != null && description.isNotEmpty;

    return Material(
      color: tokens.colors.background.level02,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: tokens.colors.surface.hover,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ProviderIconTile(
                    accent: visual.accent,
                    surface: visual.surface,
                    providerType: providerType,
                  ),
                  SizedBox(width: iconGap),
                  // `Expanded` (instead of `Flexible + Spacer`) claims
                  // every pixel between the icon and the trailing
                  // menu, so the `⋯` always pins to the card's right
                  // edge — matching the provider card and avoiding
                  // the "menu floats next to a long name" look.
                  Expanded(
                    child: Text(
                      profile.name,
                      style: tokens.typography.styles.subtitle.subtitle1
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          ),
                      softWrap: true,
                    ),
                  ),
                  if (isActive) ...[
                    SizedBox(width: tokens.spacing.step2),
                    DesignSystemBadge.filled(
                      label: messages.aiProfileCardActiveBadge,
                      tone: DesignSystemBadgeTone.success,
                    ),
                  ],
                  AiCardActionMenuButton(actions: menuActions),
                ],
              ),
              if (hasDescription) ...[
                SizedBox(height: tokens.spacing.step1),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: iconColumn + iconGap,
                  ),
                  child: Text(
                    description,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
              SizedBox(height: tokens.spacing.step3),
              for (final slot in slots)
                if (slot.modelId case final modelId? when modelId.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.step2),
                    child: _ProfileSlotRow(
                      slot: slot,
                      modelName: modelLookup(modelId),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSlot {
  const _ProfileSlot({
    required this.icon,
    required this.label,
    required this.modelId,
  });

  final IconData icon;
  final String label;
  final String? modelId;
}

class _ProfileSlotRow extends StatelessWidget {
  const _ProfileSlotRow({required this.slot, required this.modelName});

  final _ProfileSlot slot;
  final String? modelName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final resolved = modelName ?? messages.aiProfileSlotModelMissing;
    final caption = tokens.typography.styles.others.caption;
    return Row(
      // Top-align so the icon + slot label stay flush with the first
      // line of a wrapped model name on mobile widths.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(slot.icon, size: 14, color: tokens.colors.text.mediumEmphasis),
        SizedBox(width: tokens.spacing.step2),
        Text(
          slot.label,
          style: caption.copyWith(color: tokens.colors.text.mediumEmphasis),
        ),
        SizedBox(width: tokens.spacing.step2),
        Icon(
          Icons.arrow_forward_rounded,
          size: 12,
          color: tokens.colors.text.lowEmphasis,
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Text(
            resolved,
            style: caption.copyWith(
              color: modelName == null
                  ? tokens.colors.alert.warning.defaultColor
                  : tokens.colors.text.highEmphasis,
              fontWeight: tokens.typography.weight.semiBold,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

// `modelCapabilityLabels` lives in `ai_provider_visual.dart` so the
// FTUE preview modal and the redesigned Models tab share one source
// of truth for the capability-chip labelling.
