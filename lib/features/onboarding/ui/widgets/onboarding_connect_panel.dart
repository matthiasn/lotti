import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';

/// The three providers surfaced as co-equals. MLX is deliberately excluded from
/// the FTUE (a multi-GB download has no place in a first session); it stays
/// available later in Settings.
const onboardingPrimaryProviders = <InferenceProviderType>[
  InferenceProviderType.gemini,
  InferenceProviderType.mistral,
  InferenceProviderType.alibaba,
];

/// Surfaced behind the "More options" disclosure.
const onboardingMoreProviders = <InferenceProviderType>[
  InferenceProviderType.openAi,
  InferenceProviderType.ollama,
];

/// Curated welcome-specific provider name (more marketing-forward than the
/// generic AI-settings label — e.g. "Qwen" rather than "Alibaba").
String onboardingProviderName(AppLocalizations m, InferenceProviderType type) {
  return switch (type) {
    InferenceProviderType.gemini => m.onboardingConnectGeminiName,
    InferenceProviderType.mistral => m.onboardingConnectMistralName,
    InferenceProviderType.alibaba => m.onboardingConnectQwenName,
    InferenceProviderType.openAi => m.onboardingConnectOpenAiName,
    InferenceProviderType.ollama => m.onboardingConnectOllamaName,
    _ => aiProviderDisplayName(type: type, messages: m),
  };
}

/// Curated welcome-specific tagline; empty for providers without one.
String onboardingProviderTagline(
  AppLocalizations m,
  InferenceProviderType type,
) {
  return switch (type) {
    InferenceProviderType.gemini => m.onboardingConnectGeminiTagline,
    InferenceProviderType.mistral => m.onboardingConnectMistralTagline,
    InferenceProviderType.alibaba => m.onboardingConnectQwenTagline,
    _ => '',
  };
}

/// Literal external **brand** colours for the FTUE provider tiles (per
/// product-owner direction: render each provider in the colour people
/// associate with it). These are deliberately NOT design-system tokens — the
/// app's `aiProvider` palette is its own themed hues, and these brand
/// identities are external. Scoped to onboarding so the global palette and the
/// rest of AI Settings are unaffected.
Color onboardingProviderBrandColor(InferenceProviderType type) {
  return switch (type) {
    InferenceProviderType.gemini => const Color(0xFF4285F4), // Google blue
    InferenceProviderType.mistral => const Color(0xFFFF7000), // Mistral orange
    InferenceProviderType.alibaba => const Color(0xFF615CED), // Qwen violet
    InferenceProviderType.openAi => const Color(0xFF10A37F), // OpenAI green
    InferenceProviderType.ollama => const Color(0xFFC7C7CC), // Ollama neutral
    _ => const Color(0xFF5ED4B7), // brand teal fallback
  };
}

/// The cinematic connect page: an always-dark panel matching the welcome, with
/// an ambient **aurora** backdrop (a different motion from the welcome's
/// constellation) behind a back/title header and clean, Apple-style provider
/// tiles — soft brand-tinted fills, no outlines.
class OnboardingConnectPanel extends StatefulWidget {
  const OnboardingConnectPanel({
    required this.onSelect,
    required this.onBack,
    super.key,
  });

  final void Function(InferenceProviderType) onSelect;
  final VoidCallback onBack;

  @override
  State<OnboardingConnectPanel> createState() => _OnboardingConnectPanelState();
}

class _OnboardingConnectPanelState extends State<OnboardingConnectPanel> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = dsTokensDark.colors.interactive.enabled;
    final panelBg = dsTokensDark.colors.background.level01;
    final textHigh = dsTokensDark.colors.text.highEmphasis;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          // Shared alive backdrop: aurora wash + neural constellation, as on the
          // welcome — not a flat cloud gradient.
          const Positioned.fill(child: OnboardingBackdrop()),
          // Bottom scrim so the lower tiles read against the aurora.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0),
                    panelBg.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _IconBtn(
                    icon: Icons.arrow_back_rounded,
                    color: textHigh,
                    onTap: widget.onBack,
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                Text(
                  context.messages.onboardingConnectTitle,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: textHigh,
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                // Plain-language reassurance so a novice isn't paralysed by the
                // unfamiliar provider names (the recurring novice-review note).
                Text(
                  context.messages.onboardingConnectNotSure,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: dsTokensDark.colors.text.mediumEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step5),
                for (final type in onboardingPrimaryProviders)
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                    child: _ProviderTile(
                      type: type,
                      onTap: () => widget.onSelect(type),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => setState(() => _showMore = !_showMore),
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedRotation(
                            turns: _showMore ? 0.5 : 0,
                            duration: MotionDurations.short4,
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: tokens.spacing.step4,
                              color: accent,
                            ),
                          ),
                          SizedBox(width: tokens.spacing.step1),
                          AnimatedSwitcher(
                            duration: MotionDurations.short4,
                            child: Text(
                              _showMore
                                  ? context
                                        .messages
                                        .onboardingConnectLessOptions
                                  : context
                                        .messages
                                        .onboardingConnectMoreOptions,
                              key: ValueKey(_showMore),
                              style: tokens.typography.styles.body.bodyMedium
                                  .copyWith(color: accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: MotionDurations.long2,
                  curve: MotionCurves.emphasizedDecelerate,
                  alignment: Alignment.topCenter,
                  child: _showMore
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final type in onboardingMoreProviders)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: tokens.spacing.step2,
                                ),
                                child: _ProviderTile(
                                  type: type,
                                  onTap: () => widget.onSelect(type),
                                ),
                              ),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step2),
        child: Icon(icon, color: color, size: tokens.spacing.step5),
      ),
    );
  }
}

/// Clean, Apple-style provider tile: a soft brand-tinted gradient fill with
/// rounded corners and NO outline/border, a brand icon in a soft chip, name +
/// tagline, and a quiet chevron.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.type, required this.onTap});

  final InferenceProviderType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = onboardingProviderBrandColor(type);
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMed = dsTokensDark.colors.text.mediumEmphasis;
    final tagline = onboardingProviderTagline(messages, type);

    return AnimatedModalItem(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.3),
              accent.withValues(alpha: 0.14),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radii.l),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(tokens.spacing.step3),
              decoration: BoxDecoration(
                color: textHigh.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(tokens.radii.m),
              ),
              child: Icon(aiProviderIcon(type), color: accent),
            ),
            SizedBox(width: tokens.spacing.step4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    onboardingProviderName(messages, type),
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: textHigh,
                    ),
                  ),
                  if (tagline.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step1),
                      child: Text(
                        tagline,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: textMed,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textHigh.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
