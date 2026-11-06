import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_speech_bubble.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:material_ui/material_ui.dart';

/// The one provider the connect step recommends, on a card of its own: its
/// single key covers thinking, transcription and the read-aloud voice (the
/// seeded Mistral profile names all three). It is also the demo AI sheet's
/// starting choice.
const InferenceProviderType onboardingRecommendedProvider =
    InferenceProviderType.mistral;

/// The rest, behind the "Other providers" disclosure. MLX is deliberately
/// excluded from the FTUE (a multi-GB download has no place in a first
/// session); it stays available later in Settings.
const onboardingOtherProviders = <InferenceProviderType>[
  InferenceProviderType.melious,
  InferenceProviderType.gemini,
  InferenceProviderType.alibaba,
  InferenceProviderType.openAi,
  InferenceProviderType.ollama,
];

/// Curated welcome-specific provider name (more marketing-forward than the
/// generic AI-settings label — e.g. "Qwen" rather than "Alibaba").
String onboardingProviderName(AppLocalizations m, InferenceProviderType type) {
  return switch (type) {
    InferenceProviderType.melious => m.aiProviderMeliousName,
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
    InferenceProviderType.melious => m.aiProviderTaglineMelious,
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
    InferenceProviderType.melious => const Color(0xFF14B8A6), // Melious teal
    InferenceProviderType.gemini => const Color(0xFF4285F4), // Google blue
    InferenceProviderType.mistral => const Color(0xFFFF7000), // Mistral orange
    InferenceProviderType.alibaba => const Color(0xFF615CED), // Qwen violet
    InferenceProviderType.openAi => const Color(0xFF10A37F), // OpenAI green
    InferenceProviderType.ollama => const Color(0xFFC7C7CC), // Ollama neutral
    _ => const Color(0xFF5ED4B7), // brand teal fallback
  };
}

/// The cinematic connect page, built around one message: a single API key is
/// all it takes. A theme-aware panel matching the welcome, with an ambient
/// **aurora** backdrop behind a back/title header, one large card for the
/// recommended provider, and the others behind a disclosure — clean,
/// Apple-style tiles with soft brand-tinted fills.
class OnboardingConnectPanel extends StatefulWidget {
  const OnboardingConnectPanel({
    required this.onSelect,
    required this.onBack,
    this.companion,
    super.key,
  });

  final void Function(InferenceProviderType) onSelect;
  final VoidCallback onBack;

  /// The companion, as a bust beside a speech bubble in which she recommends
  /// the provider, her line also spoken where a voice is on hand. Null states the
  /// recommendation as a plain subtitle.
  final Widget? companion;

  @override
  State<OnboardingConnectPanel> createState() => _OnboardingConnectPanelState();
}

