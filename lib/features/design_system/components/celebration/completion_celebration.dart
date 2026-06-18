import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';

/// Wraps [child] with the staged completion celebration used across the app: a
/// soft accent glow that blooms behind the content, then a burst of sparks over
/// it, driven by one ~1400ms timeline so the beats cascade (glow bloom, then
/// spark burst) instead of firing on the same frame.
///
/// Plays once each time [completed] transitions `false → true` — never on a
/// child that was already complete when first built — so it marks the *moment*
/// of completion, not the completed state. This mirrors the habits row's
/// celebration so completing a checklist and completing a habit speak the same
/// motion language.
///
/// Reduced motion: the glow holds a fixed size and only fades (an
/// acknowledgement with no spatial expansion); the burst is suppressed entirely.
///
/// Render notes: the glow sits *behind* [child] and the burst *over* it inside a
/// non-clipping [Stack] + [IgnorePointer], so the halo shows around the child's
/// edges and the sparks are free to leave its bounds. [child] should therefore
/// be opaque (e.g. a card) for the glow to read as an edge halo.
class CompletionCelebration extends StatefulWidget {
  const CompletionCelebration({
    required this.completed,
    required this.child,
    this.burstOrigin = const Alignment(0, -0.6),
    this.showBurst = true,
    this.anchorScale = false,
    this.onCelebrate,
    super.key,
  });

  /// Whether the wrapped thing counts as complete. The celebration fires on the
  /// `false → true` edge of this value.
  final bool completed;

  final Widget child;

  /// Burst centre in fractional coordinates of the celebration area (the [child]
  /// bounds). Aim it at the element that "completed" (a progress ring, a check).
  final Alignment burstOrigin;

  /// When false, only the glow plays (for high-frequency moments that don't
  /// warrant flying sparks).
  final bool showBurst;

  /// When true, the [child] itself pops — a single overshoot scale (1 → 1.12 →
  /// 1) in the first quarter of the timeline, landing with the glow bloom — so
  /// the celebration reads as *of* the anchor (e.g. a status pill detonating),
  /// not merely *around* it. Suppressed under reduced motion.
  final bool anchorScale;

  /// Fired the instant the celebration triggers — the place to add a haptic
  /// (e.g. `() => HapticFeedback.mediumImpact()`). Runs even under reduced
  /// motion, since a haptic is feedback, not visual motion.
  final VoidCallback? onCelebrate;

  @override
  State<CompletionCelebration> createState() => _CompletionCelebrationState();
}

class _CompletionCelebrationState extends State<CompletionCelebration>
    with SingleTickerProviderStateMixin {
  /// One shared timeline; the glow and burst read windowed slices of it so the
  /// beats cascade off a single controller. Created in [initState] so it always
  /// exists for [dispose].
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didUpdateWidget(CompletionCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.completed && widget.completed) {
      widget.onCelebrate?.call();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The 0→1 progress of a beat whose window is `[start, end]` within the shared
  /// timeline value [c], or `null` when [c] is outside that window so the caller
  /// renders nothing.
  static double? _stage(double c, double start, double end) {
    if (c <= start || c >= end) return null;
    return (c - start) / (end - start);
  }

  /// The anchor's pop scale at timeline value [c]: a single 1 → 1.12 → 1
  /// overshoot confined to the first quarter of the timeline so it lands with
  /// the glow bloom. Rests at 1 outside the window.
  static double _anchorScaleValue(double c) {
    const window = 0.25;
    if (c <= 0 || c >= window) return 1;
    final t = c / window;
    final pop = t < 0.5
        ? Curves.easeOut.transform(t / 0.5)
        : 1 - Curves.easeIn.transform((t - 0.5) / 0.5);
    return 1 + 0.12 * pop;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    var content = widget.child;
    if (widget.anchorScale && !reduceMotion) {
      content = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _anchorScaleValue(_controller.value),
          child: child,
        ),
        child: widget.child,
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Glow blooms behind the (opaque) child — outside any clip so the halo
        // shows around the edges. Starts ~80ms in so it reads as caused by the
        // completion landing, not co-fired with it.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final v = _stage(_controller.value, 0.08, 0.78);
                return v == null
                    ? const SizedBox.shrink()
                    : CompletionGlow(value: v, staticGlow: reduceMotion);
              },
            ),
          ),
        ),
        content,
        // Sparks fly over the child, free to leave its bounds. Launches ~135ms
        // in so they read as thrown by the completion. Suppressed under reduced
        // motion — the glow alone acknowledges the moment.
        if (widget.showBurst && !reduceMotion)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final p = _stage(_controller.value, 0.12, 0.96);
                  return p == null
                      ? const SizedBox.shrink()
                      // Denser + finer than the default so the task surfaces'
                      // bursts read rich; habits keeps the default via its own
                      // direct CompletionBurst.
                      : CompletionBurst(
                          progress: p,
                          origin: widget.burstOrigin,
                          count: 50,
                          sizeScale: 0.8,
                        );
                },
              ),
            ),
          ),
      ],
    );
  }
}
