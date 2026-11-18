import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_choice_chip.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_stage.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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

/// The connect step, built around one message: a single API key is all it
/// takes. On the shared [OnboardingStage], its tray holds one card for the
/// recommended provider, already chosen, with the others behind a
/// disclosure. A card chooses its provider; the main button, which names the
/// one chosen, goes on with it.
class OnboardingConnectPanel extends StatefulWidget {
  const OnboardingConnectPanel({
    required this.onSelect,
    required this.onBack,
    this.onClose,
    this.companion,
    this.progress,
    super.key,
  });

  /// Called with the chosen provider when the main button is pressed.
  final void Function(InferenceProviderType) onSelect;
  final VoidCallback onBack;

  /// Leaves the flow; null where there is none to leave (the demo's AI
  /// setup, which has its own way out).
  final VoidCallback? onClose;

  /// The companion, on the stage above a speech bubble in which she
  /// recommends the provider, her line also spoken where a voice is on hand.
  /// Null states the recommendation as a plain subtitle.
  final Widget? companion;

  /// Where this step is in onboarding; null where it is borrowed (the demo's
  /// AI setup).
  final OnboardingProgress? progress;

  @override
  State<OnboardingConnectPanel> createState() => _OnboardingConnectPanelState();
}

class _OnboardingConnectPanelState extends State<OnboardingConnectPanel> {
  bool _showOthers = false;
  InferenceProviderType _chosen = onboardingRecommendedProvider;

  void _choose(InferenceProviderType type) => setState(() => _chosen = type);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return OnboardingStage(
      companion: widget.companion,
      title: messages.onboardingConnectOneKeyTitle,
      // Without her, a plain-language reassurance so a novice isn't
      // paralysed by the unfamiliar provider names.
      text: widget.companion != null
          ? messages.onboardingConnectGuide
          : messages.onboardingConnectNotSure,
      progress: widget.progress,
      onBack: widget.onBack,
      onClose: widget.onClose,
      caption: messages.onboardingConnectRecommended,
      helper: Text(messages.onboardingConnectKeyNote),
      primary: OnboardingStageAction(
        label: messages.onboardingConnectContinueWith(
          onboardingProviderName(messages, _chosen),
        ),
        onPressed: () => widget.onSelect(_chosen),
        icon: LottiIcons.forward,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingProviderCard(
            type: onboardingRecommendedProvider,
            recommended: true,
            chosen: _chosen == onboardingRecommendedProvider,
            onTap: () => _choose(onboardingRecommendedProvider),
          ),
          SizedBox(height: tokens.spacing.step2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DesignSystemButton(
              label: _showOthers
                  ? messages.onboardingConnectHideOtherProviders
                  : messages.onboardingConnectOtherProviders,
              onPressed: () => setState(() => _showOthers = !_showOthers),
              variant: DesignSystemButtonVariant.tertiary,
              // On the gutter, like the card above it.
              alignsLabelToLeadingEdge: true,
              trailingIcon: _showOthers
                  ? LottiIcons.collapse
                  : LottiIcons.expand,
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
                          padding: EdgeInsets.only(top: tokens.spacing.step2),
                          child: OnboardingProviderCard(
                            type: type,
                            chosen: _chosen == type,
                            onTap: () => _choose(type),
                          ),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// A provider as a card: its icon in a quiet well, its name and what it
/// offers, on the [OnboardingSelectableSurface] every onboarding choice is
/// made on. The connect step lists them to choose from; the key step shows
/// the one chosen, with the state of its connection as the [status] line.
class OnboardingProviderCard extends StatelessWidget {
  const OnboardingProviderCard({
    required this.type,
    required this.onTap,
    required this.chosen,
    this.recommended = false,
    this.status,
    super.key,
  });

  final InferenceProviderType type;

  /// Chooses the provider; null where the card only shows the one chosen.
  final VoidCallback? onTap;

  /// Whether this is the provider the main button goes on with; null for a
  /// card that only shows the provider, as the key step's does, where its
  /// [status] says how it stands.
  final bool? chosen;

  /// The recommended provider's card: what its one key covers in place of
  /// the tagline, and "Recommended" in the name a screen reader hears.
  final bool recommended;

  /// A line under the card's own, saying how its connection stands.
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final textHigh = tokens.colors.text.highEmphasis;
    final textMed = tokens.colors.text.mediumEmphasis;
    final name = onboardingProviderName(messages, type);
    final tagline = recommended
        ? messages.onboardingConnectMistralPitch
        : onboardingProviderTagline(messages, type);

    return OnboardingSelectableSurface(
      label: recommended
          ? '$name, ${messages.onboardingConnectRecommended}'
          : name,
      onTap: onTap,
      selected: chosen,
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(tokens.spacing.step3),
            decoration: BoxDecoration(
              color: tokens.colors.decorative.level01,
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
            child: Icon(aiProviderIcon(type), color: textMed),
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                if (status case final status?)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step2),
                    child: status,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
