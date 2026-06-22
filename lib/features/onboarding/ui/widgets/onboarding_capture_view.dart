import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/animation/ai_thinking_line_shader.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/crystallize_hero.dart';

/// The visible state of the first-capture aha.
enum OnboardingCapturePhase {
  /// Idle — the orb invites a tap; a rotating hint defeats blank-mic freeze.
  prompt,

  /// Mic open — the orb breathes with live voice level, waveform streams.
  listening,

  /// Words captured, structuring in flight — the transcript dims under a
  /// thinking shimmer (honest, indeterminate suspense).
  thinking,

  /// The structured task has crystallized — the hero reveal + celebration.
  revealed,
}

/// Presentational surface for the onboarding voice→task moment.
///
/// All four frames share one composition: a per-phase headline, then a
/// **fixed-height active band** that keeps the orb, the thinking cluster, and
/// the resolved card centred on the *same* optical line (so the orb visibly
/// *becomes* the card), then a per-phase supporting block. At the reveal the
/// edit cue + primary action are grouped directly under the card; the idle and
/// listening states pin a quiet "Rather type?" escape hatch at the bottom.
///
/// It is string- and callback-injected (no `getIt`/Riverpod) so it renders
/// identically under the real capture flow and in isolation for design review.
class OnboardingCaptureView extends StatelessWidget {
  const OnboardingCaptureView({
    required this.phase,
    required this.accent,
    required this.cardColor,
    required this.onCardColor,
    required this.ghostColor,
    required this.promptHeadline,
    required this.revealedHeadline,
    required this.promptHint,
    required this.listeningCaption,
    required this.thinkingHeadline,
    required this.thinkingReassurance,
    required this.ratherTypeLabel,
    required this.acceptLabel,
    required this.orbSemanticLabel,
    required this.editHint,
    required this.onOrbTap,
    required this.onRatherType,
    required this.onAccept,
    this.categoryLabel,
    this.transcript = '',
    this.amplitudes = const [],
    this.dbfs = CaptureState.defaultDbfs,
    this.title = '',
    this.items = const [],
    this.celebrate = false,
    super.key,
  });

  final OnboardingCapturePhase phase;

  final Color accent;
  final Color cardColor;
  final Color onCardColor;
  final Color ghostColor;

  /// Headline for the prompt + listening states ("What's on your mind?").
  final String promptHeadline;

  /// Headline once the task has crystallized ("Here's your first task").
  final String revealedHeadline;

  /// Rotating example hint shown while idle ("Try: …").
  final String promptHint;

  /// Caption under the orb while the mic is open.
  final String listeningCaption;

  /// Headline while structuring is in flight ("Turning your words into a task…").
  final String thinkingHeadline;

  /// Reassurance that nothing is final ("You'll be able to edit everything").
  final String thinkingReassurance;

  /// Label for the type-instead escape hatch.
  final String ratherTypeLabel;

  /// Primary action at the reveal ("Looks good").
  final String acceptLabel;

  /// Accessibility label for the orb button.
  final String orbSemanticLabel;

  /// "Tap any line to edit" cue beneath the resolved card.
  final String editHint;

  final VoidCallback onOrbTap;
  final VoidCallback onRatherType;
  final VoidCallback onAccept;

  /// Optional category pill rendered on the resolved card.
  final String? categoryLabel;

  /// The live/captured transcript (shown during [OnboardingCapturePhase.thinking]).
  final String transcript;

  /// Rolling normalized amplitude window for the live waveform.
  final List<double> amplitudes;

  /// Latest raw dBFS for the breathing orb.
  final double dbfs;

  /// Structured task title (revealed phase).
  final String title;

  /// Structured checklist items (revealed phase).
  final List<String> items;

  /// Fire the completion burst around the resolved card.
  final bool celebrate;

  /// Fixed band the active element is centred in, so the orb and the resolved
  /// card share one optical anchor across phases.
  static const double _activeBandHeight = 232;

