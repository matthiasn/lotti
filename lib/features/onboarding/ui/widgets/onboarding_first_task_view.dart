import 'dart:math' as math;

import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_capture_category.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_choice_chip.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_stage.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/live_waveform.dart';
import 'package:material_ui/material_ui.dart';

/// The visible state of the in-panel first-task moment.
enum OnboardingFirstTaskPhase {
  /// Idle — the recording visual invites a tap; starter suggestions offer a
  /// no-mic path into the same pipeline.
  prompt,

  /// Mic open — the chosen visual rides the live voice level.
  listening,

  /// Words captured, structuring in flight — the transcript dims under a
  /// thinking shimmer.
  thinking,

  /// The task landed — the created beat: the title as a glowing tappable card
  /// that hands off to the real task page, where checklist proposals appear.
  created,
}

/// Presentational surface for the onboarding first-task step, on the shared
/// [OnboardingStage] (unlike the pre-FTUE full-screen capture page).
///
/// Her bubble carries the per-phase headline, with the guidance at the
/// prompt and the live caption while listening. At the prompt the tray
/// holds the destination picker and tappable starter-task suggestions, and
/// the main button opens the mic. While listening and thinking it holds one
/// **active band**: the recording-style preference ([RecordingStyle.modern]
/// orb by default, or the [RecordingStyle.analogue] VU meter when chosen
/// under Settings → Recording Style) riding the voice, then the thinking
/// cluster while structuring. The main button ends the recording, and — on
/// the created frame, where the band gives way to the landed task as a
/// glowing tappable card — opens the task ([onOpenTask]); "Rather type?" is
/// the link above it while composing. Checklist proposals stay on the real task page, where they can
/// be reviewed and confirmed.
///
/// It is string- and callback-injected (no `getIt`/Riverpod) so it renders
/// identically under the real capture flow and in isolation for design review.
class OnboardingFirstTaskView extends StatelessWidget {
  const OnboardingFirstTaskView({
    required this.phase,
    required this.style,
    required this.accent,
    required this.colorScheme,
    required this.title,
    required this.guidance,
    required this.suggestionsLabel,
    required this.suggestions,
    required this.listeningCaption,
    required this.thinkingHeadline,
    required this.thinkingReassurance,
    required this.ratherTypeLabel,
    required this.recordSemanticLabel,
    required this.recordLabel,
    required this.stopLabel,
    required this.openTaskLabel,
    required this.categoryPrompt,
    required this.createdHeadline,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onRecordTap,
    required this.onSuggestionTap,
    required this.onRatherType,
    required this.onOpenTask,
    this.createdTaskTitle = '',
    this.transcript = '',
    this.amplitudes = const [],
    this.dbfs = CaptureState.defaultDbfs,
    this.companion,
    this.onClose,
    this.onBack,
    this.createdText = '',
    this.createdCaption = '',
    this.landedIn = '',
    this.startOverLabel = '',
    this.onStartOver,
    super.key,
  });

  final OnboardingFirstTaskPhase phase;

  /// The recording visual chosen in the style step — the payoff of that pick.
  final RecordingStyle style;

  final Color accent;

  /// Colour scheme handed to the analog VU meter (a dark scheme on the dark
  /// onboarding surface).
  final ColorScheme colorScheme;

  /// Step headline while composing ("Create your first task").
  final String title;

  /// Guidance under the title while idle ("Tap to talk and say what needs
  /// doing…").
  final String guidance;

  /// Small lead-in over the starter suggestions.
  final String suggestionsLabel;

  /// Tappable starter-task one-liners for users who don't want to speak yet.
  final List<String> suggestions;

  /// Caption under the visual while the mic is open.
  final String listeningCaption;

  /// Headline while structuring is in flight ("Turning your words into a task…").
  final String thinkingHeadline;

  /// Reassurance that nothing is final ("You'll be able to edit everything").
  final String thinkingReassurance;

  /// Label for the type-instead escape hatch.
  final String ratherTypeLabel;

  /// Accessibility label for the record affordance (orb or VU meter).
  final String recordSemanticLabel;

  /// The main button at the prompt ("Tap to talk").
  final String recordLabel;

  /// The main button while the mic is open ("Done").
  final String stopLabel;

  /// The main button once the task has landed ("Open task").
  final String openTaskLabel;

  /// Lead-in over the destination pills ("Where should this land?").
  final String categoryPrompt;

