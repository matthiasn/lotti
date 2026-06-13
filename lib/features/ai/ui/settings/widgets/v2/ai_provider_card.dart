import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_status.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_card_action_menu.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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

  /// Backwards-compat shim — the real logic lives in
  /// `util/ai_provider_status.dart` so non-widget callers (e.g. the
  /// Profiles tab's Active-badge gate) can share the same definition
  /// without depending on this widget file.
  static AiProviderCardStatus statusFor({
    required AiConfigInferenceProvider provider,
    required int modelCount,
  }) {
    return aiProviderCardStatusFor(
      provider: provider,
      modelCount: modelCount,
    );
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
        AiProviderIconTile(
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
