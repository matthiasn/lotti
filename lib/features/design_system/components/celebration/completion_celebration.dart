import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';

/// Wraps [child] with the staged completion celebration used across the app: a
/// soft accent glow that blooms behind the content, then a burst of sparks
/// thrown from it, driven by one ~1400ms timeline so the beats cascade (glow
/// bloom, then spark burst) instead of firing on the same frame.
///
/// Plays once each time [completed] transitions `false → true` — never on a
/// child that was already complete when first built — so it marks the *moment*
/// of completion, not the completed state. This mirrors the habits row's
/// celebration so completing a checklist and completing a habit speak the same
/// motion language.
///
/// The glow renders *behind* [child] inline (an edge halo, so [child] should be
/// opaque). The spark burst renders in the app [Overlay], anchored to the
/// child's on-screen position via [burstOrigin] — so the sparks spread and
/// wither freely above the UI and are never hard-clipped by a surrounding row,
/// card, or scroll viewport, and survive the child itself collapsing away (e.g.
/// a checklist row hiding the instant it completes).
///
/// Reduced motion: the glow holds a fixed size and only fades; the burst is
/// suppressed entirely.
class CompletionCelebration extends StatefulWidget {
  const CompletionCelebration({
    required this.completed,
    required this.child,
    this.burstOrigin = const Alignment(0, -0.6),
    this.showBurst = true,
    this.glow = true,
    this.anchorScale = false,
    this.duration = const Duration(milliseconds: 1400),
    this.burstCount = 50,
    this.burstSizeScale = 0.8,
    this.burstClearCenter = 0.45,
    this.burstReach = 2.2,
    this.onCelebrate,
    super.key,
  });

  /// Whether the wrapped thing counts as complete. The celebration fires on the
  /// `false → true` edge of this value.
  final bool completed;

  final Widget child;

  /// Where in the [child] the burst originates, in fractional coordinates. Aim
  /// it at the element that "completed" (a checkbox, a progress ring, a pill).
  final Alignment burstOrigin;

  /// When false, no spark burst plays (for high-frequency or glow-only moments).
  final bool showBurst;

  /// When false, the glow halo is skipped.
  final bool glow;

  /// Length of the celebration timeline. The glow/burst windows scale with it.
  final Duration duration;

  /// Spark count, size multiplier, the cleared centre ring, and how far the
  /// sparks fly ([burstReach], a multiple of the anchor height). The sparks fly
  /// out and wither naturally; a higher reach lets them spread freely.
  final int burstCount;
  final double burstSizeScale;
  final double burstClearCenter;
  final double burstReach;

  /// When true, the [child] itself pops — a single overshoot scale (1 → 1.12 →
  /// 1) in the first quarter of the timeline, landing with the glow bloom.
  /// Suppressed under reduced motion.
  final bool anchorScale;

  /// Fired the instant the celebration triggers — the place to add a haptic.
  /// Runs even under reduced motion, since a haptic is feedback, not motion.
  final VoidCallback? onCelebrate;

  @override
  State<CompletionCelebration> createState() => _CompletionCelebrationState();
}

/// The 0→1 progress of a beat whose window is `[start, end]` within timeline
/// value [c], or `null` when [c] is outside that window.
double? _stageProgress(double c, double start, double end) {
  if (c <= start || c >= end) return null;
  return (c - start) / (end - start);
}

class _CompletionCelebrationState extends State<CompletionCelebration>
    with SingleTickerProviderStateMixin {
  /// Drives the inline glow + anchor pop. The burst runs its own controller in
  /// the overlay so it outlives this widget if the child collapses.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(CompletionCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.completed && widget.completed) {
      widget.onCelebrate?.call();
      _controller.forward(from: 0);
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (widget.showBurst && !reduceMotion) {
        // Spawn after layout so the anchor's on-screen rect is current.
        WidgetsBinding.instance.addPostFrameCallback((_) => _spawnBurst());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnBurst() {
    if (!mounted) return;
    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;
    final size = box.size;
    final center = box.localToGlobal(widget.burstOrigin.alongSize(size));
    final reach = size.height * widget.burstReach;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _OverlayBurst(
        center: center,
        reach: reach,
        count: widget.burstCount,
        sizeScale: widget.burstSizeScale,
        clearCenter: widget.burstClearCenter,
        duration: widget.duration,
        onDone: () => entry
          ..remove()
          ..dispose(),
      ),
    );
    overlay.insert(entry);
  }

  /// The anchor's pop scale at timeline value [c]: a single 1 → 1.12 → 1
  /// overshoot confined to the first quarter of the timeline.
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
    if (!widget.glow) return content;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Glow blooms behind the (opaque) child. Starts ~80ms in so it reads as
        // caused by the completion landing, not co-fired with it.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final v = _stageProgress(_controller.value, 0.08, 0.78);
                return v == null
                    ? const SizedBox.shrink()
                    : CompletionGlow(value: v, staticGlow: reduceMotion);
              },
            ),
          ),
        ),
        content,
      ],
    );
  }
}

/// The spark burst, rendered in the app [Overlay] and centred on a global
/// [center] so it spreads and withers above the UI without being clipped by
/// any surrounding row / card / scroll viewport. Owns its controller and
/// removes its [OverlayEntry] when the burst finishes, so it survives — and
/// cleans up after — the anchor widget collapsing away.
class _OverlayBurst extends StatefulWidget {
  const _OverlayBurst({
    required this.center,
    required this.reach,
    required this.count,
    required this.sizeScale,
    required this.clearCenter,
    required this.duration,
    required this.onDone,
  });

  final Offset center;
  final double reach;
  final int count;
  final double sizeScale;
  final double clearCenter;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_OverlayBurst> createState() => _OverlayBurstState();
}

class _OverlayBurstState extends State<_OverlayBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A box roomy enough to hold the full spread (so the burst itself never
    // overflows its own paint area); centred on the anchor's global point.
    final half = widget.reach * 1.25;
    return Positioned(
      left: widget.center.dx - half,
      top: widget.center.dy - half,
      width: half * 2,
      height: half * 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final p = _stageProgress(_controller.value, 0.12, 0.96);
            return p == null
                ? const SizedBox.shrink()
                // The overlay box is centred on the anchor, so the burst emits
                // from the box centre — i.e. right behind the celebrated thing
                // (the checkbox / pill), not offset to one side.
                : CompletionBurst(
                    progress: p,
                    origin: Alignment.center,
                    count: widget.count,
                    sizeScale: widget.sizeScale,
                    clearCenter: widget.clearCenter,
                    reachOverride: widget.reach,
                  );
          },
        ),
      ),
    );
  }
}