  /// Headline of the created beat ("Your first task is ready").
  final String createdHeadline;

  /// The landed task's title, shown on the created card.
  final String createdTaskTitle;

  /// The areas created in the category step. With more than one, a destination
  /// picker appears at the prompt.
  final List<OnboardingCaptureCategory> categories;

  /// The area the structured task will land in.
  final String selectedCategoryId;

  final void Function(String id) onSelectCategory;

  final VoidCallback onRecordTap;

  /// Fired with the tapped suggestion's text — routed through the same
  /// structuring pipeline as a spoken transcript.
  final void Function(String suggestion) onSuggestionTap;

  final VoidCallback onRatherType;

  /// Fired when the created card is tapped — the host opens the real task.
  final VoidCallback onOpenTask;

  /// The live/captured transcript (shown during
  /// [OnboardingFirstTaskPhase.thinking]).
  final String transcript;

  /// Rolling normalized amplitude window for the live waveform.
  final List<double> amplitudes;

  /// Latest raw dBFS for the breathing visual.
  final double dbfs;

  /// The companion, on the stage; the host builds her for the phase, so this
  /// view stays free of providers.
  final Widget? companion;

  /// Leaves onboarding from here, offered until the task has landed: after
  /// that the main button is the way on.
  final VoidCallback? onClose;

  /// Goes back to the areas, offered at the prompt — before anything has
  /// been said.
  final VoidCallback? onBack;

  /// What she adds once the task has landed: where it is, and what opening
  /// it shows.
  final String createdText;

  /// The caption over the landed task, so it starts where every step's
  /// content does.
  final String createdCaption;

  /// The area the landed task is in, named on its card.
  final String landedIn;

  /// The link while the mic is open: drops what was said and goes back to
  /// the prompt, so recording is never commit-or-quit.
  final String startOverLabel;
  final VoidCallback? onStartOver;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Minimum height for the band the active element is centred in, so the
    // recording visual and the thinking cluster share one optical anchor across
    // phases. Sized on the token scale to seat the tallest visual (the modern
    // `VoiceOrbZone` — waveform + orb + caption): step13 + step10 + step3 = 232.
    // It is a *minimum*, not a fixed height, so the orb's caption can still grow
    // under a large text scale instead of overflowing the band.
    final activeBandHeight =
        tokens.spacing.step13 + tokens.spacing.step10 + tokens.spacing.step3;

