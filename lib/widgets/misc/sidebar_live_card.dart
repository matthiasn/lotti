import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

/// Shared visual shell for the sidebar's *live* status surfaces — the running
/// timer and an active audio recording.
///
/// Each renders as its own soft, accent-tinted card with a 3 px accent rail, a
/// leading glyph, the linked title (free to wrap to two lines), a prominent
/// accent-coloured elapsed time, and a trailing action. The accent both
/// identifies the kind at a glance (teal = timer, red = recording) and gives
/// the row real presence — without the old saturated alarm-red fill, glow, or
/// reactive frame. Background/scheduled surfaces (the agent queue) deliberately
/// use a quieter neutral card instead, so the eye lands on what is live first.
class SidebarLiveCard extends StatelessWidget {
  const SidebarLiveCard({
    required this.accent,
    required this.glyph,
    required this.title,
    required this.timeText,
    required this.onTap,
    required this.trailing,
    this.semanticsLabel,
    this.liveRegion = false,
    this.pulse = false,
    super.key,
  });

  /// Drives the rail, leading glyph, and elapsed-time colour.
  final Color accent;

  /// Leading type glyph (stopwatch for the timer, mic for recording).
  final IconData glyph;

  /// Linked task/entry title — wraps to at most two lines, with the full value
  /// available via tooltip when it truncates.
  final String title;

  /// Pre-formatted elapsed time, rendered prominently in [accent].
  final String timeText;

  /// Tapped on the card body (navigates / opens the relevant surface).
  final VoidCallback onTap;

  /// Trailing action — typically the stop button (its own colour/affordance).
  final Widget trailing;

  final String? semanticsLabel;
  final bool liveRegion;

  /// When true, a small pulsing dot is overlaid on the glyph to signal an
  /// actively-capturing state (recording). Respects the platform's
  /// reduce-motion setting.
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: semanticsLabel,
      child: Material(
        // Composite the accent tint over the darker level01 base (not the
        // lighter sidebar level02) so the card reads richer and the
        // accent-coloured time keeps strong, parity contrast across hues.
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.14),
          tokens.colors.background.level01,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.m),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: accent),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.step4,
                      tokens.spacing.step3,
                      tokens.spacing.step3,
                      tokens.spacing.step3,
                    ),
                    child: Row(
                      // Align the leading glyph and trailing action to the
                      // title's first line rather than centring them against
                      // the taller title+time block.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Leading(accent: accent, glyph: glyph, pulse: pulse),
                        SizedBox(width: tokens.spacing.step4),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Tooltip(
                                message: title,
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens.typography.styles.body.bodySmall
                                      .copyWith(
                                        color: tokens.colors.text.highEmphasis,
                                      ),
                                ),
                              ),
                              SizedBox(height: tokens.spacing.step1),
                              Text(
                                timeText,
                                style: tokens
                                    .typography
                                    .styles
                                    .subtitle
                                    .subtitle1
                                    .copyWith(
                                      color: accent,
                                      fontFeatures: numericBadgeFontFeatures,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        trailing,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.accent,
    required this.glyph,
    required this.pulse,
  });

  final Color accent;
  final IconData glyph;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(glyph, size: 22, color: accent);
    if (!pulse) {
      return SizedBox(width: 24, height: 24, child: Center(child: icon));
    }
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: icon),
          Positioned(right: -1, top: -1, child: _PulseDot(color: accent)),
        ],
      ),
    );
  }
}

/// Small breathing dot that marks an actively-capturing state. Static when the
/// platform requests reduced motion.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  // Created eagerly (not lazily) so dispose() never forces initialization
  // during teardown — which would look up an inherited widget on a
  // deactivated element. Under reduce-motion it is simply never started.
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _opacity = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion && !_started) {
      _started = true;
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return dot;
    return FadeTransition(opacity: _opacity, child: dot);
  }
}
