import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// A full-screen coaching spotlight that dims the surface, cuts a highlight
/// hole around a real target widget, and floats a glass card with one primary
/// action next to it.
///
/// Presentational only. The caller measures the real target's rect (the
/// check-in CTA) and inserts this into an [Overlay]; all copy and callbacks are
/// injected. Nothing here reads a session, records metrics, or navigates —
/// those belong to the wiring layer.
///
/// Tap semantics mirror a standard coachmark:
/// - a tap inside the highlighted [targetRect] means "yes, do this" and fires
///   [onAction] (the same effect as tapping the real CTA underneath),
/// - a tap anywhere else on the dim scrim fires [onDismiss],
/// - taps on the card are handled by its own buttons.
///
/// The attention ring around the hole pulses, but only when animations are
/// enabled; under `MediaQuery.disableAnimationsOf` it renders as a static ring
/// so the accessible path keeps the same layout and interaction.
class DailyOsOnboardingSpotlight extends StatefulWidget {
  const DailyOsOnboardingSpotlight({
    required this.targetRect,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.dismissLabel,
    required this.onAction,
    required this.onDismiss,
    super.key,
  });

  /// The target widget's rect, in the coordinate space this spotlight is laid
  /// out in (i.e. the overlay's local coordinates).
  final Rect targetRect;

  final String title;
  final String message;
  final String actionLabel;
  final String dismissLabel;

  /// "Try it" — proceed into the real flow.
  final VoidCallback onAction;

  /// Quiet dismissal — tap the scrim or the dismiss control.
  final VoidCallback onDismiss;

  @override
  State<DailyOsOnboardingSpotlight> createState() =>
      _DailyOsOnboardingSpotlightState();
}

class _DailyOsOnboardingSpotlightState extends State<DailyOsOnboardingSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduceMotion = false;
  bool _pulseSynced = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Sync on the first call regardless — `_reduceMotion` starts false, so a
    // plain equality guard would skip starting the pulse when motion is on.
    if (_pulseSynced && reduceMotion == _reduceMotion) return;
    _pulseSynced = true;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _pulse
        ..stop()
        ..value = 0;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Reuse the day-planning modal's own dim so the spotlight and the modal it
    // leads into share one scrim colour.
    final scrimColor = ModalUtils.getModalBarrierColor(
      isDark: isDark,
      context: context,
    );
    final cutoutPadding = tokens.spacing.step2;
    final cutoutRadius = tokens.radii.m;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final hole = widget.targetRect.inflate(cutoutPadding);
              if (hole.contains(details.localPosition)) {
                widget.onAction();
              } else {
                widget.onDismiss();
              }
            },
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _SpotlightScrimPainter(
                  target: widget.targetRect,
                  padding: cutoutPadding,
                  radius: cutoutRadius,
                  scrimColor: scrimColor,
                  ringColor: tokens.colors.interactive.enabled,
                  // A held mid-pulse frame when motion is disabled.
                  pulse: _reduceMotion ? 0.5 : _pulse.value,
                ),
              ),
            ),
          ),
        ),
        _positionedCard(context, tokens),
      ],
    );
  }

  /// Places the glass card on the roomier side of the target: above it when the
  /// target sits in the lower half (the check-in CTA's usual home), else below.
  Widget _positionedCard(BuildContext context, DsTokens tokens) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final gap = tokens.spacing.step4;
    final placeAbove = widget.targetRect.center.dy > screenHeight / 2;

    return Positioned(
      left: tokens.spacing.step5,
      right: tokens.spacing.step5,
      top: placeAbove ? null : widget.targetRect.bottom + gap,
      bottom: placeAbove ? screenHeight - widget.targetRect.top + gap : null,
      child: _card(context, tokens),
    );
  }

  Widget _card(BuildContext context, DsTokens tokens) {
    return Material(
      type: MaterialType.transparency,
      // Swallow taps that land on the card background so they never fall
      // through to the scrim's dismiss handler.
      child: GestureDetector(
        onTap: () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.l),
          child: DesignSystemGlassStrip(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    widget.message,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: widget.onDismiss,
                        child: Text(widget.dismissLabel),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      FilledButton(
                        onPressed: widget.onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.colors.interactive.enabled,
                          foregroundColor:
                              tokens.colors.text.onInteractiveAlert,
                        ),
                        child: Text(widget.actionLabel),
                      ),
                    ],
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

/// Paints the dim scrim with a rounded rectangular hole around the target and a
/// single attention ring around that hole.
class _SpotlightScrimPainter extends CustomPainter {
  _SpotlightScrimPainter({
    required this.target,
    required this.padding,
    required this.radius,
    required this.scrimColor,
    required this.ringColor,
    required this.pulse,
  });

  final Rect target;
  final double padding;
  final double radius;
  final Color scrimColor;
  final Color ringColor;

  /// 0..1 pulse phase; drives the ring's alpha and outset.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      target.inflate(padding),
      Radius.circular(radius),
    );

    // Scrim everywhere except the hole. An even-odd fill is hardware
    // accelerated and avoids the CPU-side CSG that `Path.combine` performs.
    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(scrimPath, Paint()..color = scrimColor);

    // Attention ring around the hole. Alpha and outset breathe with [pulse];
    // a held frame (pulse fixed) reads as a plain static ring.
    final ringOutset = padding * (1 + pulse);
    final ring = RRect.fromRectAndRadius(
      target.inflate(ringOutset),
      Radius.circular(radius + ringOutset - padding),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ringColor.withValues(alpha: 0.35 + 0.35 * (1 - pulse)),
    );
  }

  @override
  bool shouldRepaint(_SpotlightScrimPainter oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.pulse != pulse ||
      oldDelegate.scrimColor != scrimColor ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.padding != padding ||
      oldDelegate.radius != radius;
}