    final prompt = phase == OnboardingFirstTaskPhase.prompt;
    final picker = prompt && categories.length > 1;
    return OnboardingStage(
      companion: companion,
      // Her line is the headline, in her bubble, and every frame has a
      // second line: the guidance at the prompt, the live caption while she
      // listens, that nothing is final while she thinks, and where the task
      // is once it has landed.
      title: _headline,
      text: switch (phase) {
        OnboardingFirstTaskPhase.prompt => guidance,
        OnboardingFirstTaskPhase.listening => listeningCaption,
        OnboardingFirstTaskPhase.thinking => thinkingReassurance,
        OnboardingFirstTaskPhase.created => createdText,
      },
      progress: switch (phase) {
        OnboardingFirstTaskPhase.prompt => const OnboardingProgress(
          done: 2,
          current: 0.25,
        ),
        OnboardingFirstTaskPhase.listening => const OnboardingProgress(
          done: 2,
          current: 0.5,
        ),
        OnboardingFirstTaskPhase.thinking => const OnboardingProgress(
          done: 2,
          current: 0.75,
        ),
        OnboardingFirstTaskPhase.created => const OnboardingProgress(
          done: OnboardingProgress.total,
        ),
      },
      // Back to the areas only before anything has been said; the arrow
      // stays in the bar, disabled, after that.
      onBack: prompt ? onBack : null,
      showBack: true,
      onClose: onClose,
      // Where the task lands comes first, then the shortcuts; the landed
      // task under a caption of its own.
      caption: phase == OnboardingFirstTaskPhase.created
          ? createdCaption
          : !prompt
          ? null
          : picker
          ? categoryPrompt
          : suggestionsLabel,
      // The recorder and the thinking pulse are the one thing on their
      // frames, and move; they sit in the middle of the tray.
      centered:
          phase == OnboardingFirstTaskPhase.listening ||
          phase == OnboardingFirstTaskPhase.thinking,
      // Typing instead is offered before the mic opens. While it is open,
      // the way out short of Done is to start over — said plainly, since it
      // drops what was said.
      secondary: prompt
          ? OnboardingStageAction(
              label: ratherTypeLabel,
              onPressed: onRatherType,
            )
          : phase == OnboardingFirstTaskPhase.listening && onStartOver != null
          ? OnboardingStageAction(
              label: startOverLabel,
              onPressed: onStartOver,
            )
          : null,
      primary: switch (phase) {
        OnboardingFirstTaskPhase.prompt => OnboardingStageAction(
          label: recordLabel,
          onPressed: onRecordTap,
          icon: LottiIcons.mic,
        ),
        OnboardingFirstTaskPhase.listening => OnboardingStageAction(
          label: stopLabel,
          onPressed: onRecordTap,
          icon: LottiIcons.confirm,
        ),
        OnboardingFirstTaskPhase.thinking => null,
        OnboardingFirstTaskPhase.created => OnboardingStageAction(
          label: openTaskLabel,
          onPressed: onOpenTask,
          icon: LottiIcons.forward,
        ),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (phase == OnboardingFirstTaskPhase.created)
            _CreatedTaskCard(
              tokens: tokens,
              taskTitle: createdTaskTitle,
              landedIn: landedIn,
            )
          else if (!prompt)
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: activeBandHeight),
              child: Center(child: _activeElement(tokens)),
            ),
          if (prompt) ...[
            if (picker) ...[
              _CategoryPicker(
                tokens: tokens,
                categories: categories,
                selectedId: selectedCategoryId,
                onSelect: onSelectCategory,
              ),
              SizedBox(height: tokens.spacing.step6),
              OnboardingTrayCaption(suggestionsLabel),
              SizedBox(height: tokens.spacing.step4),
            ],
            _SuggestionChips(
              tokens: tokens,
              suggestions: suggestions,
              onTap: onSuggestionTap,
            ),
          ],
        ],
      ),
    );
  }

  String get _headline => switch (phase) {
    OnboardingFirstTaskPhase.prompt => title,
    OnboardingFirstTaskPhase.listening => title,
    OnboardingFirstTaskPhase.thinking => thinkingHeadline,
    OnboardingFirstTaskPhase.created => createdHeadline,
  };

  Widget _activeElement(DsTokens tokens) {
    if (phase == OnboardingFirstTaskPhase.thinking) {
      return _ThinkingCluster(
        tokens: tokens,
        accent: accent,
        transcript: transcript,
      );
    }
    switch (style) {
      case RecordingStyle.modern:
        return VoiceOrbZone(
          phase: CapturePhase.listening,
          caption: '',
          captionColor: tokens.colors.text.mediumEmphasis,
          semanticLabel: recordSemanticLabel,
          onTap: onRecordTap,
          amplitudes: amplitudes,
          dbfs: dbfs,
          listeningCoreColor: tokens.colors.background.level02,
        );
      case RecordingStyle.analogue:
        return _AnalogueRecorder(
          tokens: tokens,
          colorScheme: colorScheme,
          semanticLabel: recordSemanticLabel,
          onTap: onRecordTap,
          amplitudes: amplitudes,
          dbfs: dbfs,
        );
    }
  }
}

/// The analogue counterpart of [VoiceOrbZone]: a tappable skeuomorphic VU meter
/// + neutral waveform pair, riding the same live level.
class _AnalogueRecorder extends StatelessWidget {
  const _AnalogueRecorder({
    required this.tokens,
    required this.colorScheme,
    required this.semanticLabel,
    required this.onTap,
    required this.amplitudes,
    required this.dbfs,
  });

  final DsTokens tokens;
  final ColorScheme colorScheme;
  final String semanticLabel;
  final VoidCallback onTap;
  final List<double> amplitudes;
  final double dbfs;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.l),
          focusColor: tokens.colors.surface.focusPressed,
          hoverColor: tokens.colors.surface.hover,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnalogVuMeter(
                // 0 VU ≈ -18 dBFS, so VU ≈ dBFS + 18, clamped to the meter range.
                vu: (dbfs + 18).clamp(-20.0, 3.0),
                dBFS: dbfs,
                size: tokens.spacing.step11 * 3,
                colorScheme: colorScheme,
              ),
              SizedBox(height: tokens.spacing.step3),
              LiveWaveform(
                amplitudes: amplitudes,
                color: tokens.colors.text.highEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Starter-task one-liners, under the tray's caption: a no-mic path into the
/// same voice→task pipeline, for users not ready to speak yet. A tap makes
/// the task straight away, so each is a full-width row ending in an arrow —
/// a way on, not a choice to tick.
class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.tokens,
    required this.suggestions,
    required this.onTap,
  });

  final DsTokens tokens;
  final List<String> suggestions;
  final void Function(String suggestion) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, suggestion) in suggestions.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : tokens.spacing.step3),
            child: OnboardingChoiceChip(
              label: suggestion,
              trailing: LottiIcons.forward,
              wrapLabel: true,
              onTap: () => onTap(suggestion),
            ),
          ),
      ],
    );
  }
}

