import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Measures visibility episodes for one banner: the stopwatch runs while
/// the host tab is on screen (TickerMode — the app shell keeps inactive
/// tabs mounted) AND the banner intersects its enclosing viewport, so
/// scrolled-away time and pocket time never count. Rechecks happen on
/// scroll events, app-lifecycle transitions and dependency changes, not
/// per frame. Every visible→hidden transition flushes its own episode, so
/// separate appearances never merge and persistence doesn't wait for
/// disposal.
///
/// Shared by every banner surface: the shell dock (where a docked tenant
/// is visible whenever the app is foregrounded) and the uncapped list on
/// the goal detail page (where scroll position matters).
///
/// The same visibility verdict also gates a [TickerMode] around the child:
/// the detail page builds its banners eagerly, and a below-the-fold banner
/// with a repeating headline animation would otherwise burn frame work the
/// user cannot see. TickerMode composes with ancestors by AND, so enabling
/// it here never overrides the app shell's inactive-tab muting.
class NudgeBannerExposureTracker extends ConsumerStatefulWidget {
  const NudgeBannerExposureTracker({
    required this.nudgeId,
    required this.child,
    super.key,
  });

  final String nudgeId;
  final Widget child;

  @override
  ConsumerState<NudgeBannerExposureTracker> createState() =>
      _ExposureTrackerState();
}

class _ExposureTrackerState extends ConsumerState<NudgeBannerExposureTracker>
    with WidgetsBindingObserver {
  final Stopwatch _visible = Stopwatch();
  NudgeInteractionsFlush? _flush;
  ScrollPosition? _position;

  /// Starts false — the first layout-safe visibility sample is the
  /// post-frame recheck, so an off-screen banner never animates even for
  /// its first frame.
  bool _childTickerEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armFrameRecheck();
  }

  /// One cheap rect check per DRAWN frame: a local reveal animation (the
  /// Agent's-read card expanding, the About section unfolding) moves this
  /// banner across the viewport boundary with no scroll event and no
  /// rebuild of this widget, so scroll/lifecycle/update hooks alone leave
  /// the ticker gate stale. Re-arming a post-frame callback does not itself
  /// schedule frames — while nothing animates, nothing runs.
  void _armFrameRecheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recheck();
      _armFrameRecheck();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding or locking the device leaves both TickerMode and the
    // viewport check true — hours of pocket time must not count as
    // visible exposure. Leaving `resumed` flushes the episode; resuming
    // starts a fresh one if the banner is still on screen.
    _recheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured while the element is live: `ref` must not be touched from
    // dispose, and the flush must survive the widget's death.
    _flush = ref.read(nudgeExposureFlushProvider);
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_recheck);
      _position = position?..addListener(_recheck);
    }
    // Dependency changes are delivered during build. A sliver viewport may
    // still be resolving directional padding at that point, so querying its
    // reveal offset synchronously can trip Flutter's resolvedPadding assert.
    // The post-frame check below is the first layout-safe visibility sample.
    _recheckAfterFrame();
  }

  @override
  void didUpdateWidget(NudgeBannerExposureTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A sibling banner inserted or removed above this one moves it across
    // the viewport boundary with no scroll event — the rebuild that
    // reflowed the list is the signal.
    _recheckAfterFrame();
  }

  /// On the FIRST build the render box has no layout yet (and after a
  /// rebuild the new layout isn't in yet), so visibility is confirmed
  /// once the frame is out.
  void _recheckAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recheck();
    });
  }

  /// The app shell keeps inactive tabs mounted (IndexedStack) with their
  /// tickers disabled — TickerMode is the "is this tab on screen" signal
  /// — and scrollable hosts keep off-screen banners mounted too, so the
  /// enclosing viewport must actually show the banner. Each
  /// visible→hidden transition flushes its own episode, so separate
  /// appearances never merge and persistence doesn't wait for disposal.
  void _recheck() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final appForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    final visible =
        appForeground && TickerMode.valuesOf(context).enabled && _inViewport();
    if (visible) {
      if (!_visible.isRunning) _visible.start();
    } else if (_visible.isRunning) {
      _flushEpisode();
    }
    if (visible != _childTickerEnabled && mounted) {
      setState(() => _childTickerEnabled = visible);
    }
  }

  bool _inViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final position = _position;
    if (viewport == null ||
        position == null ||
        !position.hasPixels ||
        !position.hasViewportDimension) {
      // No scrollable ancestor (the shell dock): mounted on a visible tab
      // means on screen.
      return true;
    }
    final leadingEdge = viewport.getOffsetToReveal(box, 0).offset;
    return leadingEdge < position.pixels + position.viewportDimension &&
        leadingEdge + box.size.height > position.pixels;
  }

  void _flushEpisode() {
    _visible.stop();
    if (_visible.elapsed > Duration.zero) {
      _flush?.call(widget.nudgeId, _visible.elapsed);
    }
    _visible.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _position?.removeListener(_recheck);
    _flushEpisode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: _childTickerEnabled,
    child: widget.child,
  );
}
