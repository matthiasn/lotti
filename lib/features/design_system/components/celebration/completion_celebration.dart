import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';
import 'package:lotti/themes/colors.dart';

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
    this.glowIntensity = 1.0,
    this.anchorScale = false,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1400),
    this.burstCount = 50,
    this.burstSizeScale = 0.8,
    this.burstClearCenter = 0.45,
    this.burstReach = 2.2,
    this.variant = CelebrationVariant.defaultVariant,
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

  /// Scales the glow's peak opacity (1.0 = full). Lower it for a section-level
  /// completion that already celebrates per item, so the bloom reads as a soft
  /// acknowledgement rather than a blinding flash.
  final double glowIntensity;

  /// Length of the celebration timeline. The glow/burst windows scale with it.
  final Duration duration;

  /// Spark count, size multiplier, the cleared centre ring, and how far the
  /// sparks fly ([burstReach], a multiple of the anchor height). The sparks fly
  /// out and wither naturally; a higher reach lets them spread freely.
  final int burstCount;
  final double burstSizeScale;
  final double burstClearCenter;
  final double burstReach;

  /// Which particle language the burst speaks, and whether the glow runs warm.
  final CelebrationVariant variant;

  /// When true, the [child] itself pops — a single overshoot scale (1 → 1.12 →
  /// 1) in the first quarter of the timeline, landing with the glow bloom.
  /// Suppressed under reduced motion.
  final bool anchorScale;

  /// Fired the instant the celebration triggers — the place to add a haptic.
  /// Runs even under reduced motion, since a haptic is feedback, not motion.
  final VoidCallback? onCelebrate;

  /// Master gate for the *visual* celebration (glow, spark burst, anchor pop).
  /// When false the visuals are skipped entirely but [onCelebrate] still fires,
  /// so a user who turned celebratory animations off in Settings keeps the
  /// completion haptic without the flash. Defaults to true.
  final bool animate;

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
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (!oldWidget.completed && widget.completed) {
      // The haptic fires regardless; only the visual beats honour [animate].
      widget.onCelebrate?.call();
      if (widget.animate) {
        _controller.forward(from: 0);
        if (widget.showBurst) {
          // Capture the anchor geometry now, while still mounted, and render
          // the burst in the overlay — see [spawnCompletionBurst].
          spawnCompletionBurst(
            context,
            variant: widget.variant,
            origin: widget.burstOrigin,
            count: widget.burstCount,
            sizeScale: widget.burstSizeScale,
            clearCenter: widget.burstClearCenter,
            reachFactor: widget.burstReach,
            duration: widget.duration,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                    : CompletionGlow(
                        value: v,
                        staticGlow: reduceMotion,
                        intensity: widget.glowIntensity,
                        // A warm variant blooms warm; the rest keep the accent.
                        color: widget.variant.isWarm ? starredGold : null,
                      );
              },
            ),
          ),
        ),
        content,
      ],
    );
  }
}

/// Fires a self-contained completion spark burst in the app [Overlay], anchored
/// to the render box of [context].
///
/// The geometry is read here — synchronously, while [context] is still mounted
/// — and the burst then lives in the overlay with its own controller. That is
/// what lets it survive the anchor being torn down in the *same* frame: e.g.
/// completing the last open checklist item collapses the whole list (the card
/// swaps the row list for an "all done" line) on the very next build, so a
/// celebration tied to the row's widget lifecycle would be unmounted before it
/// could paint. Firing it imperatively from the tap, then rendering in the
/// overlay, sidesteps that entirely — and keeps the sparks unclipped by the
/// row / card / scroll viewport.
///
/// No-op under reduced motion, or when there is no overlay / laid-out render
/// box. [origin] is the burst centre within the anchor; [reachFactor]
/// multiplies the anchor height to set how far the sparks fly.
void spawnCompletionBurst(
  BuildContext context, {
  CelebrationVariant variant = CelebrationVariant.defaultVariant,
  Alignment origin = Alignment.center,
  int count = 50,
  double sizeScale = 0.8,
  double clearCenter = 0.45,
  double reachFactor = 2.2,
  Duration duration = const Duration(milliseconds: 1400),
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  if (reduceMotion) return;
  final overlay = Overlay.maybeOf(context);
  final box = context.findRenderObject() as RenderBox?;
  if (overlay == null || box == null || !box.hasSize) return;
  // Stretch the burst window for variants whose motion reads too fast at the
  // base timing (bubbles). Centralised here so every call site — task done,
  // checklist item, the settings preview — picks it up without its own tuning.
  final scaledDuration = duration * variant.durationScale;
  final size = box.size;
  // Anchor in the overlay's own coordinate space, not the screen's. The
  // nearest Overlay may be a nested one — e.g. the desktop task-detail pane,
  // offset to the right of the sidebar — and the burst is positioned inside
  // *that* overlay. Plain global coords would double-count the overlay's
  // offset and fling the burst off to the side (only a stray spark drifting
  // back into view). Passing the overlay's render box as `ancestor` makes
  // [RenderBox.localToGlobal] stop there, yielding overlay-local coordinates.
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  final center = box.localToGlobal(
    origin.alongSize(size),
    ancestor: overlayBox,
  );
  final reach = size.height * reachFactor;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!overlay.mounted) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _OverlayBurst(
        center: center,
        reach: reach,
        variant: variant,
        count: count,
        sizeScale: sizeScale,
        clearCenter: clearCenter,
        duration: scaledDuration,
        // Guard remove(): the entry may already be gone if the overlay was
        // torn down (e.g. the route popped) before the burst finished.
        onDone: () {
          if (entry.mounted) entry.remove();
          entry.dispose();
        },
      ),
    );
    overlay.insert(entry);
  });
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
    required this.variant,
    required this.count,
    required this.sizeScale,
    required this.clearCenter,
    required this.duration,
    required this.onDone,
  });

  final Offset center;
  final double reach;
  final CelebrationVariant variant;
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
                    variant: widget.variant,
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
