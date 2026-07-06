import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_capture_category.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';

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

  /// The task landed — the created beat: the title + checklist as a glowing
  /// tappable card that hands off to the real task page.
  created,
}

/// Presentational surface for the onboarding first-task step, hosted *inside*
/// the onboarding panel (unlike the pre-FTUE full-screen capture page).
///
/// The composing/thinking frames share one composition: a per-phase headline,
/// then a **fixed-height active band** rendering the recording visual the user
/// picked one step earlier ([RecordingStyle.modern] orb or
/// [RecordingStyle.analogue] VU meter), then per-phase support: guidance +
/// tappable starter-task suggestions while idle, a live caption while
/// listening, and the thinking cluster while structuring. A quiet "Rather
/// type?" escape hatch stays pinned under the composing frames. The created
/// frame swaps the band for the landed task itself — a glowing tappable card
/// (title + checklist) whose tap fires [onOpenTask].
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
    required this.categoryPrompt,
    required this.createdHeadline,
    required this.createdHint,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onRecordTap,
    required this.onSuggestionTap,
    required this.onRatherType,
    required this.onOpenTask,
    this.createdTaskTitle = '',
    this.createdChecklist = const [],
    this.transcript = '',
    this.amplitudes = const [],
    this.dbfs = CaptureState.defaultDbfs,
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

  /// Lead-in over the destination pills ("Where should this land?").
  final String categoryPrompt;

  /// Headline of the created beat ("Your first task is ready").
  final String createdHeadline;

  /// Invitation under the created card ("Tap your task to open it").
  final String createdHint;

  /// The landed task's title, shown on the created card.
  final String createdTaskTitle;

  /// The landed task's checklist items, previewed on the created card.
  final List<String> createdChecklist;

  /// The areas created in the category step. With more than one, a destination
  /// picker appears while composing.
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

  bool get _isComposing =>
      phase == OnboardingFirstTaskPhase.prompt ||
      phase == OnboardingFirstTaskPhase.listening;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMedium = dsTokensDark.colors.text.mediumEmphasis;
    final panelBg = dsTokensDark.colors.background.level01;
    // Fixed band the active element is centred in, so the recording visual
    // and the thinking cluster share one optical anchor across phases. Sized
    // on the token scale to fit the tallest visual (the VU meter + waveform
    // pair): step13 + step10 + step3 = 232.
    final activeBandHeight =
        tokens.spacing.step13 + tokens.spacing.step10 + tokens.spacing.step3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          const Positioned.fill(child: OnboardingBackdrop()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0.2),
                    panelBg.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step6,
              tokens.spacing.step5,
              tokens.spacing.step6 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: textHigh,
                  ),
                ),
                if (phase == OnboardingFirstTaskPhase.prompt) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    guidance,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: textMedium,
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.step4),
                // The created card sits at its natural height (a checklist can
                // be taller than the band); the other frames share the fixed
                // band so the visual keeps one optical anchor across phases.
                if (phase == OnboardingFirstTaskPhase.created)
                  _CreatedTaskCard(
                    tokens: tokens,
                    accent: accent,
                    taskTitle: createdTaskTitle,
                    checklist: createdChecklist,
                    hint: createdHint,
                    onTap: onOpenTask,
                  )
                else
                  SizedBox(
                    height: activeBandHeight,
                    child: Center(child: _activeElement(tokens)),
                  ),
                if (phase == OnboardingFirstTaskPhase.listening) ...[
                  SizedBox(height: tokens.spacing.step3),
                  Text(
                    listeningCaption,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodyLarge.copyWith(
                      color: textHigh,
                    ),
                  ),
                ],
                if (_isComposing && categories.length > 1) ...[
                  SizedBox(height: tokens.spacing.step4),
                  _CategoryPicker(
                    tokens: tokens,
                    accent: accent,
                    prompt: categoryPrompt,
                    categories: categories,
                    selectedId: selectedCategoryId,
                    onSelect: onSelectCategory,
                  ),
                ],
                if (phase == OnboardingFirstTaskPhase.prompt) ...[
                  SizedBox(height: tokens.spacing.step5),
                  _SuggestionChips(
                    tokens: tokens,
                    accent: accent,
                    label: suggestionsLabel,
                    suggestions: suggestions,
                    onTap: onSuggestionTap,
                  ),
                ],
                if (_isComposing) ...[
                  SizedBox(height: tokens.spacing.step3),
                  TextButton(
                    onPressed: onRatherType,
                    child: Text(
                      ratherTypeLabel,
                      style: tokens.typography.styles.body.bodyLarge.copyWith(
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
        reassurance: thinkingReassurance,
      );
    }
    final capturePhase = phase == OnboardingFirstTaskPhase.listening
        ? CapturePhase.listening
        : CapturePhase.idle;
    switch (style) {
      case RecordingStyle.modern:
        return VoiceOrbZone(
          phase: capturePhase,
          caption: '',
          captionColor: dsTokensDark.colors.text.mediumEmphasis,
          semanticLabel: recordSemanticLabel,
          onTap: onRecordTap,
          amplitudes: amplitudes,
          dbfs: dbfs,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
              color: dsTokensDark.colors.text.highEmphasis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Starter-task one-liners under a small lead-in: a no-mic path into the same
/// voice→task pipeline, for users not ready to speak yet.
class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.tokens,
    required this.accent,
    required this.label,
    required this.suggestions,
    required this.onTap,
  });

  final DsTokens tokens;
  final Color accent;
  final String label;
  final List<String> suggestions;
  final void Function(String suggestion) onTap;

  @override
  Widget build(BuildContext context) {
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: dsTokensDark.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            for (final suggestion in suggestions)
              Semantics(
                button: true,
                label: suggestion,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => onTap(suggestion),
                    borderRadius: BorderRadius.circular(tokens.radii.l),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: dsTokensDark.colors.background.level02
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(tokens.radii.l),
                        border: Border.all(
                          color: textHigh.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.step4,
                          vertical: tokens.spacing.step2,
                        ),
                        child: Text(
                          suggestion,
                          style: tokens.typography.styles.body.bodySmall
                              .copyWith(color: textHigh),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The first-task destination picker: a short prompt over a centred wrap of
/// pills naming the areas the user created, so they choose which one the
/// structured task lands in. Selection is colour-led (a solid brand fill for
/// the chosen area, an outline for the rest) so it stays legible on the dark
/// panel.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.tokens,
    required this.accent,
    required this.prompt,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final DsTokens tokens;
  final Color accent;
  final String prompt;
  final List<OnboardingCaptureCategory> categories;
  final String selectedId;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          prompt,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: dsTokensDark.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            for (final category in categories)
              _PickerChip(
                tokens: tokens,
                accent: accent,
                label: category.label,
                selected: category.id == selectedId,
                onTap: () => onSelect(category.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// One destination pill. Selected fills solid brand with a dark label; the rest
/// are a quiet outline with a light label.
class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.tokens,
    required this.accent,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DsTokens tokens;
  final Color accent;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? dsTokensDark.colors.background.level01
        : dsTokensDark.colors.text.highEmphasis;
    final radius = BorderRadius.circular(tokens.radii.l);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? accent
                  : dsTokensDark.colors.text.mediumEmphasis.withValues(
                      alpha: 0.5,
                    ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step2,
            ),
            child: Text(
              label,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The created beat: the landed task rendered as a glowing, tappable card —
/// title over its checklist preview — with an invitation line underneath.
/// The tap is the single handoff out of onboarding onto the real task page.
///
/// Enters with a one-shot fade + scale settle, then breathes a soft accent
/// glow so the card reads as *the* thing to touch next. Under reduced motion
/// both rest on a calm static frame.
class _CreatedTaskCard extends StatefulWidget {
  const _CreatedTaskCard({
    required this.tokens,
    required this.accent,
    required this.taskTitle,
    required this.checklist,
    required this.hint,
    required this.onTap,
  });

  final DsTokens tokens;
  final Color accent;
  final String taskTitle;
  final List<String> checklist;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_CreatedTaskCard> createState() => _CreatedTaskCardState();
}

class _CreatedTaskCardState extends State<_CreatedTaskCard>
    with SingleTickerProviderStateMixin {
  /// Drives the breathing invite glow (0 → 1 → 0).
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_glow.isAnimating) _glow.stop();
      _glow.value = 0.5;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final card = AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = _glow.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.35 + 0.35 * t),
            ),
            color: dsTokensDark.colors.background.level02.withValues(
              alpha: 0.55,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.10 + 0.16 * t),
                blurRadius: tokens.spacing.step6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.taskTitle,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: textHigh,
              ),
            ),
            if (widget.checklist.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              for (final (i, item) in widget.checklist.indexed) ...[
                if (i > 0) SizedBox(height: tokens.spacing.step2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step1),
                      child: Icon(
                        Icons.radio_button_unchecked,
                        size: tokens.spacing.step4,
                        color: widget.accent,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Text(
                        item,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: textHigh,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );

    // The hint line shares the card's tap target — "Tap your task to open it"
    // must itself be tappable, not just the card above it.
    final content = Semantics(
      button: true,
      label: widget.taskTitle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            SizedBox(height: tokens.spacing.step3),
            Text(
              widget.hint,
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: widget.accent,
              ),
            ),
          ],
        ),
      ),
    );

    if (reduceMotion) return content;

    // One-shot entrance: the card settles in with a fade + gentle scale so the
    // payoff lands as an arrival, not a hard swap.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MotionDurations.medium4,
      curve: MotionCurves.emphasizedDecelerate,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
      ),
      child: content,
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
          // Flexible so the quote yields to the pulse and the reassurance line
          // inside the fixed-height active band — a long transcript ellipsizes
          // earlier instead of pushing the reassurance out of the band.
          Flexible(
            child: Text(
              '"$transcript"',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodyLarge.copyWith(
                color: dsTokensDark.colors.text.highEmphasis,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          Text(
            reassurance,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: dsTokensDark.colors.text.mediumEmphasis,
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
