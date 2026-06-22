import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The "your words become a task" reveal — the onboarding aha made visible.
///
/// The captured [spokenLines] ghost upward and fade while a structured task
/// card crystallizes in over a deliberate contact-frame overlap (the card
/// starts arriving before the prose has gone, so it reads as *transformation*
/// rather than disappear-then-appear). The [title] lands, then the [items]
/// assemble on a staggered cascade with their checks scaling in.
///
/// Drive it with real captured data; it plays once on mount. For previews pass
/// [loop] to replay continuously. Under reduced motion the resolved card is
/// shown statically with no ghosts and no motion.
class CrystallizeHero extends StatefulWidget {
  const CrystallizeHero({
    required this.accent,
    required this.cardColor,
    required this.onCardColor,
    required this.ghostColor,
    required this.title,
    required this.items,
    this.spokenLines = const [],
    this.loop = false,
    this.categoryLabel,
    super.key,
  });

  /// Tick + title accent colour (brand).
  final Color accent;

  /// Fill of the resolved task card (a light surface on the dark hero panel).
  final Color cardColor;

  /// Text colour on the resolved card.
  final Color onCardColor;

  /// Faint colour of the drifting "spoken" ghost phrases.
  final Color ghostColor;

  /// The structured task title that crystallizes from the speech.
  final String title;

  /// The structured checklist items (may be empty for a single simple task).
  final List<String> items;

  /// The raw spoken phrases that ghost up and fade as the card forms.
  final List<String> spokenLines;

  /// Replay continuously instead of playing once (for gallery previews).
  final bool loop;

  /// Optional category pill shown on the card, signalling the task landed in a
  /// real place (not just a styled note).
  final String? categoryLabel;

  @override
  State<CrystallizeHero> createState() => _CrystallizeHeroState();
}

class _CrystallizeHeroState extends State<CrystallizeHero>
    with SingleTickerProviderStateMixin {
  // Bespoke hero timing (like the aurora/constellation heroes) — the reveal is
  // a cinematic beat, not a UI micro-transition, so it sits above the motion
  // duration scale by design.
  static const _revealDuration = Duration(milliseconds: 1800);
  static const _loopDuration = Duration(seconds: 6);

  /// Travel of the ghost phrases as they drift up, in logical px.
  static const _ghostRise = 18.0;

  /// Responsive upper bound on the card width so it doesn't stretch on desktop.
  static const _maxCardWidth = 360.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.loop ? _loopDuration : _revealDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 1;
    } else if (widget.loop) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ramp 0→1 across [a,b].
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0, 1).toDouble();

  /// Fade in over [inA,inB], hold, fade out over [outA,outB].
  static double _window(
    double t,
    double inA,
    double inB,
    double outA,
    double outB,
  ) {
    final rising = _seg(t, inA, inB);
    final falling = 1 - _seg(t, outA, outB);
    return rising < falling ? rising : falling;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Exiting prose accelerates away; the arriving card decelerates in.
          final ghostOpacity = reduceMotion
              ? 0.0
              : _window(t, 0, 0.06, 0.2, 0.32);
          final cardReveal = reduceMotion
              ? 1.0
              : MotionCurves.emphasizedDecelerate.transform(
                  _seg(t, 0.26, 0.5),
                );

          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.spokenLines.isNotEmpty)
                Opacity(
                  opacity: ghostOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -_ghostRise * t),
                    child: _GhostPhrases(
                      lines: widget.spokenLines,
                      color: widget.ghostColor,
                      style: tokens.typography.styles.body.bodyLarge,
                      gap: tokens.spacing.step2,
                    ),
                  ),
                ),
              Opacity(
                opacity: cardReveal,
                child: Transform.scale(
                  scale: 0.96 + 0.04 * cardReveal,
                  child: _TaskCard(
                    t: t,
                    reduceMotion: reduceMotion,
                    tokens: tokens,
                    accent: widget.accent,
                    cardColor: widget.cardColor,
                    onCardColor: widget.onCardColor,
                    title: widget.title,
                    items: widget.items,
                    categoryLabel: widget.categoryLabel,
                    maxWidth: _maxCardWidth,
                    seg: _seg,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GhostPhrases extends StatelessWidget {
  const _GhostPhrases({
    required this.lines,
    required this.color,
    required this.style,
    required this.gap,
  });

  final List<String> lines;
  final Color color;
  final TextStyle style;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          Padding(
            padding: EdgeInsets.symmetric(vertical: gap),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: style.copyWith(
                color: color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.t,
    required this.reduceMotion,
    required this.tokens,
    required this.accent,
    required this.cardColor,
    required this.onCardColor,
    required this.title,
    required this.items,
    required this.categoryLabel,
    required this.maxWidth,
    required this.seg,
  });

  final double t;
  final bool reduceMotion;
  final DsTokens tokens;
  final Color accent;
  final Color cardColor;
  final Color onCardColor;
  final String title;
  final List<String> items;
  final String? categoryLabel;
  final double maxWidth;
  final double Function(double, double, double) seg;

  double _appear(double a, double b) => reduceMotion
      ? 1.0
      : MotionCurves.emphasizedDecelerate.transform(seg(t, a, b));

  @override
  Widget build(BuildContext context) {
    final titleAppear = _appear(0.4, 0.52);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step5),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(tokens.radii.l),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: [
            // A soft symmetric brand glow (no directional offset) so the card
            // reads as elevated/lit rather than showing a bottom seam.
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (categoryLabel != null) ...[
              Opacity(
                opacity: titleAppear,
                child: _CategoryPill(
                  label: categoryLabel!,
                  tokens: tokens,
                  accent: accent,
                ),
              ),
              SizedBox(height: tokens.spacing.step3),
            ],
            Opacity(
              opacity: titleAppear,
              child: Text(
                title,
                style: tokens.typography.styles.heading.heading2.copyWith(
                  color: onCardColor,
                ),
              ),
            ),
            if (items.isNotEmpty) SizedBox(height: tokens.spacing.step4),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                child: _ChecklistRow(
                  label: items[i],
                  tokens: tokens,
                  accent: accent,
                  onCardColor: onCardColor,
                  appear: _appear(0.46 + i * 0.06, 0.58 + i * 0.06),
                  tick: _appear(0.58 + i * 0.06, 0.68 + i * 0.06),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.tokens,
    required this.accent,
  });

  final String label;
  final DsTokens tokens;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Brighten the teal toward white so the tag clears AA on its own dark teal
    // fill rather than sitting teal-on-teal.
    final foreground = Color.lerp(accent, const Color(0xFFFFFFFF), 0.55);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        // An outline reads the tag as a control (it re-files the task), not a
        // passive label.
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: tokens.spacing.step4,
            color: foreground,
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.tokens,
    required this.accent,
    required this.onCardColor,
    required this.appear,
    required this.tick,
  });

  final String label;
  final DsTokens tokens;
  final Color accent;
  final Color onCardColor;
  final double appear;
  final double tick;

  @override
  Widget build(BuildContext context) {
    final box = tokens.spacing.step6;
    return Opacity(
      opacity: appear,
      child: Transform.translate(
        offset: Offset(tokens.spacing.step3 * (1 - appear), 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.scale(
              scale: tick,
              child: Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: tokens.spacing.step5,
                  color: accent,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                label,
                style: tokens.typography.styles.body.bodyLarge.copyWith(
                  color: onCardColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