class _OnboardingConnectPanelState extends State<OnboardingConnectPanel> {
  bool _showOthers = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final panelBg = tokens.colors.background.level01;
    final textHigh = tokens.colors.text.highEmphasis;
    final messages = context.messages;

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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: tokens.spacing.step6 * 7,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      panelBg.withValues(alpha: 0.18),
                      panelBg.withValues(alpha: 0.76),
                      panelBg.withValues(alpha: 0.52),
                      panelBg.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.45, 0.72, 1],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step5,
              // Clear the home indicator when flush to the bottom as a sheet.
              tokens.spacing.step6 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _IconBtn(
                    icon: LottiIcons.back,
                    color: textHigh,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onTap: widget.onBack,
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                Text(
                  messages.onboardingConnectOneKeyTitle,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: textHigh,
                  ),
                ),
                SizedBox(height: tokens.spacing.step3),
                if (widget.companion case final companion?)
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: ControlSizes.avatarHero,
                        child: companion,
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Expanded(
                        child: OnboardingSpeechBubble(
                          text: messages.onboardingConnectGuide,
                          tail: OnboardingBubbleTail.left,
                        ),
                      ),
                    ],
                  )
                else
                  // Plain-language reassurance so a novice isn't paralysed by
                  // the unfamiliar provider names.
                  Text(
                    messages.onboardingConnectNotSure,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                SizedBox(height: tokens.spacing.step5),
                _ProviderTile(
                  type: onboardingRecommendedProvider,
                  recommended: true,
                  onTap: () => widget.onSelect(onboardingRecommendedProvider),
                ),
                SizedBox(height: tokens.spacing.step3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => setState(() => _showOthers = !_showOthers),
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedRotation(
                            turns: _showOthers ? 0.5 : 0,
                            duration: MotionDurations.short4,
                            child: Icon(
                              LottiIcons.expand,
                              size: tokens.spacing.step4,
                              color: accent,
                            ),
                          ),
                          SizedBox(width: tokens.spacing.step1),
                          AnimatedSwitcher(
                            duration: MotionDurations.short4,
                            child: Text(
                              _showOthers
                                  ? messages.onboardingConnectHideOtherProviders
                                  : messages.onboardingConnectOtherProviders,
                              key: ValueKey(_showOthers),
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
                  child: _showOthers
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final type in onboardingOtherProviders)
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
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onTap,
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          iconSize: tokens.spacing.step5,
          color: color,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

/// Clean, Apple-style provider tile: a soft brand-tinted gradient fill with
/// rounded corners and NO outline/border, a brand icon in a soft chip, name +
/// tagline, and a quiet chevron.
class _ProviderTile extends StatefulWidget {
  const _ProviderTile({
    required this.type,
    required this.onTap,
    this.recommended = false,
  });

  final InferenceProviderType type;
  final VoidCallback onTap;

  /// The recommended provider's card: a "Recommended" badge by the name, and
  /// what its one key covers in place of the tagline.
  final bool recommended;

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = onboardingProviderBrandColor(widget.type);
    final textHigh = tokens.colors.text.highEmphasis;
    final textMed = tokens.colors.text.mediumEmphasis;
    final tileBase = tokens.colors.background.level02;
    final name = onboardingProviderName(messages, widget.type);
    final tagline = widget.recommended
        ? messages.onboardingConnectMistralPitch
        : onboardingProviderTagline(messages, widget.type);

    return Semantics(
      button: true,
      label: widget.recommended
          ? '$name, ${messages.onboardingConnectRecommended}'
          : name,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (focused) {
          if (_focused == focused) return;
          setState(() => _focused = focused);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: ExcludeSemantics(
          child: AnimatedModalItem(
            onTap: widget.onTap,
            child: Container(
              padding: EdgeInsets.all(tokens.spacing.step4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(tileBase, accent, 0.18)!,
                    Color.lerp(tileBase, accent, 0.07)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(tokens.radii.l),
                border: Border.all(
                  color: _focused
                      ? tokens.colors.interactive.enabled
                      : accent.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: tokens.spacing.step1,
                    height: tokens.spacing.step6 * 2,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(tokens.radii.s),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Container(
                    padding: EdgeInsets.all(tokens.spacing.step3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(tokens.radii.m),
                    ),
                    child: Icon(
                      aiProviderIcon(widget.type),
                      color: Color.lerp(accent, textHigh, 0.18),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: tokens.spacing.step2,
                          runSpacing: tokens.spacing.step1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              style: tokens.typography.styles.subtitle.subtitle1
                                  .copyWith(color: textHigh),
                            ),
                            if (widget.recommended)
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(
                                    tokens.radii.s,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: tokens.spacing.step2,
                                    vertical: tokens.spacing.step1,
                                  ),
                                  child: Text(
                                    messages.onboardingConnectRecommended,
                                    style: tokens
                                        .typography
                                        .styles
                                        .others
                                        .caption
                                        .copyWith(color: textHigh),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (tagline.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: tokens.spacing.step1,
                            ),
                            child: Text(
                              tagline,
                              style: tokens.typography.styles.body.bodySmall
                                  .copyWith(color: textMed),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    LottiIcons.chevronRight,
                    color: textHigh.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