  /// Max width for centred supporting text / the reveal action group.
  static const double _supportMaxWidth = 340;

  bool get _isListenable =>
      phase == OnboardingCapturePhase.prompt ||
      phase == OnboardingCapturePhase.listening;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: Column(
        children: [
          const Spacer(flex: 4),
          Text(
            _headline,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          SizedBox(
            height: _activeBandHeight,
            child: Center(child: _activeElement(tokens)),
          ),
          SizedBox(height: tokens.spacing.step5),
          _supporting(tokens),
          // The escape hatch sits with the cluster, not pinned to the screen
          // edge, so the idle frame reads as one composed group.
          if (_isListenable) ...[
            SizedBox(height: tokens.spacing.step4),
            _bottomAction(tokens),
          ],
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  String get _headline => switch (phase) {
    OnboardingCapturePhase.prompt => promptHeadline,
    OnboardingCapturePhase.listening => promptHeadline,
    OnboardingCapturePhase.thinking => thinkingHeadline,
    OnboardingCapturePhase.revealed => revealedHeadline,
  };

  Widget _activeElement(DsTokens tokens) {
    switch (phase) {
      case OnboardingCapturePhase.prompt:
        return VoiceOrbZone(
          phase: CapturePhase.idle,
          caption: '',
          captionColor: tokens.colors.text.mediumEmphasis,
          semanticLabel: orbSemanticLabel,
          onTap: onOrbTap,
        );
      case OnboardingCapturePhase.listening:
        return VoiceOrbZone(
          phase: CapturePhase.listening,
          caption: '',
          captionColor: tokens.colors.text.mediumEmphasis,
          semanticLabel: orbSemanticLabel,
          onTap: onOrbTap,
          amplitudes: amplitudes,
          dbfs: dbfs,
        );
      case OnboardingCapturePhase.thinking:
        return _ThinkingCluster(
          tokens: tokens,
          accent: accent,
          transcript: transcript,
          reassurance: thinkingReassurance,
        );
      case OnboardingCapturePhase.revealed:
        return CompletionCelebration(
          completed: celebrate,
          child: CrystallizeHero(
            accent: accent,
            cardColor: cardColor,
            onCardColor: onCardColor,
            ghostColor: ghostColor,
            title: title,
            items: items,
            categoryLabel: categoryLabel,
          ),
        );
    }
  }

  Widget _supporting(DsTokens tokens) {
    if (phase == OnboardingCapturePhase.revealed) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _supportMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              editHint,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step5),
            DesignSystemButton(
              label: acceptLabel,
              onPressed: onAccept,
              fullWidth: true,
            ),
          ],
        ),
      );
    }

    // Thinking carries its reassurance inside the centred cluster, so its
    // supporting slot stays empty to avoid a stranded line.
    if (phase == OnboardingCapturePhase.thinking) {
      return const SizedBox.shrink();
    }

    final text = phase == OnboardingCapturePhase.listening
        ? listeningCaption
        : promptHint;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _supportMaxWidth),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodyLarge.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }

  Widget _bottomAction(DsTokens tokens) {
    return TextButton(
      onPressed: onRatherType,
      child: Text(
        ratherTypeLabel,
        style: tokens.typography.styles.body.bodyLarge.copyWith(color: accent),
      ),
    );
  }
}

class _ThinkingCluster extends StatelessWidget {
  const _ThinkingCluster({
    required this.tokens,
    required this.accent,
    required this.transcript,
    required this.reassurance,
  });

  final DsTokens tokens;
  final Color accent;
  final String transcript;
  final String reassurance;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '"$transcript"',
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyLarge.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          AiThinkingLineShader(
            width: 220,
            height: 30,
            primaryColor: accent,
            secondaryColor: tokens.colors.text.highEmphasis,
            // Transparent so the shimmer floats on the page, with no boxed-in
            // panel competing with the calm dark surface.
            backgroundColor: tokens.colors.background.level01.withValues(
              alpha: 0,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          Text(
            reassurance,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