/// The first-task destination picker: chips naming the areas the user
/// created, under the tray's caption, so they choose which one the
/// structured task lands in.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.tokens,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final DsTokens tokens;
  final List<OnboardingCaptureCategory> categories;
  final String selectedId;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        for (final category in categories)
          OnboardingChoiceChip(
            label: category.label,
            selected: category.id == selectedId,
            dense: true,
            onTap: () => onSelect(category.id),
          ),
      ],
    );
  }
}

/// The created beat: the landed task, on the surface every onboarding choice
/// is made on, marked done with its check — its title over the area it
/// landed in. It is a preview, not a button: "Open task" opens it. The
/// checklist is deliberately *not* previewed: it lands on the task page as
/// confirmable proposals. It settles in with a one-shot fade.
class _CreatedTaskCard extends StatelessWidget {
  const _CreatedTaskCard({
    required this.tokens,
    required this.taskTitle,
    required this.landedIn,
  });

  final DsTokens tokens;
  final String taskTitle;
  final String landedIn;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final textMedium = tokens.colors.text.mediumEmphasis;
    final card = OnboardingSelectableSurface(
      label: taskTitle,
      onTap: null,
      selected: true,
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            taskTitle,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          if (landedIn.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step2),
            Row(
              children: [
                Icon(
                  LottiIcons.label,
                  size: tokens.spacing.step4,
                  color: textMedium,
                ),
                SizedBox(width: tokens.spacing.step2),
                Flexible(
                  child: Text(
                    landedIn,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    if (reduceMotion) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MotionDurations.medium4,
      curve: MotionCurves.emphasizedDecelerate,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: card,
    );
  }
}

class _ThinkingCluster extends StatelessWidget {
  const _ThinkingCluster({
    required this.tokens,
    required this.accent,
    required this.transcript,
  });

  final DsTokens tokens;
  final Color accent;
  final String transcript;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        // Comfortable reading measure for the quoted transcript, on the token
        // scale: 2 × step13 + step8 = 360.
        maxWidth: tokens.spacing.step13 * 2 + tokens.spacing.step8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A teal "processing" pulse keeps a hero presence through the wait —
          // the recording visual's energy carries into the thinking beat rather
          // than deflating to a bare progress bar.
          _ThinkingPulse(color: accent, size: tokens.spacing.step11),
          SizedBox(height: tokens.spacing.step6),
          // Flexible so the quote yields to the pulse inside the active band
          // — a long transcript ellipsizes rather than overflowing it.
          Flexible(
            child: Text(
              '"$transcript"',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodyLarge.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A calm teal "processing" pulse: a breathing core under an expanding sonar
/// ring. Reads as *working* (distinct from the recording visual) and keeps a
/// teal hero in the thinking frame. Holds a static frame under reduced motion.
class _ThinkingPulse extends StatefulWidget {
  const _ThinkingPulse({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_ThinkingPulse> createState() => _ThinkingPulseState();
}

class _ThinkingPulseState extends State<_ThinkingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_c.isAnimating) _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _ThinkingPulsePainter(widget.color, _c.value)),
      ),
    );
  }
}

class _ThinkingPulsePainter extends CustomPainter {
  _ThinkingPulsePainter(this.color, this.t);

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    // Expanding sonar ring, fading as it grows.
    canvas.drawCircle(
      center,
      maxR * (0.42 + 0.58 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * 0.6),
    );
    // Breathing core (glow + crisp dot).
    final breath = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    canvas
      ..drawCircle(
        center,
        maxR * 0.26 * (0.85 + 0.3 * breath),
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawCircle(center, maxR * 0.18, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ThinkingPulsePainter old) =>
      old.t != t || old.color != color;
}
